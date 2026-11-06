package com.olarte.mprogress.domain

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Ciclo de un pago fijo (HANDOFF 8.2). */
sealed class Cycle {
    object Puntual : Cycle()
    object Semanal : Cycle()
    object Mensual : Cycle()
    object Anual : Cycle()
    data class CadaDias(val days: Int) : Cycle()

    val raw: String get() = when (this) {
        Puntual -> "puntual"; Semanal -> "semanal"; Mensual -> "mensual"; Anual -> "anual"; is CadaDias -> "otra"
    }
    val intervalDays: Int? get() = (this as? CadaDias)?.days
    val title: String get() = when (this) {
        Puntual -> "Puntual"; Semanal -> "Semanal"; Mensual -> "Mensual"; Anual -> "Anual"; is CadaDias -> "Cada $days días"
    }
    val repeats: Boolean get() = this != Puntual

    companion object {
        fun from(raw: String, intervalDays: Int? = null): Cycle = when (raw) {
            "semanal" -> Semanal; "mensual" -> Mensual; "anual" -> Anual
            "otra" -> CadaDias(maxOf(1, intervalDays ?: 30)); else -> Puntual
        }
    }
}

/** Día y mes originales: un mensual del 31 cae el 30 en abril y vuelve al 31 en mayo. */
data class CycleAnchor(val day: Int, val month: Int) {
    companion object { fun of(date: LocalDate) = CycleAnchor(date.dayOfMonth, date.monthValue) }
}

object CycleMath {
    fun next(after: LocalDate, cycle: Cycle, anchor: CycleAnchor): LocalDate? = when (cycle) {
        Cycle.Puntual -> null
        Cycle.Semanal -> after.plusDays(7)
        is Cycle.CadaDias -> after.plusDays(cycle.days.toLong())
        Cycle.Mensual -> clamp(anchor.day, after.withDayOfMonth(1).plusMonths(1))
        Cycle.Anual -> clamp(anchor.day, LocalDate.of(after.year + 1, anchor.month, 1))
    }

    fun occurrences(start: LocalDate, through: LocalDate, cycle: Cycle, anchor: CycleAnchor, limit: Int = 400): List<LocalDate> {
        val out = mutableListOf<LocalDate>()
        var current: LocalDate? = start
        while (current != null && !current.isAfter(through) && out.size < limit) {
            out += current
            current = next(current, cycle, anchor)
        }
        return out
    }

    private fun clamp(day: Int, month: LocalDate) = month.withDayOfMonth(minOf(day, month.lengthOfMonth()))
}

/** Urgencia de un cargo: hoy (o vencido), pronto (1 a 3 días), próximas. */
enum class Urgency(val title: String) {
    HOY("Hoy"), PRONTO("Pronto"), PROXIMAS("Próximas");

    companion object {
        fun of(due: LocalDate, today: LocalDate): Urgency {
            val d = days(today, due)
            return when { d <= 0 -> HOY; d <= 3 -> PRONTO; else -> PROXIMAS }
        }
        fun days(from: LocalDate, to: LocalDate) = ChronoUnit.DAYS.between(from, to).toInt()
    }
}
