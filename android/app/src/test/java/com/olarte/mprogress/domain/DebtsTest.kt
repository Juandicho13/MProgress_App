package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/** Las mismas pruebas de DebtsTests.swift de iOS. */
class DebtsTest {
    private fun pesos(v: Long) = v * 100
    private fun d(m: Int, day: Int) = LocalDate.of(2026, m, day)
    private val hoy = d(11, 10)
    private fun deuda(person: String, dir: DebtDirection, units: Long, day: Int = 1, due: LocalDate? = null) =
        DebtRecord(person = person, direction = dir, amountMinor = pesos(units), date = d(11, day), dueDate = due)

    @Test fun faltaRestaAbonosYNuncaBajaDeCero() {
        val x = deuda("Ana", DebtDirection.ME_DEBE, 100_000)
        val abonos = listOf(DebtPaymentRecord(debtId = x.id, amountMinor = pesos(30_000), date = d(11, 3)),
            DebtPaymentRecord(debtId = x.id, amountMinor = pesos(20_000), date = d(11, 5)),
            DebtPaymentRecord(debtId = "otra", amountMinor = pesos(99_000), date = d(11, 5)))
        assertEquals(pesos(50_000), DebtMath.paid(x, abonos))
        assertEquals(pesos(50_000), DebtMath.remaining(x, abonos))
        val demas = abonos + DebtPaymentRecord(debtId = x.id, amountMinor = pesos(80_000), date = d(11, 6))
        assertEquals(0L, DebtMath.remaining(x, demas))
        assertEquals(pesos(50_000), DebtMath.clampPayment(pesos(80_000), pesos(50_000)))
        assertEquals(0L, DebtMath.clampPayment(-5, pesos(50_000)))
        assertEquals(d(11, 6), DebtMath.lastPaymentDate(x, demas))
    }

    @Test fun estado() {
        val x = deuda("Ana", DebtDirection.ME_DEBE, 50_000, due = d(11, 9))
        assertEquals(DebtStatus.PENDIENTE, DebtMath.status(x, emptyList(), d(11, 9)))
        assertEquals(DebtStatus.VENCIDA, DebtMath.status(x, emptyList(), hoy))
        assertEquals(DebtStatus.SALDADA, DebtMath.status(x, listOf(DebtPaymentRecord(debtId = x.id, amountMinor = pesos(50_000), date = hoy)), hoy))
        assertEquals("Saldada", DebtStatus.SALDADA.title)
    }

    @Test fun netoPorPersonaJuntaTildesYMayusculas() {
        val a1 = deuda("Ana María", DebtDirection.ME_DEBE, 300_000, day = 1)
        val a2 = deuda("  ana maria ", DebtDirection.LE_DEBO, 50_000, day = 4)
        val c = deuda("Carlos", DebtDirection.LE_DEBO, 80_000, day = 2)
        val saldada = deuda("Pedro", DebtDirection.ME_DEBE, 10_000)
        val pagos = listOf(DebtPaymentRecord(debtId = saldada.id, amountMinor = pesos(10_000), date = hoy),
            DebtPaymentRecord(debtId = a1.id, amountMinor = pesos(100_000), date = hoy))
        val people = DebtMath.people(listOf(a1, a2, c, saldada), pagos)
        assertEquals(2, people.size)
        assertEquals("ana maria", people[0].name)
        assertEquals(pesos(200_000), people[0].owedToMeMinor)
        assertEquals(pesos(50_000), people[0].iOweMinor)
        assertEquals(pesos(150_000), people[0].netMinor)
        assertEquals(2, people[0].openCount)
        assertEquals("te debe", DebtMath.netLabel(people[0]))
        assertEquals("Carlos", people[1].name); assertEquals(-pesos(80_000), people[1].netMinor)
        assertEquals("le debes", DebtMath.netLabel(people[1]))
        assertEquals(2, DebtMath.debtsOf(DebtMath.personKey("ANA MARÍA"), listOf(a1, a2, c)).size)
        assertEquals("a mano", DebtMath.netLabel(PersonDebts("x", "X", 5, 5, 2)))
    }

