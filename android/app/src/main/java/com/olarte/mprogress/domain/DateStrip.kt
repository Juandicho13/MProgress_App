package com.olarte.mprogress.domain

import java.time.LocalDate

/**
 * Cuentas del calendario de semana de Agregar, igual que DateStrip de iOS: una fila de 7 días que empieza el lunes (como en Colombia),
 * el mes completo con los días del mes anterior y del siguiente para llenar las semanas, y el título "noviembre 2026".
 */
object DateStrip {
    val weekdayInitials = listOf("L", "M", "M", "J", "V", "S", "D")
    val weekdayNames = listOf("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")
    /** Lo más lejos que puede quedar la fecha de un movimiento, hacia atrás o hacia adelante. */
    const val MAX_YEARS = 2L

    /** Un día de la cuadrícula del mes. `inMonth` es falso en los días del mes anterior o siguiente. */
    data class Day(val date: LocalDate, val inMonth: Boolean)

    /** 0 el lunes, 6 el domingo. */
    fun mondayIndex(date: LocalDate) = date.dayOfWeek.value - 1

    /** El lunes de la semana de `date`. */
    fun weekStart(date: LocalDate): LocalDate = date.minusDays(mondayIndex(date).toLong())

    /** Los 7 días (de lunes a domingo) de la semana de `date`. */
    fun week(date: LocalDate): List<LocalDate> = weekStart(date).let { start -> (0L until 7L).map { start.plusDays(it) } }

    /** Semanas completas del mes de `date`, de lunes a domingo, con los días de los meses vecinos al principio y al final. */
    fun monthGrid(date: LocalDate): List<Day> {
        val first = date.withDayOfMonth(1)
        val lead = mondayIndex(first)
        val cells = (lead + first.lengthOfMonth() + 6) / 7 * 7
        val start = first.minusDays(lead.toLong())
        return (0 until cells).map { start.plusDays(it.toLong()).let { d -> Day(d, d.monthValue == first.monthValue && d.year == first.year) } }
    }

    /** "noviembre 2026". */
    fun monthLabel(date: LocalDate) = "${DueText.monthName(date)} ${date.year}"

    /** "viernes 7 de noviembre de 2026", para TalkBack. */
    fun spokenDate(date: LocalDate) = "${weekdayNames[mondayIndex(date)]} ${date.dayOfMonth} de ${DueText.monthName(date)} de ${date.year}"

    /** Primer y último día que se pueden elegir: dos años antes y dos años después de hoy. */
    fun bounds(today: LocalDate): ClosedRange<LocalDate> = today.minusYears(MAX_YEARS)..today.plusYears(MAX_YEARS)

    fun isSelectable(date: LocalDate, today: LocalDate) = date in bounds(today)

    /** La misma fecha N semanas antes o después. */
    fun shiftWeek(date: LocalDate, weeks: Int): LocalDate = date.plusWeeks(weeks.toLong())

    /** El primer día del mes N meses antes o después. */
    fun shiftMonth(date: LocalDate, months: Int): LocalDate = date.withDayOfMonth(1).plusMonths(months.toLong())

    /** Se puede ir a la semana de al lado si tiene por lo menos un día elegible. */
    fun canShiftWeek(visible: LocalDate, weeks: Int, today: LocalDate) = week(shiftWeek(visible, weeks)).any { isSelectable(it, today) }

    /** Se puede ir al mes de al lado si tiene por lo menos un día elegible. */
    fun canShiftMonth(visible: LocalDate, months: Int, today: LocalDate): Boolean {
        val month = shiftMonth(visible, months)
        val range = bounds(today)
        return !month.isAfter(range.endInclusive) && !month.withDayOfMonth(month.lengthOfMonth()).isBefore(range.start)
    }

    /** El mismo día si está dentro de los dos años; si no, el borde más cercano. */
    fun clamp(date: LocalDate, today: LocalDate): LocalDate {
        val range = bounds(today)
        return when {
            date.isBefore(range.start) -> range.start
            date.isAfter(range.endInclusive) -> range.endInclusive
            else -> date
        }
    }
}
