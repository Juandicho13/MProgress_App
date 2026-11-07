package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.YearMonth

/** "Este mes" y "Los próximos 3 meses" sin predicciones inventadas (PLAN_F12B Paso 4): los mismos casos de ForecastTests de iOS. */
class ForecastTest {
    private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)
    private fun pesos(v: Long) = v * 100
    private val ahora = d(2026, 11, 10)
    private fun gasto(u: Long, date: LocalDate, fijo: String? = null) = EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(u), occurredAt = date, recurringId = fijo)
    private fun fijo(name: String, kind: EntryKind, u: Long, next: LocalDate, total: Int? = null, paid: Int = 0) =
        RecurringRecord(kind = kind, name = name, amountMinor = pesos(u), cycle = Cycle.Mensual, nextDate = next, totalCount = total, paidCount = paid)

    @Test fun este_mes() {
        val entries = listOf(EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2_000_000), occurredAt = d(2026, 11, 1)),
            gasto(136_600, d(2026, 11, 2)), gasto(10_000, d(2026, 11, 5)), gasto(100_000, d(2026, 11, 5), "fijo"), gasto(900_000, d(2026, 10, 20)))
        val recurring = listOf(fijo("Renta", EntryKind.GASTO, 1_000_000, d(2026, 11, 15)), fijo("Prima", EntryKind.INGRESO, 300_000, d(2026, 11, 28)))
        val f = Forecast.monthFacts(entries, recurring, ahora)
        assertEquals(pesos(2_000_000), f.enteredMinor)
        assertEquals(pesos(300_000), f.pendingIncomeMinor)
        assertEquals(pesos(246_600), f.spentMinor)
        assertEquals(pesos(1_000_000), f.pendingFixedMinor)
        assertEquals(pesos(1_053_400), f.remainingMinor)
        assertFalse(f.isOver)
        assertEquals(BalanceCalculator.monthSummary(entries, recurring, ahora).remainingMinor, f.remainingMinor)
        assertNull(Forecast.overText(f.remainingMinor, Currency.COP))
    }

    @Test fun te_pasaste() {
        // El caso de Juan: sueldo fijo de $ 2 por error y gastos reales del mes.
        val entries = listOf(gasto(136_600, d(2026, 11, 2)), gasto(10_000, d(2026, 11, 5)), gasto(5_000, d(2026, 11, 6)))
        val f = Forecast.monthFacts(entries, listOf(fijo("Sueldo", EntryKind.INGRESO, 2, d(2026, 11, 30))), d(2026, 11, 6))
        assertEquals(pesos(2 - 151_600), f.remainingMinor)
        assertTrue(f.isOver)
        assertEquals("Te pasaste $ 151.598 de lo que entra este mes", Forecast.overText(f.remainingMinor, Currency.COP))
    }

    @Test fun proximos() {
        val recurring = listOf(fijo("Sueldo", EntryKind.INGRESO, 3_000_000, d(2026, 12, 1)), fijo("Renta", EntryKind.GASTO, 1_000_000, d(2026, 11, 15)),
            fijo("Celular", EntryKind.GASTO, 150_000, d(2026, 12, 10), total = 3, paid = 1))
        val m = Forecast.nextMonths(3, recurring, ahora)
        assertEquals(listOf(YearMonth.of(2026, 12), YearMonth.of(2027, 1), YearMonth.of(2027, 2)), m.map { it.month })
        assertEquals(pesos(3_000_000), m[0].fixedIncomeMinor)
        assertEquals(pesos(1_150_000), m[0].fixedExpenseMinor)
        assertEquals(pesos(1_850_000), m[0].netMinor)
        assertEquals(pesos(1_150_000), m[1].fixedExpenseMinor)
        assertEquals(pesos(1_000_000), m[2].fixedExpenseMinor)
        assertEquals(pesos(2_000_000), m[2].netMinor)
        assertEquals("Quedan $ 1.850.000", Forecast.netText(m[0], Currency.COP))
        assertEquals("Solo cuenta tus pagos fijos", Forecast.NEXT_MONTHS_NOTE)
    }

    @Test fun proximos_negativo() {
        val m = Forecast.nextMonths(1, listOf(fijo("Renta", EntryKind.GASTO, 500_000, d(2026, 12, 5))), ahora)
        assertEquals(-pesos(500_000), m[0].netMinor)
        assertEquals("Quedan − $ 500.000", Forecast.netText(m[0], Currency.COP))
    }

    @Test fun fecha_final() {
        val curso = fijo("Curso", EntryKind.GASTO, 200_000, d(2026, 12, 5)).copy(endDate = d(2026, 12, 31))
        assertEquals(listOf(pesos(200_000), 0L, 0L), Forecast.nextMonths(3, listOf(curso), ahora).map { it.fixedExpenseMinor })
    }
}
