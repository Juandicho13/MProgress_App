package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Reglas del PLAN_F12B (Paso 2 y Paso 4), con los casos mínimos del plan. */
class PlanF12BTest {
    private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)
    private fun pesos(v: Long) = v * 100

    private val tresCuotas = RecurringRecord(kind = EntryKind.GASTO, name = "Celular", amountMinor = pesos(300_000), cycle = Cycle.Mensual,
        nextDate = d(2026, 11, 10), totalCount = 3)

    @Test fun cuotas_mensual_de_3_genera_solo_3_fechas() {
        assertEquals(listOf(d(2026, 11, 10), d(2026, 12, 10), d(2027, 1, 10)), RecurringMath.occurrences(tresCuotas, d(2027, 12, 31)))
        assertEquals(emptyList<LocalDate>(), BalanceCalculator.pendingOccurrences(tresCuotas, d(2027, 2, 1)))
    }

    @Test fun cuotas_con_una_pagada_noviembre_no_cuenta() {
        val pagada = RecurringMath.afterPaid(tresCuotas)
        assertEquals(1, pagada.paidCount)
        assertEquals(d(2026, 12, 10), pagada.nextDate)
        assertEquals(emptyList<LocalDate>(), BalanceCalculator.pendingOccurrences(pagada, d(2026, 11, 1)))
        assertEquals(listOf(d(2026, 12, 10), d(2027, 1, 10)), RecurringMath.occurrences(pagada, d(2027, 12, 31)))
        assertEquals("Cuota 2 de 3", RecurringMath.endText(pagada))
    }

    @Test fun cuotas_al_llegar_al_total_termina() {
        var r = tresCuotas
        repeat(3) { r = RecurringMath.afterPaid(r) }
        assertEquals(3, r.paidCount)
        assertTrue(r.finished)
        assertFalse(r.active)
        assertEquals(emptyList<LocalDate>(), RecurringMath.occurrences(r, d(2030, 1, 1)))
    }

    @Test fun fecha_final_semanal_no_genera_enero() {
        val semanal = RecurringRecord(kind = EntryKind.GASTO, name = "Clases", amountMinor = pesos(50_000), cycle = Cycle.Semanal,
            nextDate = d(2026, 12, 1), endDate = d(2026, 12, 31))
        val fechas = RecurringMath.occurrences(semanal, d(2027, 3, 1))
        assertEquals(listOf(d(2026, 12, 1), d(2026, 12, 8), d(2026, 12, 15), d(2026, 12, 22), d(2026, 12, 29)), fechas)
        assertTrue(BalanceCalculator.pendingOccurrences(semanal, d(2027, 1, 15)).isEmpty())
        // Marcar pagado el último deja el pago terminado: la siguiente fecha pasa el 31 dic.
        assertTrue(RecurringMath.afterPaid(semanal.copy(nextDate = d(2026, 12, 29))).finished)
        assertEquals("Hasta 31 dic 2026", RecurringMath.endText(semanal))
    }

    @Test fun sin_fin_sigue_igual() {
        val renta = tresCuotas.copy(totalCount = null)
        assertNull(RecurringMath.endText(renta))
        assertEquals(14, RecurringMath.occurrences(renta, d(2027, 12, 31)).size)
    }

    @Test fun puntos_por_cada_mil() {
        assertEquals(84L, RewardMath.pointsFor(pesos(84_300), 1.0))
        assertEquals(126L, RewardMath.pointsFor(pesos(84_300), 1.5))
        assertEquals(0L, RewardMath.pointsFor(pesos(999), 1.0))
        assertEquals(0L, RewardMath.pointsFor(pesos(84_300), null))
        assertEquals(2L, RewardMath.pointsFor(pesos(1_000), 2.0))
    }

    @Test fun lector_de_sms_y_recibos() {
        val c = SmsParser.parse("Bancolombia: Compraste \$84.300,00 en EXITO CALLE 80 con tu T.Cred *4417, el 06/11/2026")!!
        assertEquals(EntryKind.GASTO, c.kind)
        assertEquals(pesos(84_300), c.amountMinor)
        assertEquals("4417", c.last4)
        assertEquals("Bancolombia", c.bank)
        assertEquals("Exito Calle 80", c.merchant)
        val n = SmsParser.parse("Nequi: Te enviaron \$45.500 de Mariana")!!
        assertEquals(EntryKind.INGRESO, n.kind)
        assertEquals(pesos(32_400), ReceiptParser.total(listOf("FARMACIA PASTEUR", "NIT 800.123", "SUBTOTAL 27.227", "IVA 5.173", "TOTAL \$32.400")))
    }

    @Test fun notificaciones_wallet_y_bancos() {
        val w = NotificationParser.parse("com.google.android.apps.walletnfcrel", "ÉXITO CALLE 80", "\$ 84.300,00 con Visa •••• 4417")!!
        assertEquals(EntryKind.GASTO, w.kind)
        assertEquals(pesos(84_300), w.amountMinor)
        assertEquals("4417", w.last4)
        assertEquals("Éxito Calle 80", w.merchant)
        assertTrue(!w.needsReview)
        val n = NotificationParser.parse("com.nequi.MobileApp", "Nequi", "Pagaste \$45.500 en RAPPI")!!
        assertEquals("Nequi", n.bank)
        assertEquals(pesos(45_500), n.amountMinor)
        assertNull(NotificationParser.parse("com.nequi.MobileApp", "Nequi", "Tienes una nueva oferta"))
    }
}
