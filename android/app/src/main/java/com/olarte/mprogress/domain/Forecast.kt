package com.olarte.mprogress.domain

import java.time.LocalDate
import java.time.YearMonth

/** El mes de hoy con datos reales, sin predicciones inventadas (PLAN_F12B Paso 4). Igual que MonthFacts de iOS. */
data class MonthFacts(
    /** Ingresos ya registrados este mes. */
    val enteredMinor: Long,
    /** Pagos fijos de ingreso que todavía faltan este mes. */
    val pendingIncomeMinor: Long,
    /** Lo que ya salió este mes. */
    val spentMinor: Long,
    /** Pagos fijos de gasto que todavía faltan este mes. */
    val pendingFixedMinor: Long,
    /** Te quedan = ingresos (registrados y por entrar) − gastado − fijos que faltan. El mismo número de Inicio. */
    val remainingMinor: Long,
) {
    val isOver: Boolean get() = remainingMinor < 0
}

/** Un mes que viene, para "Los próximos 3 meses": solo pagos fijos. */
data class MonthForecast(val month: YearMonth, val fixedIncomeMinor: Long, val fixedExpenseMinor: Long) {
    /** Lo que quedaría: ingresos fijos menos gastos fijos. */
    val netMinor: Long get() = fixedIncomeMinor - fixedExpenseMinor
}

/** Cuentas del mes y de los meses que vienen (PLAN_F12B Paso 4). Solo datos reales y pagos fijos programados:
 *  nada de ritmos de gasto ni estimados. Funciones puras, las mismas de iOS (Domain/Forecast.swift). */
object Forecast {
    /** "Este mes" de Resumen. Sale de monthSummary, así Te quedan es igual al de Inicio. */
    fun monthFacts(entries: List<EntryRecord>, recurring: List<RecurringRecord>, today: LocalDate): MonthFacts {
        val summary = BalanceCalculator.monthSummary(entries, recurring, today)
        val month = YearMonth.from(today)
        val entered = entries.filter { it.kind == EntryKind.INGRESO && YearMonth.from(it.occurredAt) == month }.sumOf { it.amountMinor }
        return MonthFacts(entered, summary.expectedIncomeMinor - entered, summary.spentMinor, summary.pendingFixedMinor, summary.remainingMinor)
    }

    /** Los `count` meses siguientes: ingresos fijos y gastos fijos (con fecha final y cuotas). */
    fun nextMonths(count: Int = 3, recurring: List<RecurringRecord>, today: LocalDate): List<MonthForecast> {
        val current = YearMonth.from(today)
        return (1..maxOf(1, count)).map { offset ->
            val month = current.plusMonths(offset.toLong())
            var income = 0L; var expense = 0L
            for (item in recurring) {
                val times = BalanceCalculator.pendingOccurrences(item, month.atDay(1)).size.toLong()
                if (item.kind == EntryKind.INGRESO) income += times * item.amountMinor else expense += times * item.amountMinor
            }
            MonthForecast(month, income, expense)
        }
    }

    /** "Te pasaste $ X de lo que entra este mes", solo si Te quedan ya es negativo. */
    fun overText(remainingMinor: Long, currency: Currency = Currency.current): String? =
        if (remainingMinor < 0) "Te pasaste ${Money(-remainingMinor, currency).formatted()} de lo que entra este mes" else null

    /** "Quedan $ X" de un mes que viene (con signo si es negativo). */
    fun netText(month: MonthForecast, currency: Currency = Currency.current): String = "Quedan ${Money(month.netMinor, currency).formatted()}"

    /** Nota bajo "Los próximos 3 meses". */
    const val NEXT_MONTHS_NOTE = "Solo cuenta tus pagos fijos"
}

/** "Día del mes" de los pagos fijos mensuales (Paso 2), como DayOfMonth de iOS. */
object DayOfMonth {
    private fun clamped(day: Int, month: YearMonth) = month.atDay(minOf(maxOf(1, day), month.lengthOfMonth()))

    /** Si el día ya pasó este mes, cae este mes cuando ya se pagó (así se anota) y el que viene cuando no. */
    fun date(day: Int, today: LocalDate, alreadyPaidIfPassed: Boolean): LocalDate {
        val thisMonth = clamped(day, YearMonth.from(today))
        return if (thisMonth.isBefore(today) && !alreadyPaidIfPassed) clamped(day, YearMonth.from(today).plusMonths(1)) else thisMonth
    }

    /** El día ya pasó en el mes de hoy (hoy no cuenta como pasado). */
    fun hasPassed(day: Int, today: LocalDate) = clamped(day, YearMonth.from(today)).isBefore(today)
}