    @Test fun resumen() {
        val t = DebtMath.totals(listOf(deuda("Ana", DebtDirection.ME_DEBE, 350_000), deuda("Carlos", DebtDirection.LE_DEBO, 80_000)), emptyList())
        assertEquals("Te deben $ 350.000 · Debes $ 80.000", DebtMath.summaryText(t, Currency.COP))
        assertEquals("Te deben $ 5.000", DebtMath.summaryText(DebtTotals(pesos(5_000), 0), Currency.COP))
        assertEquals("Debes $ 80.000", DebtMath.summaryText(DebtTotals(0, pesos(80_000)), Currency.COP))
        assertEquals("Nadie te debe y no debes nada", DebtMath.summaryText(DebtTotals(0, 0), Currency.COP))
    }

    @Test fun ordenAbiertasYSaldadas() {
        val sinFecha = deuda("A", DebtDirection.ME_DEBE, 1, day = 5)
        val pronto = deuda("B", DebtDirection.ME_DEBE, 1, day = 1, due = d(11, 12))
        val despues = deuda("C", DebtDirection.ME_DEBE, 1, day = 2, due = d(11, 20))
        val vieja = deuda("D", DebtDirection.ME_DEBE, 1, day = 1)
        val nueva = deuda("E", DebtDirection.ME_DEBE, 1, day = 2)
        val pagos = listOf(DebtPaymentRecord(debtId = vieja.id, amountMinor = pesos(1), date = d(11, 9)),
            DebtPaymentRecord(debtId = nueva.id, amountMinor = pesos(1), date = d(11, 3)))
        val all = listOf(sinFecha, despues, pronto, vieja, nueva)
        assertEquals(listOf("B", "C", "A"), DebtMath.open(all, pagos).map { it.person })
        assertEquals(listOf("D", "E"), DebtMath.settled(all, pagos).map { it.person })
    }

    @Test fun sugerencias() {
        val debts = listOf(deuda("Ana María", DebtDirection.ME_DEBE, 1, day = 3), deuda("ana maría", DebtDirection.LE_DEBO, 1, day = 1),
            deuda("Andrés", DebtDirection.ME_DEBE, 1, day = 2), deuda("Carlos", DebtDirection.ME_DEBE, 1, day = 4))
        assertEquals(listOf("Ana María", "Andrés"), DebtMath.suggestions("an", debts))
        assertEquals(listOf("Ana María"), DebtMath.suggestions("mar", debts))
        assertEquals(listOf("Carlos", "Ana María", "Andrés"), DebtMath.suggestions("", debts))
        assertTrue(DebtMath.suggestions("Carlos", debts).isEmpty())
        assertEquals("Ana María", DebtMath.cleanName("  Ana   María "))
    }

    @Test fun haciaDondeSeMueveLaPlata() {
        val cuenta = "c1"
        val out = DebtMath.OUTSIDE_PRODUCT_ID
        assertEquals(cuenta to out, DebtMath.transferEnds(cuenta, DebtDirection.ME_DEBE, false))
        assertEquals(out to cuenta, DebtMath.transferEnds(cuenta, DebtDirection.ME_DEBE, true))
        assertEquals(out to cuenta, DebtMath.transferEnds(cuenta, DebtDirection.LE_DEBO, false))
        assertEquals(cuenta to out, DebtMath.transferEnds(cuenta, DebtDirection.LE_DEBO, true))
        assertEquals("¿De dónde salió la plata?", DebtMath.productQuestion(DebtDirection.ME_DEBE, false))
        assertEquals("¿A dónde llegó?", DebtMath.productQuestion(DebtDirection.LE_DEBO, false))
        assertEquals("Préstamo a Ana", DebtMath.transferNote("Ana", DebtDirection.ME_DEBE, false))
        assertEquals("Abono de Ana", DebtMath.transferNote("Ana", DebtDirection.ME_DEBE, true))
    }

