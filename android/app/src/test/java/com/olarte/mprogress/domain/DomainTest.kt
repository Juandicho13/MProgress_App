package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)
private fun pesos(v: Long) = v * 100

class MoneyTest {
    @Test fun formato() {
        assertEquals("$ 1.901.100", Money(pesos(1_901_100)).formatted())
        assertEquals("− $ 84.300", Money(-pesos(84_300)).formatted())
        assertEquals("+ $ 500", Money(pesos(500)).formatted(sign = true))
        assertEquals("€ 12,50", Money(1250, Currency.EUR).formatted())
    }

    @Test fun teclado() {
        var a = AmountInput()
        "45500".forEach { a = a.press(it) }
        assertEquals("45.500", a.display)
        assertEquals(pesos(45_500), a.money.minor)
        a = a.press(',')
        assertEquals("45500", a.text)
        a = a.deleteLast()
        assertEquals("4.550", a.display)
        var e = AmountInput(Currency.EUR)
        "12,505".forEach { e = e.press(it) }
        assertEquals(1250, e.money.minor)
        assertEquals("45500", AmountInput.fromMinor(pesos(45_500), Currency.COP).text)
    }
}

class CycleTest {
    @Test fun mensualDel31() {
        val a = CycleAnchor(31, 1)
        val feb = CycleMath.next(d(2026, 1, 31), Cycle.Mensual, a)!!
        assertEquals(d(2026, 2, 28), feb)
        assertEquals(d(2026, 3, 31), CycleMath.next(feb, Cycle.Mensual, a))
    }

    @Test fun anualYCadaDias() {
        assertEquals(d(2028, 2, 29), CycleMath.next(d(2027, 2, 28), Cycle.Anual, CycleAnchor(29, 2)))
        assertEquals(d(2026, 11, 21), CycleMath.next(d(2026, 11, 6), Cycle.CadaDias(15), CycleAnchor(6, 11)))
        assertNull(CycleMath.next(d(2026, 11, 6), Cycle.Puntual, CycleAnchor(6, 11)))
    }

    @Test fun urgencia() {
        val hoy = d(2026, 11, 6)
        assertEquals(Urgency.HOY, Urgency.of(d(2026, 11, 5), hoy))
        assertEquals(Urgency.PRONTO, Urgency.of(d(2026, 11, 9), hoy))
        assertEquals(Urgency.PROXIMAS, Urgency.of(d(2026, 11, 10), hoy))
    }
}

class BalanceTest {
    @Test fun teQuedan() {
        val hoy = d(2026, 11, 6)
        val entries = listOf(
            EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(4_000_000), occurredAt = d(2026, 11, 1)),
            EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(300_000), occurredAt = d(2026, 11, 3)),
            EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(999_000), occurredAt = d(2026, 10, 30)),
        )
        val fijos = listOf(
            RecurringRecord(kind = EntryKind.GASTO, name = "Renta", amountMinor = pesos(1_500_000), cycle = Cycle.Mensual, nextDate = d(2026, 11, 15)),
            RecurringRecord(kind = EntryKind.GASTO, name = "Gym", amountMinor = pesos(100_000), cycle = Cycle.Mensual, nextDate = d(2026, 12, 2)),
            RecurringRecord(kind = EntryKind.GASTO, name = "Sin fecha", amountMinor = pesos(50_000), cycle = Cycle.Mensual, nextDate = d(2026, 11, 20), dateUnset = true),
        )
        val s = BalanceCalculator.monthSummary(entries, fijos, hoy)
        assertEquals(pesos(4_000_000), s.expectedIncomeMinor)
        assertEquals(pesos(300_000), s.spentMinor)
        assertEquals(pesos(1_500_000), s.pendingFixedMinor)
        assertEquals(pesos(2_200_000), s.remainingMinor)
        assertEquals(24, s.daysLeft)
        val up = BalanceCalculator.upcoming(fijos, hoy)
        assertEquals(listOf("Renta", "Gym"), up.map { it.name })
    }

    @Test fun planDeAgregar() {
        val hoy = d(2026, 11, 6)
        assertEquals(AddPlan(hoy, null), AddPlan.decide(Cycle.Puntual, hoy, hoy))
        assertEquals(AddPlan(null, d(2026, 11, 20)), AddPlan.decide(Cycle.Puntual, d(2026, 11, 20), hoy))
        assertEquals(AddPlan(d(2026, 11, 1), d(2026, 12, 1)), AddPlan.decide(Cycle.Mensual, d(2026, 11, 1), hoy))
        assertEquals(AddPlan(d(2026, 9, 6), d(2026, 12, 6)), AddPlan.decide(Cycle.Mensual, d(2026, 9, 6), hoy))
    }

    @Test fun fijos() {
        assertEquals(pesos(52_000), FixedMath.monthlyEquivalent(pesos(12_000), Cycle.Semanal))
        assertEquals(pesos(73_000), FixedMath.monthlyEquivalent(pesos(36_000), Cycle.CadaDias(15)))
        assertEquals("Mensual · el 5", FixedMath.scheduleText(Cycle.Mensual, d(2026, 12, 5), false, d(2026, 11, 6)))
        assertEquals("En 6 días", DueText.describe(d(2026, 11, 12), d(2026, 11, 6)))
    }
}

class QuickActionsTest {
    @Test fun porDefectoYGuardado() {
        val l = QuickActionLayout.parse("")
        assertEquals(listOf(QuickActionKind.GASTO, QuickActionKind.INGRESO, QuickActionKind.FIJO), l.pinned)
        val m = l.togglePin(QuickActionKind.INGRESO).togglePin(QuickActionKind.AHORRO)
        assertEquals(m, QuickActionLayout.parse(m.stored))
        assertEquals(listOf(QuickActionKind.GASTO, QuickActionKind.FIJO, QuickActionKind.AHORRO), m.pinned)
    }

    @Test fun limiteYTolerancia() {
        assertEquals(QuickActionKind.HISTORIAL, QuickActionLayout.standard.togglePin(QuickActionKind.HISTORIAL).pinned.last())
        val l = QuickActionLayout.parse("ahorro,vieja,gasto|ahorro,ahorro,vieja")
        assertEquals(listOf(QuickActionKind.AHORRO), l.pinned)
        assertTrue(l.order.toSet() == QuickActionKind.entries.toSet())
        // Mismo texto que guarda iOS: se puede leer igual en ambas apps.
        assertEquals(QuickActionKind.AHORRO, QuickActionLayout.parse("ahorro,gasto|ahorro").pinned.first())
    }
}
