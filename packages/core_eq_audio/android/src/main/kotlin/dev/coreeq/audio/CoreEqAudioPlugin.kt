package dev.coreeq.audio

import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
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
    private var routeCallback: AudioDeviceCallback? = null
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
    private var mediaPlayer: CoreEqMedia3Player? = null
    private val globalOutputEffects = CoreEqGlobalOutputEffects()
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val manager = appContext.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
            val callback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                    mainHandler.post { channel.invokeMethod("audioRouteChanged", audioRouteStatus()) }
                }
                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                    mainHandler.post { channel.invokeMethod("audioRouteChanged", audioRouteStatus()) }
                }
            }
            routeCallback = callback
            manager.registerAudioDeviceCallback(callback, mainHandler)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "playMedia" -> {
                val uri = call.argument<String>("uri")
                if (uri.isNullOrBlank()) {
                    result.error("INVALID_MEDIA_URI", "Choose an audio file before playback.", null)
                    return
                }
                try {
                    if (running) stopPlayback()
                    val player = mediaPlayer ?: CoreEqMedia3Player(appContext) { message ->
                        lastError = message
                        mainHandler.post { channel.invokeMethod("mediaPlaybackError", message) }
                    }.also { mediaPlayer = it }
                    player.applySettings(
                        bandGainsDb,
                        outputGainDb,
                        bypassed,
                        limiterEnabled,
                        spatialEnabled,
                    )
                    player.play(uri)
                    lastError = null
                    result.success(player.status())
                } catch (e: Exception) {
                    lastError = e.message ?: e.javaClass.simpleName
                    result.error("MEDIA_PLAYBACK_FAILED", lastError, null)
                }
            }
            "pauseMedia" -> {
                mediaPlayer?.pause()
                result.success(mediaPlayer?.status() ?: emptyMap<String, Any?>())
            }
            "resumeMedia" -> {
                mediaPlayer?.resume()
                result.success(mediaPlayer?.status() ?: emptyMap<String, Any?>())
            }
            "stopMedia" -> {
                mediaPlayer?.stop()
                result.success(mediaPlayer?.status() ?: emptyMap<String, Any?>())
            }
            "seekMedia" -> {
                val positionMs = call.argument<Number>("positionMs")?.toLong()
                if (positionMs == null || positionMs < 0L) {
                    result.error("INVALID_SEEK_POSITION", "Seek position must be zero or greater.", null)
                } else {
                    mediaPlayer?.seekTo(positionMs)
                    result.success(mediaPlayer?.status() ?: emptyMap<String, Any?>())
                }
            }
            "mediaStatus" -> result.success(mediaPlayer?.status() ?: mapOf(
                "isPlaying" to false, "playWhenReady" to false, "state" to "idle",
                "positionMs" to 0L, "durationMs" to null, "mediaUri" to null
            ))
            "globalEffectCapabilities" -> result.success(globalOutputEffects.probe())
            "audioRouteStatus" -> result.success(audioRouteStatus())
            "setGlobalEffectsEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Global equalizer enabled must be a boolean.", null)
                } else if (globalOutputEffects.setEnabled(enabled)) {
                    result.success(globalOutputEffects.probe())
                } else {
                    result.error("GLOBAL_EFFECT_UNAVAILABLE", "This Android device did not accept the global output equalizer request.", globalOutputEffects.probe())
                }
            }
            "setGlobalBassBoostEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Global bass boost enabled must be a boolean.", null)
                } else if (globalOutputEffects.setBassBoostEnabled(enabled)) {
                    result.success(globalOutputEffects.probe())
                } else {
                    result.error("GLOBAL_EFFECT_UNAVAILABLE", "This Android device did not accept the global output bass boost request.", globalOutputEffects.probe())
                }
            }
            "setGlobalBandGain" -> {
                val band = call.argument<Int>("band")
                val gainDb = call.argument<Double>("gainDb")
                if (band == null || gainDb == null || band !in 0..9 || !gainDb.isFinite() || gainDb !in -12.0..12.0) {
                    result.error("INVALID_EQ_PARAMETER", "Band must be 0..9 and gain must be -12..12 dB.", null)
                } else if (globalOutputEffects.setBandGain(band, gainDb.toFloat())) {
                    result.success(globalOutputEffects.probe())
                } else {
                    result.error("GLOBAL_EFFECT_UNAVAILABLE", "The OEM global equalizer rejected this band update.", globalOutputEffects.probe())
                }
            }
            "setGlobalBassBoostStrength" -> {
                val strength = call.argument<Int>("strength")
                if (strength == null || strength !in 0..1000) {
                    result.error("INVALID_EQ_PARAMETER", "Bass boost strength must be 0..1000.", null)
                } else if (globalOutputEffects.setBassBoostStrength(strength)) {
                    result.success(globalOutputEffects.probe())
                } else {
                    result.error("GLOBAL_EFFECT_UNAVAILABLE", "This device does not expose adjustable global bass boost.", globalOutputEffects.probe())
                }
            }
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
                    // Keep the diagnostic tone isolated from the local music player.
                    // Running two independent output paths at once can compete for
                    // audio focus and makes listening tests difficult to interpret.
                    mediaPlayer?.pause()
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
                    val previousGain = bandGainsDb[band]
                    val nativeCode = if (engine == 0L) 0 else nativeSetBandGain(engine, band, gainDb.toFloat())
                    if (nativeCode != 0) {
                        result.error(
                            "NATIVE_EQ_REJECTED",
                            "Native DSP rejected band $band update (native status $nativeCode).",
                            mapOf("component" to "native", "status" to nativeCode, "band" to band)
                        )
                        return
                    }
                    val mediaOk = mediaPlayer?.setBandGain(band, gainDb.toFloat()) ?: true
                    if (!mediaOk) {
                        if (engine != 0L) nativeSetBandGain(engine, band, previousGain)
                        result.error(
                            "MEDIA3_EQ_REJECTED",
                            "Media3 DSP rejected band $band update; the native setting was rolled back.",
                            mapOf("component" to "media3", "band" to band)
                        )
                        return
                    }
                    bandGainsDb[band] = gainDb.toFloat()
                    result.success(null)
                }
            }
            "setOutputGain" -> {
                val gainDb = call.argument<Double>("gainDb")
                if (gainDb == null || !gainDb.isFinite() || gainDb !in -24.0..6.0) {
                    result.error("INVALID_EQ_PARAMETER", "Output gain must be -24..6 dB.", null)
                } else {
                    val previousGain = outputGainDb
                    val code = if (engine == 0L) 0 else nativeSetOutputGain(engine, gainDb.toFloat())
                    if (code != 0) {
                        result.error(
                            "NATIVE_EQ_REJECTED",
                            "Native DSP rejected output gain (native status $code).",
                            mapOf("component" to "native", "status" to code)
                        )
                        return
                    }
                    val mediaOk = mediaPlayer?.setOutputGain(gainDb.toFloat()) ?: true
                    if (!mediaOk) {
                        if (engine != 0L) nativeSetOutputGain(engine, previousGain)
                        result.error(
                            "MEDIA3_EQ_REJECTED",
                            "Media3 DSP rejected output gain; the native setting was rolled back.",
                            mapOf("component" to "media3")
                        )
                        return
                    }
                    outputGainDb = gainDb.toFloat()
                    result.success(null)
                }
            }
            "setSpatialEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Spatial enabled must be a boolean.", null)
                } else {
                    spatialEnabled = enabled
                    mediaPlayer?.setSpatialEnabled(enabled)
                    result.success(null)
                }
            }
            "setLimiterEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_EQ_PARAMETER", "Limiter enabled must be a boolean.", null)
                } else {
                    limiterEnabled = enabled
                    mediaPlayer?.setLimiterEnabled(enabled)
                    result.success(null)
                }
            }
            "setBypassed" -> {
                val bypassed = call.argument<Boolean>("bypassed")
                if (bypassed == null) {
                    result.error("INVALID_EQ_PARAMETER", "Bypass must be a boolean.", null)
                } else {
                    val previousBypass = this.bypassed
                    val code = if (engine == 0L) 0 else nativeSetBypassed(engine, bypassed)
                    if (code != 0) {
                        result.error(
                            "NATIVE_EQ_REJECTED",
                            "Native DSP rejected bypass update (native status $code).",
                            mapOf("component" to "native", "status" to code)
                        )
                        return
                    }
                    val mediaOk = mediaPlayer?.setBypassed(bypassed) ?: true
                    if (!mediaOk) {
                        if (engine != 0L) nativeSetBypassed(engine, previousBypass)
                        result.error(
                            "MEDIA3_EQ_REJECTED",
                            "Media3 DSP rejected bypass update; the native setting was rolled back.",
                            mapOf("component" to "media3")
                        )
                        return
                    }
                    this.bypassed = bypassed
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun audioRouteStatus(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return mapOf("supported" to false, "outputs" to emptyList<Map<String, Any?>>())
        }
        val manager = appContext.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
        val outputs = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .filter { it.isSink }
            .map { device ->
                val type = when (device.type) {
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "built_in_speaker"
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired_headphones"
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired_headset"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetooth_a2dp"
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth_sco"
                    AudioDeviceInfo.TYPE_BLE_HEADSET -> "bluetooth_le_headset"
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> "usb_audio"
                    AudioDeviceInfo.TYPE_HDMI,
                    AudioDeviceInfo.TYPE_HDMI_ARC,
                    AudioDeviceInfo.TYPE_HDMI_EARC -> "hdmi"
                    else -> "other"
                }
                mapOf(
                    "id" to device.id,
                    "type" to type,
                    "productName" to device.productName?.toString().orEmpty(),
                    "sampleRates" to device.sampleRates.toList(),
                    "channelCounts" to device.channelCounts.toList(),
                )
            }
        return mapOf(
            "supported" to true,
            "outputs" to outputs,
            "hasHeadphones" to outputs.any {
                it["type"] in setOf("wired_headphones", "wired_headset", "bluetooth_a2dp",
                    "bluetooth_sco", "bluetooth_le_headset", "usb_audio")
            },
            "note" to "Route detection only; it does not prove that global effects are applied to this route."
        )
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
        // Publish ownership immediately. Any later startup failure is handled by
        // stopPlayback(), including failures while allocating the PCM work buffer.
        track = audioTrack
        check(audioTrack.state == AudioTrack.STATE_INITIALIZED) {
            "Android AudioTrack initialization failed."
        }

        val pcm = ByteBuffer.allocateDirect(bytesPerBlock).order(ByteOrder.nativeOrder())
        val floats = pcm.asFloatBuffer()
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
                    if (!bypassed && spatialEnabled) {
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
                    if (!bypassed && limiterEnabled) {
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
                mainHandler.post {
                    channel.invokeMethod("playbackError", lastError)
                    // A worker-side failure does not pass through the Flutter stop
                    // method. Tear down the AudioTrack, focus request, and native
                    // engine on the main thread after this worker has unwound.
                    stopPlayback()
                }
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            routeCallback?.let { callback ->
                val manager = appContext.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
                manager.unregisterAudioDeviceCallback(callback)
            }
        }
        routeCallback = null
        mediaPlayer?.release()
        mediaPlayer = null
        globalOutputEffects.close()
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
