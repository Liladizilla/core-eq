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
        "error" to lastError
    )

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopPlayback()
        channel.setMethodCallHandler(null)
    }

    private external fun nativeCreate(): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeProcess(handle: Long, pcm: ByteBuffer, frames: Int, channels: Int): Int
}
