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
                return DefaultAudioSink.Builder(context)
                    .setEnableFloatOutput(false)
                    .setEnableAudioOutputPlaybackParameters(enableAudioOutputPlaybackParams)
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

    fun setBandGain(band: Int, gainDb: Float): Boolean =
        processor?.setBandGain(band, gainDb) ?: true

    fun setOutputGain(gainDb: Float): Boolean =
        processor?.setOutputGain(gainDb) ?: true

    fun setBypassed(bypassed: Boolean): Boolean =
        processor?.setBypassed(bypassed) ?: true

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
    )

    fun release() {
        player.release()
        processor = null
    }
}