    @Test fun prestarBajaElSaldoYElAbonoLoSube() {
        val cuenta = ProductRecord("c1", ProductKind.CUENTA, pesos(1_000_000), d(10, 31))
        val (f1, t1) = DebtMath.transferEnds(cuenta.id, DebtDirection.ME_DEBE, false)
        val (f2, t2) = DebtMath.transferEnds(cuenta.id, DebtDirection.ME_DEBE, true)
        val transfers = listOf(TransferRecord(fromProductId = f1, toProductId = t1, amountMinor = pesos(300_000), occurredAt = d(11, 1)),
            TransferRecord(fromProductId = f2, toProductId = t2, amountMinor = pesos(100_000), occurredAt = d(11, 5)))
        assertEquals(pesos(800_000), MoneyCalculator.currentBalance(cuenta, listOf(cuenta), emptyList(), transfers))
        assertEquals(pesos(800_000), MoneyCalculator.netWorth(listOf(cuenta), emptyList(), transfers).third)
        val tarjeta = ProductRecord("t1", ProductKind.CREDITO, 0, d(10, 31))
        val (f3, t3) = DebtMath.transferEnds(tarjeta.id, DebtDirection.LE_DEBO, true)
        val t = TransferRecord(fromProductId = f3, toProductId = t3, amountMinor = pesos(50_000), occurredAt = d(11, 2))
        assertEquals(pesos(50_000), MoneyCalculator.currentBalance(tarjeta, listOf(tarjeta), emptyList(), listOf(t)))
    }

    @Test fun avisoElDiaAntes() {
        val x = deuda("Ana María", DebtDirection.ME_DEBE, 50_000, due = d(11, 15))
        val now = hoy.atTime(9, 0)
        assertEquals(LocalDateTime.of(2026, 11, 14, 9, 0), DebtMath.reminderDate(x, emptyList(), 540, now))
        assertNull(DebtMath.reminderDate(x, emptyList(), 540, LocalDateTime.of(2026, 11, 14, 10, 0)))
        assertNull(DebtMath.reminderDate(deuda("A", DebtDirection.ME_DEBE, 1), emptyList(), 540, now))
        assertNull(DebtMath.reminderDate(x, listOf(DebtPaymentRecord(debtId = x.id, amountMinor = pesos(50_000), date = hoy)), 540, now))
        val debo = deuda("Carlos", DebtDirection.LE_DEBO, 80_000, due = d(11, 20))
        val plan = DebtMath.reminders(listOf(debo, x), emptyList(), 480, Currency.COP, now)
        assertEquals(2, plan.size)
        assertEquals("deuda.${x.id}", plan[0].id)
        assertEquals("Mañana Ana María te paga", plan[0].title)
        assertEquals("Quedó de pagarte $ 50.000. Si quieres, recuérdale desde Dinero.", plan[0].body)
        assertEquals("Mañana le pagas a Carlos", plan[1].title)
        assertEquals("Le debes $ 80.000. Si ya le pagaste, anota el abono en Dinero.", plan[1].body)
        assertEquals(LocalDateTime.of(2026, 11, 19, 8, 0), plan[1].fireAt)
    }

    @Test fun mensajeParaRecordarle() {
        val conFecha = DebtMath.shareText("Ana María", pesos(150_000), d(11, 15), Currency.COP, hoy)
        assertEquals("Hola Ana, ¿cómo vas? Te escribo para recordarte los $ 150.000 que te presté. Quedamos para el 15 de noviembre. Si puedes, me los pasas para esa fecha. Gracias.", conFecha)
        val vencida = DebtMath.shareText("Ana", pesos(150_000), d(11, 1), Currency.COP, hoy)
        assertTrue(vencida.endsWith("Quedamos para el 1 de noviembre. Cuando puedas me los pasas. Gracias."))
        assertEquals("Hola Carlos, ¿cómo vas? Te escribo para recordarte los $ 20.000 que te presté. Cuando puedas me los pasas. Gracias.",
            DebtMath.shareText("Carlos", pesos(20_000), null, Currency.COP, hoy))
        assertFalse(conFecha.contains('\u2014'))
    }

