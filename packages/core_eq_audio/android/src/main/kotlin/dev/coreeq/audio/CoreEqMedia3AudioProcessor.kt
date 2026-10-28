package dev.coreeq.audio

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Media3 processor that routes decoded 48 kHz stereo PCM through CORE-EQ's native DSP.
 * This is a player-pipeline component, not a hook into audio from other applications.
 */
class CoreEqMedia3AudioProcessor : BaseAudioProcessor() {
    private var engine: Long = 0L
    private var channels = 0
    private var sampleRateHz = 0
    private var floatScratch: ByteBuffer = ByteBuffer.allocateDirect(0).order(ByteOrder.nativeOrder())

    init {
        System.loadLibrary("core_eq")
        engine = nativeCreate()
        check(engine != 0L) { "Could not create CORE-EQ native DSP engine." }
    }

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.sampleRate != 48000 || inputAudioFormat.channelCount != 2 ||
            inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        sampleRateHz = inputAudioFormat.sampleRate
        channels = inputAudioFormat.channelCount
        return inputAudioFormat
    }

    override fun onQueueInput(inputBuffer: ByteBuffer) {
        val inputBytes = inputBuffer.remaining()
        if (inputBytes == 0) return
        check(inputBytes % (channels * 2) == 0) { "Input buffer does not contain complete PCM frames." }
        val samples = inputBytes / 2
        val frames = samples / channels
        val requiredFloatBytes = samples * 4
        if (floatScratch.capacity() < requiredFloatBytes) {
            floatScratch = ByteBuffer.allocateDirect(requiredFloatBytes).order(ByteOrder.nativeOrder())
        }
        floatScratch.clear()
        val input = inputBuffer.order(ByteOrder.LITTLE_ENDIAN)
        val floatView = floatScratch.asFloatBuffer()
        repeat(samples) { floatView.put(input.short / 32768.0f) }
        check(nativeProcess(engine, floatScratch, frames, channels) == 0) {
            "CORE-EQ native DSP rejected a Media3 PCM block."
        }
        val output = replaceOutputBuffer(inputBytes).order(ByteOrder.LITTLE_ENDIAN)
        floatView.position(0)
        repeat(samples) {
            val sample = floatView.get().coerceIn(-1.0f, 1.0f)
            val pcm = (sample * 32767.0f).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
            output.putShort(pcm.toShort())
        }
        inputBuffer.position(inputBuffer.limit())
        output.flip()
    }

    fun setBandGain(band: Int, gainDb: Float): Boolean =
        engine != 0L && nativeSetBandGain(engine, band, gainDb) == 0

    fun setOutputGain(gainDb: Float): Boolean =
        engine != 0L && nativeSetOutputGain(engine, gainDb) == 0

    fun setBypassed(bypassed: Boolean): Boolean =
        engine != 0L && nativeSetBypassed(engine, bypassed) == 0

    override fun onFlush() {
        if (engine != 0L) nativeReset(engine)
    }

    override fun onReset() {
        if (engine != 0L) {
            nativeDestroy(engine)
            engine = 0L
        }
        floatScratch = ByteBuffer.allocateDirect(0).order(ByteOrder.nativeOrder())
        channels = 0
        sampleRateHz = 0
    }

    private external fun nativeCreate(): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeProcess(handle: Long, pcm: ByteBuffer, frames: Int, channels: Int): Int
    private external fun nativeSetBandGain(handle: Long, band: Int, gainDb: Float): Int
    private external fun nativeSetOutputGain(handle: Long, gainDb: Float): Int
    private external fun nativeSetBypassed(handle: Long, bypassed: Boolean): Int
    private external fun nativeReset(handle: Long): Int
}
