package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)

/** Calendario de semana de Agregar, con las mismas pruebas de DateStripTests de iOS. */
class DateStripTest {
    @Test fun semanaDesdeLunes() {
        assertEquals((2..8).map { d(2026, 11, it) }, DateStrip.week(d(2026, 11, 7)))
        assertEquals(d(2026, 11, 2), DateStrip.weekStart(d(2026, 11, 8)))
        assertEquals(d(2026, 11, 2), DateStrip.weekStart(d(2026, 11, 2)))
        assertEquals(5, DateStrip.mondayIndex(d(2026, 11, 7)))
        assertEquals(listOf("L", "M", "M", "J", "V", "S", "D"), DateStrip.weekdayInitials)
    }

    @Test fun cuadriculaDelMes() {
        val noviembre = DateStrip.monthGrid(d(2026, 11, 7))
        assertEquals(42, noviembre.size)
        assertEquals(d(2026, 10, 26), noviembre.first().date)
        assertFalse(noviembre.first().inMonth)
        assertEquals(30, noviembre.count { it.inMonth })
        assertEquals(d(2026, 12, 6), noviembre.last().date)
        val febrero = DateStrip.monthGrid(d(2027, 2, 10))
        assertEquals(28, febrero.size)
        assertTrue(febrero.all { it.inMonth })
        val marzo = DateStrip.monthGrid(d(2027, 3, 10))
        assertEquals(35, marzo.size)
        assertEquals(1, marzo.first().date.dayOfMonth)
    }

    @Test fun textos() {
        assertEquals("noviembre 2026", DateStrip.monthLabel(d(2026, 11, 7)))
        assertEquals("sábado 7 de noviembre de 2026", DateStrip.spokenDate(d(2026, 11, 7)))
    }

    @Test fun limites() {
        val hoy = d(2026, 11, 7)
        assertTrue(DateStrip.isSelectable(d(2028, 11, 7), hoy))
        assertFalse(DateStrip.isSelectable(d(2028, 11, 8), hoy))
        assertTrue(DateStrip.isSelectable(d(2024, 11, 7), hoy))
        assertFalse(DateStrip.isSelectable(d(2024, 11, 6), hoy))
        assertTrue(DateStrip.canShiftWeek(d(2026, 11, 7), 1, hoy))
        assertFalse(DateStrip.canShiftWeek(d(2028, 11, 7), 1, hoy))
        assertTrue(DateStrip.canShiftMonth(d(2028, 10, 7), 1, hoy))
        assertFalse(DateStrip.canShiftMonth(d(2028, 11, 7), 1, hoy))
        assertFalse(DateStrip.canShiftMonth(d(2024, 11, 7), -1, hoy))
        assertEquals(d(2028, 11, 7), DateStrip.clamp(d(2030, 1, 1), hoy))
    }

    @Test fun mover() {
        assertEquals(d(2026, 10, 31), DateStrip.shiftWeek(d(2026, 11, 7), -1))
        assertEquals(d(2027, 2, 1), DateStrip.shiftMonth(d(2026, 11, 30), 3))
    }
}
