package com.olarte.mprogress.domain

import java.time.LocalDate

/** Cálculos del mes (HANDOFF 8.2), los mismos de iOS. */
object BalanceCalculator {
    /** Cobros que faltan en el mes, respetando la fecha final y las cuotas que quedan (Paso 2). */
    fun pendingOccurrences(item: RecurringRecord, monthOf: LocalDate): List<LocalDate> {
        val start = monthOf.withDayOfMonth(1)
        val end = monthOf.withDayOfMonth(monthOf.lengthOfMonth())
        return RecurringMath.occurrences(item, end).filter { !it.isBefore(start) }
    }

    fun monthSummary(entries: List<EntryRecord>, recurring: List<RecurringRecord>, today: LocalDate): MonthSummary {
        val inMonth = entries.filter { it.occurredAt.year == today.year && it.occurredAt.month == today.month }
        val income = inMonth.filter { it.kind == EntryKind.INGRESO }.sumOf { it.amountMinor }
        val spent = inMonth.filter { it.kind == EntryKind.GASTO }.sumOf { it.amountMinor }
        var pendingIncome = 0L
        var pendingExpense = 0L
        for (item in recurring) {
            val n = pendingOccurrences(item, today).size.toLong()
            if (item.kind == EntryKind.INGRESO) pendingIncome += n * item.amountMinor else pendingExpense += n * item.amountMinor
        }
        val expected = income + pendingIncome
        val ratio = if (expected > 0) (spent.toDouble() / expected).coerceIn(0.0, 1.0) else if (spent > 0) 1.0 else 0.0
        val daysLeft = maxOf(0, Urgency.days(today, today.withDayOfMonth(today.lengthOfMonth())))
        return MonthSummary(expected, spent, pendingExpense, expected - spent - pendingExpense, ratio, daysLeft)
    }

    fun upcoming(recurring: List<RecurringRecord>, today: LocalDate, kind: EntryKind? = EntryKind.GASTO, limit: Int = 20) =
        recurring.filter { it.active && !it.dateUnset && !it.finished && (kind == null || it.kind == kind) }
            .map { UpcomingCharge(it.id, it.name, it.kind, it.amountMinor, it.nextDate, Urgency.of(it.nextDate, today), Urgency.days(today, it.nextDate)) }
            .sortedWith(compareBy({ it.date }, { it.name }))
            .take(limit)
}

/**
 * Qué se guarda al tocar Guardar en Agregar (F03-03):
 * puntual pasado = movimiento; puntual futuro = fijo pendiente;
 * repetido pasado = movimiento y fijo desde la siguiente; repetido futuro = solo el fijo.
 */
data class AddPlan(val entryDate: LocalDate?, val recurringNext: LocalDate?) {
    companion object {
        fun decide(cycle: Cycle, date: LocalDate, today: LocalDate): AddPlan {
            val due = !date.isAfter(today)
            if (!cycle.repeats) return if (due) AddPlan(date, null) else AddPlan(null, date)
            if (!due) return AddPlan(null, date)
            val anchor = CycleAnchor.of(date)
            var next = CycleMath.next(date, cycle, anchor) ?: date
            var guard = 0
            while (!next.isAfter(today) && guard < 500) { next = CycleMath.next(next, cycle, anchor) ?: next; guard++ }
            return AddPlan(date, next)
        }
    }
}

/** "Hoy", "Mañana", "En 6 días", "Hace 2 días", "1 dic". */
object DueText {
    val months = listOf("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")
    val monthNames = listOf("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")

    fun describe(date: LocalDate, today: LocalDate): String = when (val d = Urgency.days(today, date)) {
        0 -> "Hoy"; 1 -> "Mañana"; in 2..14 -> "En $d días"; -1 -> "Ayer"; in -14..-2 -> "Hace ${-d} días"
        else -> shortDate(date, today)
    }

    fun shortDate(date: LocalDate, today: LocalDate): String {
        val base = "${date.dayOfMonth} ${months[date.monthValue - 1]}"
        return if (date.year != today.year) "$base ${date.year}" else base
    }

    fun monthName(date: LocalDate) = monthNames[date.monthValue - 1]
}

/** Cuentas de la zona de pagos fijos. */
object FixedMath {
    fun monthlyEquivalent(amountMinor: Long, cycle: Cycle): Long = when (cycle) {
        Cycle.Puntual -> 0
        Cycle.Mensual -> amountMinor
        Cycle.Semanal -> amountMinor * 52 / 12
        Cycle.Anual -> amountMinor / 12
        is Cycle.CadaDias -> amountMinor * 365 / (12L * maxOf(1, cycle.days))
        is Cycle.CadaMeses -> amountMinor / maxOf(1, cycle.months)
    }

    data class Totals(val expenseMinor: Long = 0, val incomeMinor: Long = 0, val withoutDate: Int = 0, val paused: Int = 0)

    fun totals(items: List<RecurringRecord>): Totals {
        var t = Totals()
        for (i in items) {
            if (i.finished) continue
            if (!i.active) { t = t.copy(paused = t.paused + 1); continue }
            if (i.dateUnset) t = t.copy(withoutDate = t.withoutDate + 1)
            val m = monthlyEquivalent(i.amountMinor, i.cycle)
            t = if (i.kind == EntryKind.INGRESO) t.copy(incomeMinor = t.incomeMinor + m) else t.copy(expenseMinor = t.expenseMinor + m)
        }
        return t
    }

    /** Igual que scheduleText y, si tiene fin, "Cuota 3 de 12" o "Hasta 15 mar 2027". */
    fun scheduleText(item: RecurringRecord, today: LocalDate): String {
        if (item.finished) return "Terminado"
        val base = scheduleText(item.cycle, item.nextDate, item.dateUnset, today)
        return RecurringMath.endText(item)?.let { "$base · $it" } ?: base
    }

    fun scheduleText(cycle: Cycle, nextDate: LocalDate, dateUnset: Boolean, today: LocalDate): String = when {
        dateUnset -> "${cycle.title} · sin fecha"
        cycle.isMonthly -> "${cycle.title} · el ${nextDate.dayOfMonth}"
        cycle == Cycle.Anual -> "Anual · ${DueText.shortDate(nextDate, today)}"
        else -> cycle.title
    }
}
