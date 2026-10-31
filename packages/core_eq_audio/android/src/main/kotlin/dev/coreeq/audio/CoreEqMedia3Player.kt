package dev.coreeq.audio

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

/**
 * In-app local-media player whose decoded PCM is routed through CORE-EQ's native processor.
 * This does not intercept audio produced by Spotify or any other application.
 */
internal class CoreEqMedia3Player(
    context: Context,
    private val onError: (String) -> Unit,
) {
    private var processor: CoreEqMedia3AudioProcessor? = null
    private val bandGainsDb = FloatArray(10)
    private var outputGainDb = 0.0f
    private var bypassed = false
    private var limiterEnabled = true
    private var spatialEnabled = false
    private val player: ExoPlayer

    init {
        val renderersFactory = object : DefaultRenderersFactory(context) {
            override fun buildAudioSink(
                context: Context,
                enableFloatOutput: Boolean,
                enableAudioOutputPlaybackParams: Boolean,
            ): AudioSink {
                val eqProcessor = CoreEqMedia3AudioProcessor()
                processor = eqProcessor
                for (band in bandGainsDb.indices) eqProcessor.setBandGain(band, bandGainsDb[band])
                eqProcessor.setOutputGain(outputGainDb)
                eqProcessor.setBypassed(bypassed)
                eqProcessor.setLimiterEnabled(limiterEnabled)
                eqProcessor.setSpatialEnabled(spatialEnabled)
                return DefaultAudioSink.Builder(context)
                    .setEnableFloatOutput(false)
                    .setAudioProcessors(arrayOf<AudioProcessor>(eqProcessor))
                    .build()
            }
        }
        player = ExoPlayer.Builder(context, renderersFactory).build()
        player.setAudioAttributes(
            androidx.media3.common.AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(),
            true,
        )
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                onError(error.message ?: "Media playback failed.")
            }
        })
    }

    fun play(uri: String) {
        require(uri.isNotBlank()) { "Media URI must not be empty." }
        player.setMediaItem(MediaItem.fromUri(Uri.parse(uri)))
        player.prepare()
        player.play()
    }

    fun pause() = player.pause()

    fun resume() = player.play()

    fun stop() {
        player.stop()
        player.clearMediaItems()
    }

    fun seekTo(positionMs: Long) {
        player.seekTo(positionMs.coerceAtLeast(0L))
    }

    fun applySettings(
        bands: FloatArray,
        outputGain: Float,
        isBypassed: Boolean,
        isLimiterEnabled: Boolean,
        isSpatialEnabled: Boolean,
    ) {
        for (band in bandGainsDb.indices) {
            val requestedGain = bands.getOrElse(band) { 0.0f }
            require(processor?.setBandGain(band, requestedGain) != false) {
                "Media3 DSP rejected band $band while applying saved settings."
            }
            bandGainsDb[band] = requestedGain
        }
        require(processor?.setOutputGain(outputGain) != false) {
            "Media3 DSP rejected saved output gain."
        }
        outputGainDb = outputGain
        require(processor?.setBypassed(isBypassed) != false) {
            "Media3 DSP rejected saved bypass state."
        }
        bypassed = isBypassed
        limiterEnabled = isLimiterEnabled
        spatialEnabled = isSpatialEnabled
        processor?.setLimiterEnabled(limiterEnabled)
        processor?.setSpatialEnabled(spatialEnabled)
    }

    fun setBandGain(band: Int, gainDb: Float): Boolean {
        if (band !in bandGainsDb.indices) return false
        if (processor?.setBandGain(band, gainDb) == false) return false
        bandGainsDb[band] = gainDb
        return true
    }

    fun setOutputGain(gainDb: Float): Boolean {
        if (processor?.setOutputGain(gainDb) == false) return false
        outputGainDb = gainDb
        return true
    }

    fun setLimiterEnabled(value: Boolean) {
        limiterEnabled = value
        processor?.setLimiterEnabled(value)
    }

    fun setSpatialEnabled(value: Boolean) {
        spatialEnabled = value
        processor?.setSpatialEnabled(value)
    }

    fun setBypassed(value: Boolean): Boolean {
        if (processor?.setBypassed(value) == false) return false
        bypassed = value
        return true
    }

    fun status(): Map<String, Any?> = mapOf(
        "isPlaying" to player.isPlaying,
        "playWhenReady" to player.playWhenReady,
        "state" to when (player.playbackState) {
            Player.STATE_IDLE -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> "ready"
            Player.STATE_ENDED -> "ended"
            else -> "unknown"
        },
        "positionMs" to player.currentPosition.coerceAtLeast(0L),
        "durationMs" to if (player.duration >= 0L) player.duration else null,
        "mediaUri" to player.currentMediaItem?.localConfiguration?.uri?.toString(),
        "inputPeakLevel" to (processor?.inputPeakLevel ?: 0.0f),
        "outputPeakLevel" to (processor?.outputPeakLevel ?: 0.0f),
        "inputRmsLevel" to (processor?.inputRmsLevel ?: 0.0f),
        "outputRmsLevel" to (processor?.outputRmsLevel ?: 0.0f),
        "signalDifferenceRms" to (processor?.signalDifferenceRms ?: 0.0f),
        "processedFrames" to (processor?.processedFrames ?: 0L),
        "sampleRateHz" to (processor?.currentSampleRateHz ?: 0),
        "channels" to (processor?.currentChannelCount ?: 0),
        "processorConfigured" to (processor?.isConfigured ?: false),
        "lastProcessedUptimeMs" to (processor?.lastProcessedUptimeMs ?: 0L),
    )

    fun release() {
        player.release()
        processor = null
    }
}
