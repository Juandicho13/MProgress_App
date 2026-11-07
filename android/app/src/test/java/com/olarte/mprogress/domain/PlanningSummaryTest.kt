package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Test

/** Límites y ahorro en Dinero: los mismos casos de PlanningSummaryTests de iOS. */
class PlanningSummaryTest {
    private fun status(limit: Long, spent: Long) = BudgetStatus(BudgetRecord(categoryId = "c", limitMinor = limit), spent)

    @Test fun limites() {
        assertEquals("Sin límites", PlanningSummary.budgets(emptyList()))
        assertEquals("2 límites · 1 pasado", PlanningSummary.budgets(listOf(status(100, 120), status(100, 10))))
        assertEquals("2 límites · 2 pasados", PlanningSummary.budgets(listOf(status(100, 120), status(100, 100))))
        assertEquals("1 límite · 1 cerca", PlanningSummary.budgets(listOf(status(100, 85))))
        assertEquals("1 límite · al día", PlanningSummary.budgets(listOf(status(100, 10))))
    }

    @Test fun metas() {
        assertEquals("Sin metas", PlanningSummary.goals(emptyList()))
        val una = GoalProgress(GoalRecord(name = "Viaje", targetMinor = 1000), 459)
        assertEquals("1 meta · 45%", PlanningSummary.goals(listOf(una)))
        val llena = GoalProgress(GoalRecord(name = "Moto", targetMinor = 1000), 5000)
        assertEquals("2 metas · 72%", PlanningSummary.goals(listOf(una, llena)))
    }
}
