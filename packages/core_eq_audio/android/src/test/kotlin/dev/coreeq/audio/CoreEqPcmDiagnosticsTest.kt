package dev.coreeq.audio

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CoreEqPcmDiagnosticsTest {
    @Test fun identicalPcmHasZeroDifferenceAndMatchingRms() {
        val samples = shortArrayOf(-16384, 0, 16384, 8192)
        val input = pcm(samples)
        val output = pcm(samples)

        val result = CoreEqPcmDiagnostics.measurePcm16(input, output, samples.size)

        assertEquals(result.inputRms, result.outputRms, 0.000001f)
        assertEquals(0.0f, result.differenceRms, 0.0f)
        assertEquals(0, input.position())
        assertEquals(0, output.position())
    }

    @Test fun changedPcmReportsExpectedDifferenceRms() {
        val input = pcm(shortArrayOf(0, 0, 0, 0))
        val output = pcm(shortArrayOf(16384, -16384, 16384, -16384))

        val result = CoreEqPcmDiagnostics.measurePcm16(input, output, 4)

        assertEquals(0.0f, result.inputRms, 0.0f)
        assertEquals(0.5f, result.outputRms, 0.000001f)
        assertEquals(0.5f, result.differenceRms, 0.000001f)
    }

    @Test fun rejectsEmptySampleCount() {
        assertThrows(IllegalArgumentException::class.java) {
            CoreEqPcmDiagnostics.measurePcm16(pcm(shortArrayOf()), pcm(shortArrayOf()), 0)
        }
    }

    @Test fun rejectsBuffersShorterThanRequestedSamples() {
        assertThrows(IllegalArgumentException::class.java) {
            CoreEqPcmDiagnostics.measurePcm16(pcm(shortArrayOf(1)), pcm(shortArrayOf(1)), 2)
        }
    }

    private fun pcm(samples: ShortArray): ByteBuffer =
        ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN).apply {
            samples.forEach(::putShort)
            flip()
        }
}
