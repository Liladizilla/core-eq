package dev.coreeq.audio

import org.junit.Assert.assertEquals
import org.junit.Test

class CoreEqPostProcessingTest {
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
        val result = CoreEqPostProcessing.spatialSample(0.4f, 0.4f)
        assertEquals(0.4f, result.first, 0.0001f)
        assertEquals(0.4f, result.second, 0.0001f)
    }

    @Test fun spatialProcessingExpandsSideSignalSymmetrically() {
        val result = CoreEqPostProcessing.spatialSample(0.5f, -0.5f)
        assertEquals(0.8f, result.first, 0.0001f)
        assertEquals(-0.8f, result.second, 0.0001f)
    }
}
