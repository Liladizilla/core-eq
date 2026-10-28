package dev.coreeq.audio

import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
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
    private lateinit var appContext: android.content.Context
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var running = false
    @Volatile private var worker: Thread? = null
    private var track: AudioTrack? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> mainHandler.post {
                lastError = "Audio focus lost; playback stopped."
                stopPlayback()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> mainHandler.post {
                lastError = "Audio focus interrupted; playback stopped."
                stopPlayback()
            }
        }
    }
    private var engine: Long = 0L
    private var lastError: String? = null
    @Volatile private var toneFrequencyHz = 440
    @Volatile private var toneAmplitude = 0.06f
    // Preserve controls while stopped and restore them into each new native session.
    private val bandGainsDb = FloatArray(10) { 0.0f }
    @Volatile private var outputGainDb = 0.0f
    @Volatile private var bypassed = false
    @Volatile private var limiterEnabled = true
    @Volatile private var spatialEnabled = false
    // Gain state is owned by the single audio worker.
    private var limiterGain = 1.0f

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "core_eq_audio")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTestTone" -> {
                val frequencyHz = call.argument<Int>("frequencyHz") ?: 440
                val amplitude = call.argument<Double>("amplitude")?.toFloat() ?: 0.06f
                if (frequencyHz !in setOf(32, 64, 125, 250, 440, 1000)) {
                    result.error("INVALID_TONE_FREQUENCY", "Choose 32, 64, 125, 250, 440, or 1000 Hz.", null)
                    return
                }
                if (!amplitude.isFinite() || amplitude !in 0.02f..0.12f) {
                    result.error("INVALID_TONE_AMPLITUDE", "Test tone level must be between 0.02 and 0.12.", null)
                    return
                }
                if (running) { result.success(status()); return }
                try {
                    startPlayback(frequencyHz, amplitude)
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
            "setSpatialEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Spatial enabled must be a boolean.", null)
                } else {
                    spatialEnabled = enabled
                    result.success(null)
                }
            }
            "setLimiterEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Limiter enabled must be a boolean.", null)
                } else {
                    limiterEnabled = enabled
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

    private fun requestAudioFocus() {
        val manager = appContext.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
        audioManager = manager
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(audioFocusListener)
                .setWillPauseWhenDucked(true)
                .build()
            audioFocusRequest = request
            manager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        check(granted) { "Audio focus was denied by Android." }
        hasAudioFocus = true
    }

    private fun abandonAudioFocus() {
        if (!hasAudioFocus) return
        val manager = audioManager
        if (manager != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { manager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                manager.abandonAudioFocus(audioFocusListener)
            }
        }
        audioFocusRequest = null
        hasAudioFocus = false
    }

    @Synchronized
    private fun startPlayback(frequencyHz: Int, amplitude: Float) {
        toneFrequencyHz = frequencyHz
        toneAmplitude = amplitude
        check(Build.VERSION.SDK_INT >= 23) { "Generated float-PCM playback requires Android 6.0 or newer." }
        check(!running) { "Playback is already running." }
        requestAudioFocus()
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
        // A new playback session starts with unity limiter gain; never carry
        // attenuation from a previous session into the next test tone.
        limiterGain = 1.0f
        worker = Thread({
            var phase = 0.0
            val step = 2.0 * PI * toneFrequencyHz / sampleRate
            try {
                audioTrack.play()
                while (running) {
                    floats.position(0)
                    for (frame in 0 until frames) {
                        val left = (toneAmplitude * sin(phase - 0.09)).toFloat()
                        val right = (toneAmplitude * sin(phase + 0.09)).toFloat()
                        phase += step
                        if (phase >= 2.0 * PI) phase -= 2.0 * PI
                        floats.put(left)
                        floats.put(right)
                    }
                    check(nativeProcess(engine, pcm, frames, channels) == 0) {
                        "Native DSP rejected an audio block."
                    }
                    // Optional mid/side stereo width processing. The test signal has a small
                    // channel phase offset so widening is audible instead of mathematically
                    // inert on perfectly identical mono channels.
                    if (spatialEnabled) {
                        val width = 1.6f
                        for (frame in 0 until frames) {
                            val index = frame * channels
                            val left = floats.get(index)
                            val right = floats.get(index + 1)
                            val mid = (left + right) * 0.5f
                            val side = (left - right) * 0.5f * width
                            floats.put(index, (mid + side).coerceIn(-1.0f, 1.0f))
                            floats.put(index + 1, (mid - side).coerceIn(-1.0f, 1.0f))
                        }
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
        abandonAudioFocus()
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
        "frequencyHz" to toneFrequencyHz,
        "amplitude" to toneAmplitude.toDouble(),
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