    @Test fun loQueTeDebeParaRecordarle() {
        val a = deuda("Ana", DebtDirection.ME_DEBE, 100_000, due = d(11, 20))
        val b = deuda("ana", DebtDirection.ME_DEBE, 50_000, due = d(11, 12))
        val c = deuda("Ana", DebtDirection.LE_DEBO, 30_000)
        val (total, due) = DebtMath.owedToMe(DebtMath.personKey("Ana"), listOf(a, b, c), emptyList())
        assertEquals(pesos(150_000), total)
        assertEquals(d(11, 12), due)
        assertEquals(DebtDirection.ME_DEBE, DebtDirection.from("me_debe")); assertEquals("le_debo", DebtDirection.LE_DEBO.raw)
    }
}

class DebtsSyncTextTest {
    @Test fun hojaDeEstadoYOrdenDeLaNube() {
        assertEquals("2 deudas, 1 abono", SyncText.pendingSummary(mapOf("debts" to 2, "debt_payments" to 1)))
        assertEquals(listOf("debts", "debt_payments"), SyncEngine.TABLES.takeLast(2))
    }
}

class LockTimeoutTest {
    @Test fun inmediatamenteSiempre() {
        assertTrue(LockTimeout.requiresAuth(100_000, 100_000, LockDelay.INMEDIATAMENTE))
        assertTrue(LockTimeout.requiresAuth(100_000, 101_000, LockDelay.INMEDIATAMENTE))
    }

    @Test fun conEspera() {
        assertFalse(LockTimeout.requiresAuth(100_000, 129_900, LockDelay.TREINTA_SEGUNDOS))
        assertTrue(LockTimeout.requiresAuth(100_000, 130_000, LockDelay.TREINTA_SEGUNDOS))
        assertFalse(LockTimeout.requiresAuth(100_000, 159_000, LockDelay.UN_MINUTO))
        assertTrue(LockTimeout.requiresAuth(100_000, 160_000, LockDelay.UN_MINUTO))
    }

    @Test fun arranqueEnFrioYRelojQueRetrocede() {
        assertTrue(LockTimeout.requiresAuth(null, 5_000, LockDelay.UN_MINUTO))
        assertTrue(LockTimeout.requiresAuth(500_000, 10_000, LockDelay.UN_MINUTO))
    }

    @Test fun opciones() {
        assertEquals(listOf("Inmediatamente", "Después de 30 segundos", "Después de 1 minuto"), LockDelay.entries.map { it.title })
        assertEquals(LockDelay.INMEDIATAMENTE, LockDelay.from(null))
        assertEquals(LockDelay.TREINTA_SEGUNDOS, LockDelay.from(30))
        assertEquals(LockDelay.UN_MINUTO, LockDelay.from(60))
        assertEquals(LockDelay.INMEDIATAMENTE, LockDelay.from(45))
        assertEquals("seguridad.bloquearTras", LockDelay.STORAGE_KEY)
    }
}

class CajitaTest {
    private fun pesos(v: Long) = v * 100

    @Test fun cajitaEsPlataDisponibleYRinde() {
        val inicio = LocalDate.of(2026, 11, 1)
        val cuenta = ProductRecord("c", ProductKind.CUENTA, pesos(200_000), inicio)
        val cajita = ProductRecord("k", ProductKind.CAJITA, pesos(1_000_000), inicio)
        val bolsillo = ProductRecord("b", ProductKind.BOLSILLO, pesos(500_000), inicio)
        val paso = TransferRecord(fromProductId = "c", toProductId = "k", amountMinor = pesos(100_000), occurredAt = LocalDate.of(2026, 11, 2))
        val (have, owe, _) = MoneyCalculator.netWorth(listOf(cuenta, cajita, bolsillo), emptyList(), listOf(paso))
        assertEquals(pesos(1_700_000), have)
        assertEquals(0L, owe)
        assertFalse(ProductKind.CAJITA.isDebt)
        assertTrue(ProductKind.CAJITA.earnsYield && ProductKind.BOLSILLO.earnsYield && !ProductKind.CUENTA.earnsYield)
        assertEquals("Cajita", ProductKind.CAJITA.title); assertEquals("Bolsillo", ProductKind.BOLSILLO.title)
        assertEquals(ProductKind.CAJITA, ProductKind.valueOf("cajita".uppercase()))
        assertTrue(monthlyYield(pesos(1_100_000), 9.0) > 0)
    }
}
