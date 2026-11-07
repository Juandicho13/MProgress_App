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
    /** Cada N meses (2 a 24, sin 12, que es anual). Se guarda como "mensual" con `intervalMonths`. */
    data class CadaMeses(val months: Int) : Cycle()

    val raw: String get() = when (this) {
        Puntual -> "puntual"; Semanal -> "semanal"; Mensual, is CadaMeses -> "mensual"; Anual -> "anual"; is CadaDias -> "otra"
    }
    val intervalDays: Int? get() = (this as? CadaDias)?.days
    /** Meses entre cobros que se guardan (`interval_months`): N en cada N meses, 1 en todo lo demás. */
    val intervalMonths: Int get() = (this as? CadaMeses)?.months ?: 1
    /** Mensual o cada N meses: los que usan "Día del mes". */
    val isMonthly: Boolean get() = this == Mensual || this is CadaMeses
    val title: String get() = when (this) {
        Puntual -> "Puntual"; Semanal -> "Semanal"; Mensual -> "Mensual"; Anual -> "Anual"; is CadaDias -> "Cada $days días"
        is CadaMeses -> MonthInterval.title(months)
    }
    val repeats: Boolean get() = this != Puntual

    companion object {
        /** `intervalMonths` solo cuenta para "mensual": 1 (o null, los datos de antes) es mensual. */
        fun from(raw: String, intervalDays: Int? = null, intervalMonths: Int? = null): Cycle = when (raw) {
            "semanal" -> Semanal; "mensual" -> months(intervalMonths ?: 1); "anual" -> Anual
            "otra" -> CadaDias(maxOf(1, intervalDays ?: 30)); else -> Puntual
        }

        /** El ciclo de cada N meses, de 1 a 24: 1 es mensual y 12 es anual, así cada ciclo tiene una sola forma. */
        fun months(count: Int): Cycle = when (val m = count.coerceIn(MonthInterval.RANGE)) {
            1 -> Mensual; 12 -> Anual; else -> CadaMeses(m)
        }
    }
}

/**
 * Cada cuánto se repite un pago mensual (opciones de la pantalla): mensual, cada 2 meses, trimestral, semestral, anual o cada N
 * meses con un contador de 1 a 24. Igual que MonthInterval de iOS.
 */
enum class MonthInterval(val months: Int?, val title: String) {
    MENSUAL(1, "Mensual"), BIMESTRAL(2, "Cada 2 meses"), TRIMESTRAL(3, "Trimestral"), SEMESTRAL(6, "Semestral"), ANUAL(12, "Anual"),
    OTRO(null, "Cada N meses");

    companion object {
        val RANGE = 1..24
        /** La opción que corresponde a N meses; lo que no es una opción fija queda en "Cada N meses". */
        fun of(months: Int): MonthInterval = entries.firstOrNull { it.months == months } ?: OTRO
        /** "Mensual", "Cada 2 meses", "Trimestral", "Semestral", "Anual" o "Cada 4 meses". */
        fun title(months: Int): String = of(months).let { if (it == OTRO) "Cada $months meses" else it.title }
        /** El ciclo que resulta de la opción y del contador. */
        fun cycle(choice: MonthInterval, months: Int): Cycle = Cycle.months(choice.months ?: months)
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
        Cycle.Mensual -> addMonths(1, after, anchor)
        is Cycle.CadaMeses -> addMonths(maxOf(1, cycle.months), after, anchor)
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

    /**
     * Suma meses desde el mes de `after` y pone el día ancla: el 31 de enero más un mes es el 28 (o 29) de febrero y el siguiente
     * vuelve al 31 de marzo, porque el ancla es el día original y no el último usado.
     */
    fun addMonths(months: Int, after: LocalDate, anchor: CycleAnchor): LocalDate = clamp(anchor.day, after.withDayOfMonth(1).plusMonths(months.toLong()))

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
