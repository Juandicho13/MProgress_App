package com.olarte.mprogress.domain

import java.text.Normalizer
import java.time.LocalDate
import java.time.YearMonth

data class HistoryDay(val day: LocalDate, val entries: List<EntryRecord>, val netMinor: Long)
data class MonthFlow(val month: YearMonth, val incomeMinor: Long, val spentMinor: Long) { val netMinor get() = incomeMinor - spentMinor }

/** Historial (F04-01): por día, del más nuevo al más viejo, y búsqueda sin tildes. */
object HistoryMath {
    fun days(entries: List<EntryRecord>): List<HistoryDay> =
        entries.groupBy { it.occurredAt }.map { (d, items) -> HistoryDay(d, items.sortedBy { it.name }, items.sumOf { it.signedMinor }) }
            .sortedByDescending { it.day }

    fun filter(entries: List<EntryRecord>, query: String): List<EntryRecord> {
        val words = normalize(query).split(" ").filter { it.isNotBlank() }
        if (words.isEmpty()) return entries
        return entries.filter { e ->
            val hay = normalize(e.name) + " " + (e.amountMinor / 100)
            words.all { hay.contains(it) }
        }
    }

    fun normalize(t: String): String =
        Normalizer.normalize(t.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").replace(".", "").trim()
}

/** Resumen (F05): flujo por mes, comparación con el mes pasado y tu mes normal. */
object SummaryMath {
    fun flows(entries: List<EntryRecord>, today: LocalDate, months: Int = 6): List<MonthFlow> {
        val current = YearMonth.from(today)
        return (months - 1 downTo 0).map { off ->
            val m = current.minusMonths(off.toLong())
            val items = entries.filter { YearMonth.from(it.occurredAt) == m }
            MonthFlow(m, items.filter { it.kind == EntryKind.INGRESO }.sumOf { it.amountMinor }, items.filter { it.kind == EntryKind.GASTO }.sumOf { it.amountMinor })
        }
    }

    /** Gastado este mes hasta hoy contra lo gastado el mes pasado hasta el mismo día. */
    fun versusLastMonth(entries: List<EntryRecord>, today: LocalDate): Pair<Long, Long> {
        val thisMonth = entries.filter { it.kind == EntryKind.GASTO && YearMonth.from(it.occurredAt) == YearMonth.from(today) && !it.occurredAt.isAfter(today) }.sumOf { it.amountMinor }
        val last = today.minusMonths(1)
        val lastMonth = entries.filter { it.kind == EntryKind.GASTO && YearMonth.from(it.occurredAt) == YearMonth.from(last) && it.occurredAt.dayOfMonth <= today.dayOfMonth }.sumOf { it.amountMinor }
        return thisMonth to lastMonth
    }

    /** Mediana del gasto de los 12 meses anteriores que tienen datos. */
    fun normalMonth(entries: List<EntryRecord>, today: LocalDate): Long? {
        val current = YearMonth.from(today)
        val totals = (1..12).map { off ->
            val m = current.minusMonths(off.toLong())
            entries.filter { it.kind == EntryKind.GASTO && YearMonth.from(it.occurredAt) == m }.sumOf { it.amountMinor }
        }.filter { it > 0 }.sorted()
        if (totals.isEmpty()) return null
        val mid = totals.size / 2
        return if (totals.size % 2 == 1) totals[mid] else (totals[mid - 1] + totals[mid]) / 2
    }

    /** Lo que ya se sabe del mes que viene: fijos de ingreso y de gasto. */
    fun nextMonth(recurring: List<RecurringRecord>, today: LocalDate): Pair<Long, Long> {
        val next = today.withDayOfMonth(1).plusMonths(1)
        var income = 0L; var expense = 0L
        recurring.forEach { r ->
            val n = BalanceCalculator.pendingOccurrences(r, next).size.toLong() * r.amountMinor
            if (r.kind == EntryKind.INGRESO) income += n else expense += n
        }
        return income to expense
    }
}

data class CalendarDay(val entries: List<EntryRecord> = emptyList(), val charges: List<UpcomingCharge> = emptyList()) {
    val hasExpense get() = entries.any { it.kind == EntryKind.GASTO } || charges.any { it.kind == EntryKind.GASTO }
    val pendingMinor get() = charges.filter { it.kind == EntryKind.GASTO }.sumOf { it.amountMinor }
}

/** Calendario (F04-04): cuadrícula del mes empezando en lunes y lo que pasa cada día. */
object CalendarMath {
    val weekdays = listOf("L", "M", "M", "J", "V", "S", "D")

    /** Celdas del mes: null son huecos antes del día 1. */
    fun grid(month: YearMonth): List<LocalDate?> {
        val first = month.atDay(1)
        val blanks = first.dayOfWeek.value - 1
        return List(blanks) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
    }

    fun days(month: YearMonth, entries: List<EntryRecord>, recurring: List<RecurringRecord>, today: LocalDate): Map<LocalDate, CalendarDay> {
        val out = mutableMapOf<LocalDate, CalendarDay>()
        entries.filter { YearMonth.from(it.occurredAt) == month }.forEach { e ->
            val d = out[e.occurredAt] ?: CalendarDay(); out[e.occurredAt] = d.copy(entries = d.entries + e)
        }
        recurring.filter { it.active && !it.dateUnset }.forEach { r ->
            CycleMath.occurrences(r.nextDate, month.atEndOfMonth(), r.cycle, r.anchor).filter { YearMonth.from(it) == month }.forEach { date ->
                val c = UpcomingCharge(r.id, r.name, r.kind, r.amountMinor, date, Urgency.of(date, today), Urgency.days(today, date))
                val d = out[date] ?: CalendarDay(); out[date] = d.copy(charges = d.charges + c)
            }
        }
        return out
    }
}

/** Saldos (HANDOFF 8.2): cuentas lo que hay, crédito lo que se debe. Los gastos con débito salen de su cuenta. */
data class ProductRecord(val id: String, val kind: ProductKind, val balanceMinor: Long, val balanceAt: LocalDate, val hidden: Boolean = false, val parentProductId: String? = null)

object MoneyCalculator {
    fun currentBalance(p: ProductRecord, products: List<ProductRecord>, entries: List<EntryRecord>): Long {
        val debit = products.filter { it.kind == ProductKind.DEBITO && it.parentProductId == p.id }.map { it.id }.toSet()
        var b = p.balanceMinor
        entries.filter { it.occurredAt.isAfter(p.balanceAt) || it.occurredAt == p.balanceAt }.forEach { e ->
            val pid = e.productId ?: return@forEach
            if (pid == p.id || pid in debit) b += if (p.kind.isDebt) -e.signedMinor else e.signedMinor
        }
        return b
    }

    fun netWorth(products: List<ProductRecord>, entries: List<EntryRecord>): Triple<Long, Long, Long> {
        var have = 0L; var owe = 0L
        products.filter { !it.hidden && it.kind != ProductKind.DEBITO }.forEach {
            val b = currentBalance(it, products, entries)
            if (it.kind.isDebt) owe += b else have += b
        }
        return Triple(have, owe, have - owe)
    }
}
