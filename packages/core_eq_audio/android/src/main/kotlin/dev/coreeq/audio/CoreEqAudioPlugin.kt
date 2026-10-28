package dev.coreeq.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.sin

/** Plays a generated test tone only; it does not capture microphone or other-app audio. */
class CoreEqAudioPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var running = false
    @Volatile private var worker: Thread? = null
    private var track: AudioTrack? = null
    private var engine: Long = 0L
    private var lastError: String? = null
    // Preserve controls while stopped and restore them into each new native session.
    private val bandGainsDb = FloatArray(10) { 0.0f }
    @Volatile private var outputGainDb = 0.0f
    @Volatile private var bypassed = false
    @Volatile private var limiterEnabled = true
    // Gain state is owned by the single audio worker.
    private var limiterGain = 1.0f

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "core_eq_audio")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTestTone" -> {
                if (running) { result.success(status()); return }
                try {
                    startPlayback()
                    result.success(status())
                } catch (e: Exception) {
                    lastError = e.message ?: e.javaClass.simpleName
                    stopPlayback()
                    result.error("AUDIO_START_FAILED", lastError, null)
                }
            }
            "stop" -> {
                stopPlayback()
                result.success(status())
            }
            "status" -> result.success(status())
            "setBandGain" -> {
                val band = call.argument<Int>("band")
                val gainDb = call.argument<Double>("gainDb")
                if (band == null || gainDb == null || band !in 0..9 ||
                    !gainDb.isFinite() || gainDb !in -12.0..12.0) {
                    result.error("INVALID_EQ_PARAMETER", "Band must be 0..9 and gain must be -12..12 dB.", null)
                } else {
                    bandGainsDb[band] = gainDb.toFloat()
                    val code = if (engine == 0L) 0 else nativeSetBandGain(engine, band, gainDb.toFloat())
                    if (code == 0) result.success(null)
                    else result.error("NATIVE_EQ_REJECTED", "Native DSP rejected band update (status $code).", null)
                }
            }
            "setOutputGain" -> {
                val gainDb = call.argument<Double>("gainDb")
                if (gainDb == null || !gainDb.isFinite() || gainDb !in -24.0..6.0) {
                    result.error("INVALID_EQ_PARAMETER", "Output gain must be -24..6 dB.", null)
                } else {
                    outputGainDb = gainDb.toFloat()
                    val code = if (engine == 0L) 0 else nativeSetOutputGain(engine, gainDb.toFloat())
                    if (code == 0) result.success(null)
                    else result.error("NATIVE_EQ_REJECTED", "Native DSP rejected output gain (status $code).", null)
                }
            }
            "setLimiterEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Limiter enabled must be a boolean.", null)
                } else {
                    limiterEnabled = enabled
                    if (!enabled) limiterGain = 1.0f
                    result.success(null)
                }
            }
            "setBypassed" -> {
                val bypassed = call.argument<Boolean>("bypassed")
                if (bypassed == null) {
                    result.error("INVALID_EQ_PARAMETER", "Bypass must be a boolean.", null)
                } else {
                    this.bypassed = bypassed
                    val code = if (engine == 0L) 0 else nativeSetBypassed(engine, bypassed)
                    if (code == 0) result.success(null)
                    else result.error("NATIVE_EQ_REJECTED", "Native DSP rejected bypass update (status $code).", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    @Synchronized
    private fun startPlayback() {
        check(Build.VERSION.SDK_INT >= 23) { "Generated float-PCM playback requires Android 6.0 or newer." }
        check(!running) { "Playback is already running." }
        System.loadLibrary("core_eq")
        engine = nativeCreate()
        check(engine != 0L) { "Native CORE-EQ engine allocation failed." }
        for (band in bandGainsDb.indices) {
            check(nativeSetBandGain(engine, band, bandGainsDb[band]) == 0) {
                "Native DSP rejected saved gain for band $band."
            }
        }
        check(nativeSetOutputGain(engine, outputGainDb) == 0) {
            "Native DSP rejected saved output gain."
        }
        check(nativeSetBypassed(engine, bypassed) == 0) {
            "Native DSP rejected saved bypass state."
        }

        val sampleRate = 48000
        val channels = 2
        val frames = 480
        val bytesPerBlock = frames * channels * 4
        val minBytes = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_FLOAT
        )
        check(minBytes > 0) { "Android rejected float-PCM output configuration: $minBytes" }

        val audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBytes, bytesPerBlock * 2))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        check(audioTrack.state == AudioTrack.STATE_INITIALIZED) {
            audioTrack.release()
            "Android AudioTrack initialization failed."
        }

        val pcm = ByteBuffer.allocateDirect(bytesPerBlock).order(ByteOrder.nativeOrder())
        val floats = pcm.asFloatBuffer()
        track = audioTrack
        running = true
        lastError = null
        worker = Thread({
            var phase = 0.0
            val step = 2.0 * PI * 440.0 / sampleRate
            try {
                audioTrack.play()
                while (running) {
                    floats.position(0)
                    for (frame in 0 until frames) {
                        val sample = (0.12 * sin(phase)).toFloat()
                        phase += step
                        if (phase >= 2.0 * PI) phase -= 2.0 * PI
                        floats.put(sample)
                        floats.put(sample)
                    }
                    check(nativeProcess(engine, pcm, frames, channels) == 0) {
                        "Native DSP rejected an audio block."
                    }
                    // Output-stage peak limiter: keep the generated test tone below
                    // -0.9 dBFS with fast attack and gradual release. It operates on
                    // the processed PCM buffer and never copies audio over the channel.
                    floats.position(0)
                    if (limiterEnabled) {
                        var blockPeak = 0.0f
                        for (i in 0 until frames * channels) {
                            blockPeak = maxOf(blockPeak, kotlin.math.abs(floats.get(i)))
                        }
                        val targetGain = if (blockPeak > 0.9f) 0.9f / blockPeak else 1.0f
                        limiterGain = if (targetGain < limiterGain) targetGain
                            else limiterGain + (targetGain - limiterGain) * 0.15f
                        for (i in 0 until frames * channels) {
                            floats.put(i, floats.get(i) * limiterGain)
                        }
                    } else {
                        limiterGain = 1.0f
                    }
                    pcm.position(0)
                    val written = audioTrack.write(pcm, bytesPerBlock, AudioTrack.WRITE_BLOCKING)
                    check(written == bytesPerBlock) { "AudioTrack wrote $written of $bytesPerBlock bytes." }
                    pcm.clear()
                }
            } catch (e: Exception) {
                lastError = e.message ?: e.javaClass.simpleName
                running = false
                mainHandler.post { channel.invokeMethod("playbackError", lastError) }
            } finally {
                try { audioTrack.pause() } catch (_: Exception) {}
                try { audioTrack.flush() } catch (_: Exception) {}
            }
        }, "core-eq-audio").apply { start() }
    }

    @Synchronized
    private fun stopPlayback() {
        running = false
        val audioTrack = track
        // Stop first so a blocking AudioTrack.write can return before we join.
        try { audioTrack?.pause() } catch (_: Exception) {}
        try { audioTrack?.flush() } catch (_: Exception) {}
        try { audioTrack?.stop() } catch (_: Exception) {}

        val thread = worker
        if (thread != null && thread !== Thread.currentThread()) {
            thread.join(2000)
            if (thread.isAlive) {
                lastError = "Audio worker did not stop within 2 seconds; native engine retained for safety."
                return
            }
        }
        worker = null
        audioTrack?.release()
        track = null
        if (engine != 0L) {
            nativeDestroy(engine)
            engine = 0L
        }
    }

    private fun status(): Map<String, Any?> = mapOf(
        "running" to running,
        "sampleRateHz" to 48000,
        "channels" to 2,
        "source" to "generated_test_tone",
        "peakLevel" to if (engine != 0L) nativeGetPeakLevel(engine).coerceIn(0.0f, 1.0f) else 0.0f,
        "error" to lastError
    )

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopPlayback()
        channel.setMethodCallHandler(null)
    }

    private external fun nativeCreate(): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeProcess(handle: Long, pcm: ByteBuffer, frames: Int, channels: Int): Int
    private external fun nativeGetPeakLevel(handle: Long): Float
    private external fun nativeSetBandGain(handle: Long, band: Int, gainDb: Float): Int
    private external fun nativeSetOutputGain(handle: Long, gainDb: Float): Int
    private external fun nativeSetBypassed(handle: Long, bypassed: Boolean): Int
}
