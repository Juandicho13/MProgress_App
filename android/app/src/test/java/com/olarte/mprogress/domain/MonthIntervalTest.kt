package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)
private fun pesos(v: Long) = v * 100

/** Pagos fijos cada N meses, con las mismas pruebas de MonthIntervalTests de iOS. */
class MonthIntervalTest {
    private fun next(after: LocalDate, cycle: Cycle, anchor: CycleAnchor) = CycleMath.next(after, cycle, anchor)
    private fun fijo(cycle: Cycle, next: LocalDate, endDate: LocalDate? = null, total: Int? = null, paid: Int = 0) =
        RecurringRecord(kind = EntryKind.GASTO, name = "Seguro", amountMinor = pesos(300_000), cycle = cycle, nextDate = next,
            endDate = endDate, totalCount = total, paidCount = paid)

    @Test fun trimestralSumaTresMeses() {
        val a = CycleAnchor(15, 1)
        assertEquals(d(2026, 4, 15), next(d(2026, 1, 15), Cycle.CadaMeses(3), a))
        assertEquals(d(2027, 2, 15), next(d(2026, 11, 15), Cycle.CadaMeses(3), a))
    }

    @Test fun finDeMesVuelveAlAncla() {
        val dates = CycleMath.occurrences(d(2026, 1, 31), d(2026, 5, 31), Cycle.Mensual, CycleAnchor(31, 1))
        assertEquals(listOf(d(2026, 1, 31), d(2026, 2, 28), d(2026, 3, 31), d(2026, 4, 30), d(2026, 5, 31)), dates)
    }

    @Test fun cadaDosMesesBisiesto() {
        val a = CycleAnchor(31, 1)
        assertEquals(d(2028, 3, 31), next(d(2028, 1, 31), Cycle.CadaMeses(2), a))
        assertEquals(d(2028, 2, 29), next(d(2027, 12, 31), Cycle.CadaMeses(2), a))
        assertEquals(d(2028, 4, 30), next(d(2028, 2, 29), Cycle.CadaMeses(2), a))
        assertEquals(d(2028, 6, 30), next(d(2028, 4, 30), Cycle.CadaMeses(2), a))
        assertEquals(d(2028, 8, 31), next(d(2028, 6, 30), Cycle.CadaMeses(2), a))
    }

    @Test fun semestralDel31DeAgosto() {
        val a = CycleAnchor(31, 8)
        assertEquals(d(2027, 2, 28), next(d(2026, 8, 31), Cycle.CadaMeses(6), a))
        assertEquals(d(2027, 8, 31), next(d(2027, 2, 28), Cycle.CadaMeses(6), a))
        assertEquals(d(2028, 2, 29), next(d(2027, 8, 31), Cycle.CadaMeses(6), a))
    }

    @Test fun cadaVeinticuatroMeses() {
        val a = CycleAnchor(29, 2)
        assertEquals(d(2030, 2, 28), next(d(2028, 2, 29), Cycle.CadaMeses(24), a))
        assertEquals(d(2032, 2, 29), next(d(2030, 2, 28), Cycle.CadaMeses(24), a))
    }

    @Test fun normaliza() {
        assertEquals(Cycle.Mensual, Cycle.months(1))
        assertEquals(Cycle.Mensual, Cycle.months(0))
        assertEquals(Cycle.Anual, Cycle.months(12))
        assertEquals(Cycle.CadaMeses(3), Cycle.months(3))
        assertEquals(Cycle.CadaMeses(24), Cycle.months(99))
        assertEquals(3, Cycle.months(3).intervalMonths)
        assertEquals(1, Cycle.Mensual.intervalMonths)
        assertEquals(1, Cycle.Semanal.intervalMonths)
        assertTrue(Cycle.CadaMeses(3).isMonthly)
        assertFalse(Cycle.Anual.isMonthly)
    }

    @Test fun guardado() {
        assertEquals("mensual", Cycle.CadaMeses(6).raw)
        assertEquals(Cycle.CadaMeses(6), Cycle.from("mensual", intervalMonths = 6))
        assertEquals(Cycle.Mensual, Cycle.from("mensual"))
        assertEquals(Cycle.Mensual, Cycle.from("mensual", intervalMonths = 1))
        assertEquals(Cycle.Anual, Cycle.from("anual", intervalMonths = 3))
    }

