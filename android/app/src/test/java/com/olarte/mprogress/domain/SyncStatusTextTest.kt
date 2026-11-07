package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant

/** Pastilla, hoja de estado y reintentos (F10-04), las mismas de ios/MProgressTests/Domain/SyncStatusTextTests.swift. */
class SyncStatusTextTest {
    @Test fun pillStatesAndTexts() {
        assertNull(SyncPill.state(signedIn = false, online = false, running = true, pending = 3, failed = 1, hasError = true))
        assertEquals(SyncPill.AlDia, SyncPill.state(true, true, false, 0, 0, false))
        assertEquals(SyncPill.Sincronizando, SyncPill.state(true, true, true, 0, 0, false))
        assertEquals(SyncPill.Sincronizando, SyncPill.state(true, true, false, 2, 0, false))
        assertEquals(SyncPill.SinConexion(3), SyncPill.state(true, false, true, 3, 1, true))
        assertEquals(SyncPill.Error, SyncPill.state(true, true, false, 3, 1, false))
        assertEquals(SyncPill.Error, SyncPill.state(true, true, false, 0, 0, true))
        assertEquals(SyncPill.Sincronizando, SyncPill.state(true, true, true, 0, 2, true))

        assertEquals("Al día", SyncPill.AlDia.text)
        assertEquals("Sincronizando…", SyncPill.Sincronizando.text)
        assertEquals("Sin conexión · 3 pendientes", SyncPill.SinConexion(3).text)
        assertEquals("Sin conexión · 1 pendiente", SyncPill.SinConexion(1).text)
        assertEquals("Sin conexión", SyncPill.SinConexion(0).text)
        assertEquals("Error al sincronizar", SyncPill.Error.text)
    }

    @Test fun relativeTime() {
        val now = Instant.parse("2026-11-08T15:00:00Z")
        assertEquals("Todavía no", SyncText.relative(null, now))
        assertEquals("Hace un momento", SyncText.relative(now.minusSeconds(20), now))
        assertEquals("Hace un momento", SyncText.relative(now.plusSeconds(5), now))
        assertEquals("Hace 2 min", SyncText.relative(now.minusSeconds(120), now))
        assertEquals("Hace 59 min", SyncText.relative(now.minusSeconds(59 * 60), now))
        assertEquals("Hace 3 h", SyncText.relative(now.minusSeconds(3 * 3600), now))
        assertEquals("Ayer", SyncText.relative(now.minusSeconds(30 * 3600), now))
        assertEquals("Hace 4 días", SyncText.relative(now.minusSeconds(4 * 86400), now))
    }

    @Test fun pendingGroupedByType() {
        assertEquals("Nada pendiente", SyncText.pendingSummary(emptyMap()))
        assertEquals("Nada pendiente", SyncText.pendingSummary(mapOf("entries" to 0)))
        assertEquals("3 movimientos, 1 pago fijo", SyncText.pendingSummary(mapOf("recurring" to 1, "entries" to 3)))
        assertEquals("1 movimiento, 2 cuentas o tarjetas, 1 nombre de comercio, 2 cambios",
            SyncText.pendingSummary(mapOf("entries" to 1, "products" to 2, "merchant_alias" to 1, "otra" to 2)))
        assertEquals("Conectado", SyncText.connection(true))
        assertEquals("Sin conexión", SyncText.connection(false))
        assertNull(SyncText.failedText(0))
        assertEquals("1 cambio no subió después de 3 intentos.", SyncText.failedText(1))
        assertEquals("4 cambios no subieron después de 3 intentos.", SyncText.failedText(4))
    }

    @Test fun backoffGrowsAndStopsAtFiveMinutes() {
        assertEquals(5L, SyncBackoff.delaySeconds(0))
        assertEquals(5L, SyncBackoff.delaySeconds(1))
        assertEquals(15L, SyncBackoff.delaySeconds(2))
        assertEquals(60L, SyncBackoff.delaySeconds(4))
        assertEquals(300L, SyncBackoff.delaySeconds(6))
        assertEquals(300L, SyncBackoff.delaySeconds(50))
    }
}
