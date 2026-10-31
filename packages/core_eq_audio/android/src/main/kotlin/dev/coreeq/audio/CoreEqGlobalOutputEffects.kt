package dev.coreeq.audio

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import java.io.Closeable

/**
 * Optional OEM-provided effects attached to Android's global output mix (session 0).
 *
 * Android does not guarantee that an app can attach effects to session 0. Construction
 * is therefore treated as a capability probe, never as proof of universal system EQ.
 */
internal class CoreEqGlobalOutputEffects : Closeable {
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var lastError: String? = null

    @Synchronized
    fun probe(): Map<String, Any?> {
        ensureCreated()
        val eq = equalizer
        val bass = bassBoost
        return mapOf(
            "available" to (eq != null || bass != null),
            "globalOutputSession" to 0,
            "equalizerAvailable" to (eq != null),
            "bassBoostAvailable" to (bass != null),
            "equalizerEnabled" to runCatching { eq?.enabled == true }.getOrDefault(false),
            "bassBoostEnabled" to runCatching { bass?.enabled == true }.getOrDefault(false),
            "bandCount" to runCatching { eq?.numberOfBands?.toInt() ?: 0 }.getOrDefault(0),
            "bandLevelRangeMb" to runCatching {
                eq?.bandLevelRange?.map { it.toInt() } ?: emptyList<Int>()
            }.getOrDefault(emptyList<Int>()),
            "error" to lastError,
            "scope" to "OEM-dependent global output mix; not guaranteed for every device or route"
        )
    }

    @Synchronized
    fun setEnabled(enabled: Boolean): Boolean {
        ensureCreated()
        val eq = equalizer ?: return false
        return runCatching {
            eq.enabled = enabled
            eq.enabled == enabled
        }.onFailure { lastError = it.message ?: it.javaClass.simpleName }.getOrDefault(false)
    }

    @Synchronized
    fun setBassBoostEnabled(enabled: Boolean): Boolean {
        ensureCreated()
        val bass = bassBoost ?: return false
        return runCatching {
            bass.enabled = enabled
            bass.enabled == enabled
        }.onFailure { lastError = it.message ?: it.javaClass.simpleName }.getOrDefault(false)
    }

    /** Maps CORE-EQ's 10 fixed bands to the nearest bands exposed by the device. */
    @Synchronized
    fun setBandGain(band: Int, gainDb: Float): Boolean {
        if (band !in 0..9 || !gainDb.isFinite() || gainDb !in -12.0f..12.0f) return false
        ensureCreated()
        val eq = equalizer ?: return false
        return runCatching {
            val count = eq.numberOfBands.toInt()
            if (count <= 0) return false
            val targetHz = floatArrayOf(31.25f, 62.5f, 125f, 250f, 500f, 1000f, 2000f, 4000f, 8000f, 16000f)[band]
            val targetMilliHz = (targetHz * 1000f).toInt()
            val selected = (0 until count).minByOrNull { index ->
                kotlin.math.abs(eq.getCenterFreq(index.toShort()) - targetMilliHz)
            } ?: return false
            val range = eq.bandLevelRange
            val requestedMb = (gainDb * 100f).toInt()
            val level = requestedMb.coerceIn(range[0].toInt(), range[1].toInt()).toShort()
            eq.setBandLevel(selected.toShort(), level)
            eq.getBandLevel(selected.toShort()) == level
        }.onFailure { lastError = it.message ?: it.javaClass.simpleName }.getOrDefault(false)
    }

    @Synchronized
    fun setBassBoostStrength(strength: Int): Boolean {
        if (strength !in 0..1000) return false
        ensureCreated()
        val bass = bassBoost ?: return false
        return runCatching {
            if (!bass.strengthSupported) return false
            bass.setStrength(strength.toShort())
            bass.roundedStrength.toInt() == strength
        }.onFailure { lastError = it.message ?: it.javaClass.simpleName }.getOrDefault(false)
    }

    private fun ensureCreated() {
        if (equalizer != null || bassBoost != null) return
        lastError = null
        try {
            equalizer = Equalizer(0, 0)
        } catch (error: Exception) {
            lastError = "Global Equalizer unavailable: ${error.message ?: error.javaClass.simpleName}"
        }
        try {
            bassBoost = BassBoost(0, 0)
        } catch (error: Exception) {
            val detail = "Global BassBoost unavailable: ${error.message ?: error.javaClass.simpleName}"
            lastError = listOfNotNull(lastError, detail).joinToString("; ")
        }
    }

    @Synchronized
    override fun close() {
        runCatching { equalizer?.release() }
        runCatching { bassBoost?.release() }
        equalizer = null
        bassBoost = null
    }
}
