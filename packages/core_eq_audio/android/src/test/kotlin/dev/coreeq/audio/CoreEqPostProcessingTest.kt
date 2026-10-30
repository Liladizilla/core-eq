package dev.coreeq.audio

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CoreEqPostProcessingTest {
    @Test fun bypassCopyPreservesEveryPcm16BitIncludingExtremes() {
        val samples = shortArrayOf(Short.MIN_VALUE, -12345, -1, 0, 1, 12345, Short.MAX_VALUE)
        val input = ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        val output = ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        samples.forEach(input::putShort)
        input.flip()

        val peak = CoreEqPostProcessing.copyPcm16AndMeasurePeak(input, output, samples.size)

        assertEquals(1.0f, peak, 0.0001f)
        output.flip()
        samples.forEach { assertEquals(it, output.short) }
        assertEquals(0, input.remaining())
        assertEquals(0, output.remaining())
    }

    @Test fun bypassCopyMeasuresSilenceAsZero() {
        val input = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN)
        val output = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN)

        assertEquals(0.0f, CoreEqPostProcessing.copyPcm16AndMeasurePeak(input, output, 4), 0.0f)
    }

    @Test fun limiterAttacksImmediatelyAboveCeiling() {
        assertEquals(0.45f, CoreEqPostProcessing.nextLimiterGain(1.0f, 1.8f), 0.0001f)
    }

    @Test fun limiterReleasesGraduallyBelowCeiling() {
        assertEquals(0.575f, CoreEqPostProcessing.nextLimiterGain(0.5f, 0.5f), 0.0001f)
    }

    @Test fun limiterNeverRequestsGainAboveUnity() {
        assertEquals(1.0f, CoreEqPostProcessing.nextLimiterGain(1.0f, 0.2f), 0.0001f)
    }

    @Test fun limiterHandlesNonFinitePeakSafely() {
        assertEquals(1.0f, CoreEqPostProcessing.nextLimiterGain(1.0f, Float.NaN), 0.0001f)
    }

    @Test fun spatialProcessingPreservesCenterSignal() {
        assertEquals(0.4f, CoreEqPostProcessing.spatialLeft(0.4f, 0.4f), 0.0001f)
        assertEquals(0.4f, CoreEqPostProcessing.spatialRight(0.4f, 0.4f), 0.0001f)
    }

    @Test fun spatialProcessingExpandsSideSignalSymmetrically() {
        assertEquals(0.8f, CoreEqPostProcessing.spatialLeft(0.5f, -0.5f), 0.0001f)
        assertEquals(-0.8f, CoreEqPostProcessing.spatialRight(0.5f, -0.5f), 0.0001f)
    }
}
