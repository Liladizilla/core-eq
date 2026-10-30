package dev.coreeq.audio

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

internal data class CoreEqPcmDiagnostics(
    val inputRms: Float,
    val outputRms: Float,
    val differenceRms: Float,
) {
    companion object {
        fun measurePcm16(
            input: ByteBuffer,
            output: ByteBuffer,
            sampleCount: Int,
        ): CoreEqPcmDiagnostics {
            require(sampleCount > 0) { "PCM diagnostics require at least one sample." }
            require(input.remaining() >= sampleCount * 2) { "Input buffer is shorter than the requested PCM sample count." }
            require(output.remaining() >= sampleCount * 2) { "Output buffer is shorter than the requested PCM sample count." }

            val original = input.duplicate().order(ByteOrder.LITTLE_ENDIAN)
            val processed = output.duplicate().order(ByteOrder.LITTLE_ENDIAN)
            var inputSquares = 0.0
            var outputSquares = 0.0
            var differenceSquares = 0.0
            repeat(sampleCount) {
                val before = original.short / 32768.0
                val after = processed.short / 32768.0
                inputSquares += before * before
                outputSquares += after * after
                val difference = after - before
                differenceSquares += difference * difference
            }
            return CoreEqPcmDiagnostics(
                inputRms = sqrt(inputSquares / sampleCount).toFloat(),
                outputRms = sqrt(outputSquares / sampleCount).toFloat(),
                differenceRms = sqrt(differenceSquares / sampleCount).toFloat(),
            )
        }
    }
}