    @Test fun opciones() {
        assertEquals(listOf("Mensual", "Cada 2 meses", "Trimestral", "Semestral", "Anual", "Cada N meses"), MonthInterval.entries.map { it.title })
        assertEquals(MonthInterval.TRIMESTRAL, MonthInterval.of(3))
        assertEquals(MonthInterval.OTRO, MonthInterval.of(4))
        assertEquals(Cycle.CadaMeses(3), MonthInterval.cycle(MonthInterval.TRIMESTRAL, 9))
        assertEquals(Cycle.CadaMeses(9), MonthInterval.cycle(MonthInterval.OTRO, 9))
        assertEquals(Cycle.Anual, MonthInterval.cycle(MonthInterval.ANUAL, 9))
        assertEquals("Cada 4 meses", Cycle.CadaMeses(4).title)
        assertEquals("Semestral", Cycle.CadaMeses(6).title)
        assertEquals("Trimestral · el 5", FixedMath.scheduleText(Cycle.CadaMeses(3), d(2026, 12, 5), false, d(2026, 11, 6)))
        assertEquals(pesos(100_000), FixedMath.monthlyEquivalent(pesos(300_000), Cycle.CadaMeses(3)))
    }

    @Test fun soloEnSusMeses() {
        val seguro = fijo(Cycle.CadaMeses(3), d(2026, 12, 10))
        val months = Forecast.nextMonths(4, listOf(seguro), d(2026, 11, 6))
        assertEquals(listOf(pesos(300_000), 0L, 0L, pesos(300_000)), months.map { it.fixedExpenseMinor })
        assertEquals(0L, BalanceCalculator.monthSummary(emptyList(), listOf(seguro), d(2026, 11, 6)).pendingFixedMinor)
        assertEquals(pesos(300_000), BalanceCalculator.monthSummary(emptyList(), listOf(seguro), d(2026, 12, 2)).pendingFixedMinor)
    }

    @Test fun conFin() {
        val cuotas = fijo(Cycle.CadaMeses(2), d(2026, 11, 20), total = 3, paid = 1)
        assertEquals(listOf(d(2026, 11, 20), d(2027, 1, 20)), RecurringMath.occurrences(cuotas, d(2027, 12, 31)))
        val hasta = fijo(Cycle.CadaMeses(2), d(2026, 11, 20), endDate = d(2027, 3, 20))
        assertEquals(listOf(d(2026, 11, 20), d(2027, 1, 20), d(2027, 3, 20)), RecurringMath.occurrences(hasta, d(2027, 12, 31)))
        // Pagar el 20 de enero lleva al 20 de marzo; pagar el de marzo (el último antes del fin) lo termina.
        assertEquals(d(2027, 3, 20), RecurringMath.afterPaid(hasta.copy(nextDate = d(2027, 1, 20), paidCount = 1)).nextDate)
        val last = RecurringMath.afterPaid(hasta.copy(nextDate = d(2027, 3, 20), paidCount = 2))
        assertTrue(last.finished)
        assertFalse(last.active)
    }

    @Test fun agregarPasado() {
        val plan = AddPlan.decide(Cycle.CadaMeses(3), d(2026, 9, 6), d(2026, 11, 6))
        assertEquals(d(2026, 9, 6), plan.entryDate)
        assertEquals(d(2026, 12, 6), plan.recurringNext)
    }

    @Test fun proximosCargos() {
        val seguro = fijo(Cycle.CadaMeses(3), d(2026, 11, 10))
        assertEquals(d(2026, 11, 10), BalanceCalculator.upcoming(listOf(seguro), d(2026, 11, 6), kind = null, limit = 5).first().date)
        assertEquals(listOf(d(2026, 11, 10), d(2027, 2, 10), d(2027, 5, 10)), RecurringMath.occurrences(seguro, d(2027, 6, 30)))
    }

    @Test fun montoPuestoSeReemplaza() {
        var a = AmountInput.prefilled(pesos(1_250_000), Currency.COP)
        assertEquals("1.250.000", a.display)
        a = a.press('9')
        assertEquals("9", a.display)
        a = a.press('0')
        assertEquals(pesos(90), a.money.minor)
        var b = AmountInput.prefilled(pesos(45_500), Currency.COP)
        b = b.press(',')
        assertEquals("45.500", b.display)
        b = b.deleteLast()
        assertEquals("", b.text)
        assertFalse(AmountInput.prefilled(0, Currency.COP).replaceNext)
    }
}
