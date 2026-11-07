package com.olarte.mprogress.domain

import java.time.LocalDate
import java.time.YearMonth

/**
 * Barra de filtros del Resumen: el periodo, "Todas" y una pastilla por categoría con gasto en el periodo,
 * de la que más gasta a la que menos. Se pueden elegir varias categorías; "Todas" es el conjunto vacío.
 * Igual que SummaryFilter y SummaryMath.activeCategories de iOS.
 */
object SummaryFilter {
    /** Movimientos de los últimos `months` meses hasta el mes de `today` (meses completos). */
    fun inPeriod(entries: List<EntryRecord>, today: LocalDate, months: Int): List<EntryRecord> {
        val end = YearMonth.from(today)
        val start = end.minusMonths(maxOf(1, months) - 1L)
        return entries.filter { val m = YearMonth.from(it.occurredAt); !m.isBefore(start) && !m.isAfter(end) }
    }

    /** Categorías con gasto en esos movimientos, de mayor a menor gasto. Los gastos sin categoría no tienen pastilla. */
    fun chips(inPeriod: List<EntryRecord>): List<String> = CategoryMath.spending(inPeriod).mapNotNull { it.categoryId }

    /** Toca una categoría: si estaba, sale; si no, entra. */
    fun toggle(selected: Set<String>, id: String): Set<String> = if (id in selected) selected - id else selected + id

    /** Lo que de verdad se filtra: solo las elegidas que tienen pastilla en este periodo. Null es "Todas". */
    fun effective(selected: Set<String>, chips: List<String>): Set<String>? = selected.intersect(chips.toSet()).ifEmpty { null }

    /** Deja solo los movimientos de esas categorías (solo gastos); null deja todo. */
    fun apply(entries: List<EntryRecord>, filter: Set<String>?): List<EntryRecord> =
        if (filter == null) entries else entries.filter { it.kind == EntryKind.GASTO && it.categoryId in filter }

    /** "Ingresos y gastos", "Gastos de Mercado", "Gastos de Mercado y Salidas", "Gastos de 3 categorías". */
    fun spendTitle(names: List<String>): String = when (names.size) {
        0 -> "Ingresos y gastos"
        1 -> "Gastos de ${names[0]}"
        2 -> "Gastos de ${names[0]} y ${names[1]}"
        else -> "Gastos de ${names.size} categorías"
    }
}
