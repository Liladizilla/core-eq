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
        assertEquals(0.4f, CoreEqPostProcessing.spatialLeft(0.4f, 0.4f), 0.0001f)
        assertEquals(0.4f, CoreEqPostProcessing.spatialRight(0.4f, 0.4f), 0.0001f)
    }

    @Test fun spatialProcessingExpandsSideSignalSymmetrically() {
        assertEquals(0.8f, CoreEqPostProcessing.spatialLeft(0.5f, -0.5f), 0.0001f)
        assertEquals(-0.8f, CoreEqPostProcessing.spatialRight(0.5f, -0.5f), 0.0001f)
    }
}
