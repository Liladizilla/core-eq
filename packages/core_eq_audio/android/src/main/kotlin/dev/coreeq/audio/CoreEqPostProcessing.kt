package dev.coreeq.audio

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Allocation-free post-DSP math for the real-time audio thread. */
internal object CoreEqPostProcessing {
    const val LIMITER_CEILING = 0.9f
    private const val LIMITER_RELEASE = 0.15f
    private const val SPATIAL_WIDTH = 1.6f

    /**
     * Copies signed PCM16 samples without changing a single bit and returns
     * the normalized absolute peak. Buffers must be little-endian.
     */
    fun copyPcm16AndMeasurePeak(input: ByteBuffer, output: ByteBuffer, sampleCount: Int): Float {
        var peak = 0.0f
        repeat(sampleCount) {
            val sample = input.short
            output.putShort(sample)
            peak = maxOf(peak, kotlin.math.abs(sample / 32768.0f))
        }
        return peak
    }

    fun nextLimiterGain(currentGain: Float, blockPeak: Float): Float {
        val safePeak = if (blockPeak.isFinite()) kotlin.math.abs(blockPeak) else 0.0f
        val current = currentGain.coerceIn(0.0f, 1.0f)
        val target = if (safePeak > LIMITER_CEILING) LIMITER_CEILING / safePeak else 1.0f
        return if (target < current) target else current + (target - current) * LIMITER_RELEASE
    }

    fun spatialLeft(left: Float, right: Float): Float {
        val mid = (left + right) * 0.5f
        val side = (left - right) * 0.5f * SPATIAL_WIDTH
        return mid + side
    }

    fun spatialRight(left: Float, right: Float): Float {
        val mid = (left + right) * 0.5f
        val side = (left - right) * 0.5f * SPATIAL_WIDTH
        return mid - side
    }
}
