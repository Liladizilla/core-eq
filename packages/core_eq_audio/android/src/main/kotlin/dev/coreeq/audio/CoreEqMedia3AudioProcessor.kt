package dev.coreeq.audio

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Media3 processor for mono or stereo PCM16 at common music sample rates.
 * This processes only audio in CORE-EQ's own Media3 player, not other apps.
 */
class CoreEqMedia3AudioProcessor : BaseAudioProcessor() {
    private var engine: Long = 0L
    private var channels = 0
    private var sampleRateHz = 0
    private val bandGainsDb = FloatArray(10)
    private var outputGainDb = 0.0f
    private var bypassed = false
    private var limiterEnabled = true
    private var spatialEnabled = false
    private var limiterGain = 1.0f
    private var floatScratch: ByteBuffer = ByteBuffer.allocateDirect(0).order(ByteOrder.nativeOrder())
    @Volatile var inputPeakLevel: Float = 0.0f
        private set
    @Volatile var outputPeakLevel: Float = 0.0f
        private set
    @Volatile var processedFrames: Long = 0L
        private set
    val currentSampleRateHz: Int get() = sampleRateHz
    val currentChannelCount: Int get() = channels

    init {
        System.loadLibrary("core_eq")
        ensureEngine()
    }

    private fun ensureEngine() {
        if (engine == 0L) {
            engine = nativeCreate()
            check(engine != 0L) { "Could not create CORE-EQ native DSP engine." }
            if (sampleRateHz > 0) applySettings()
        }
    }

    private fun applySettings() {
        for (band in bandGainsDb.indices) {
            check(nativeSetBandGain(engine, band, bandGainsDb[band], sampleRateHz) == 0) {
                "Native DSP rejected gain for band $band at $sampleRateHz Hz."
            }
        }
        check(nativeSetOutputGain(engine, outputGainDb) == 0) { "Native DSP rejected output gain." }
        check(nativeSetBypassed(engine, bypassed) == 0) { "Native DSP rejected bypass state." }
    }

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.sampleRate !in 22050..96000 ||
            inputAudioFormat.channelCount !in 1..2 ||
            inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        val changedRate = sampleRateHz != inputAudioFormat.sampleRate
        sampleRateHz = inputAudioFormat.sampleRate
        channels = inputAudioFormat.channelCount
        ensureEngine()
        if (changedRate) applySettings()
        return inputAudioFormat
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val inputBytes = inputBuffer.remaining()
        if (inputBytes == 0) return
        check(channels > 0 && inputBytes % (channels * 2) == 0) {
            "Input buffer does not contain complete PCM frames."
        }
        val samples = inputBytes / 2
        val frames = samples / channels
        val requiredFloatBytes = samples * 4
        if (floatScratch.capacity() < requiredFloatBytes) {
            floatScratch = ByteBuffer.allocateDirect(requiredFloatBytes).order(ByteOrder.nativeOrder())
        }
        floatScratch.clear()
        val input = inputBuffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        val floatView = floatScratch.asFloatBuffer()
        var inputPeak = 0.0f
        repeat(samples) {
            val sample = input.short / 32768.0f
            inputPeak = maxOf(inputPeak, kotlin.math.abs(sample))
            floatView.put(sample)
        }
        inputPeakLevel = inputPeak
        check(nativeProcess(engine, floatScratch, frames, channels) == 0) {
            "CORE-EQ native DSP rejected a Media3 PCM block."
        }
        val output = replaceOutputBuffer(inputBytes).order(ByteOrder.LITTLE_ENDIAN)
        floatView.position(0)
        if (spatialEnabled && channels == 2) {
            for (frame in 0 until frames) {
                val index = frame * 2
                val left = floatView.get(index)
                val right = floatView.get(index + 1)
                val mid = (left + right) * 0.5f
                val side = (left - right) * 0.5f * 1.6f
                floatView.put(index, mid + side)
                floatView.put(index + 1, mid - side)
            }
        }
        var blockPeak = 0.0f
        repeat(samples) { blockPeak = maxOf(blockPeak, kotlin.math.abs(floatView.get(it))) }
        if (limiterEnabled) {
            val targetGain = if (blockPeak > 0.9f) 0.9f / blockPeak else 1.0f
            limiterGain = if (targetGain < limiterGain) targetGain
                else limiterGain + (targetGain - limiterGain) * 0.15f
        } else {
            limiterGain = 1.0f
        }
        var outputPeak = 0.0f
        repeat(samples) {
            val processedSample = floatView.get() * limiterGain
            outputPeak = maxOf(outputPeak, kotlin.math.abs(processedSample))
            val sample = processedSample.coerceIn(-1.0f, 1.0f)
            val pcm = (sample * 32767.0f).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
            output.putShort(pcm.toShort())
        }
        outputPeakLevel = outputPeak
        processedFrames += frames.toLong()
        inputBuffer.position(inputBuffer.limit())
        output.flip()
    }

    fun setBandGain(band: Int, gainDb: Float): Boolean {
        if (band !in bandGainsDb.indices || !gainDb.isFinite() || gainDb !in -12.0f..12.0f) return false
        bandGainsDb[band] = gainDb
        return engine == 0L || sampleRateHz == 0 ||
            nativeSetBandGain(engine, band, gainDb, sampleRateHz) == 0
    }

    fun setOutputGain(gainDb: Float): Boolean {
        if (!gainDb.isFinite() || gainDb !in -24.0f..6.0f) return false
        outputGainDb = gainDb
        return engine == 0L || nativeSetOutputGain(engine, gainDb) == 0
    }

    fun setLimiterEnabled(value: Boolean) { limiterEnabled = value }

    fun setSpatialEnabled(value: Boolean) { spatialEnabled = value }

    fun setBypassed(value: Boolean): Boolean {
        bypassed = value
        return engine == 0L || nativeSetBypassed(engine, value) == 0
    }

    override fun onFlush() {
        if (engine != 0L) nativeReset(engine)
        if (sampleRateHz > 0 && engine != 0L) applySettings()
    }

    override fun onReset() {
        if (engine != 0L) {
            nativeDestroy(engine)
            engine = 0L
        }
        floatScratch = ByteBuffer.allocateDirect(0).order(ByteOrder.nativeOrder())
        channels = 0
        sampleRateHz = 0
        inputPeakLevel = 0.0f
        outputPeakLevel = 0.0f
        processedFrames = 0L
        limiterGain = 1.0f
    }

    private external fun nativeCreate(): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeProcess(handle: Long, pcm: ByteBuffer, frames: Int, channels: Int): Int
    private external fun nativeSetBandGain(handle: Long, band: Int, gainDb: Float, sampleRateHz: Int): Int
    private external fun nativeSetOutputGain(handle: Long, gainDb: Float): Int
    private external fun nativeSetBypassed(handle: Long, bypassed: Boolean): Int
    private external fun nativeReset(handle: Long): Int
}
