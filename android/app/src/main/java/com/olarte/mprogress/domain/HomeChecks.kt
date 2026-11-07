package com.olarte.mprogress.domain

/** Revisión del sueldo en Inicio (PLAN_F12B Paso 4): un ingreso fijo de menos de 1.000 unidades de la moneda
 *  casi siempre es un error al escribirlo ($ 2 en vez de $ 2.000.000). Igual que IncomeCheck de iOS. */
object IncomeCheck {
    /** Menos de esto, en unidades de la moneda, se pregunta. */
    const val THRESHOLD_UNITS = 1_000L
    /** Los arreglos que se ofrecen: por mil y por un millón. */
    val factors = listOf(1_000L, 1_000_000L)
    /** Dónde se guardan, en este dispositivo, los ingresos que la persona dijo que están bien. */
    const val STORAGE_KEY = "inicio.ingresosRevisados"

    /** Ingresos fijos activos con un monto sospechoso que la persona no ha confirmado. */
    fun suspicious(recurring: List<RecurringRecord>, currency: Currency, dismissed: Set<String>): List<RecurringRecord> =
        recurring.filter {
            it.active && it.kind == EntryKind.INGRESO && it.amountMinor > 0 &&
                it.amountMinor < THRESHOLD_UNITS * currency.minorPerUnit && it.id !in dismissed
        }

    /** "¿Tu sueldo es $ 2?" */
    fun question(name: String, amountMinor: Long, currency: Currency = Currency.current) =
        "¿Tu ${phrase(name)} es ${Money(amountMinor, currency).formatted()}?"

    /** "Es $ 2.000" */
    fun fixTitle(amountMinor: Long, factor: Long, currency: Currency = Currency.current) =
        "Es ${Money(amountMinor * factor, currency).formatted()}"

    /** Movimientos que nacieron de este ingreso fijo con el monto mal escrito: los enlazados a él, o los que no
     *  tienen enlace pero se llaman igual. Se arreglan junto con el pago fijo para que "Te quedan" cambie de una vez. */
    fun entriesToFix(entries: List<EntryRecord>, recurring: RecurringRecord, oldAmountMinor: Long): List<String> =
        entries.filter { e ->
            e.kind == recurring.kind && e.amountMinor == oldAmountMinor &&
                (e.recurringId == recurring.id || (e.recurringId == null && sameName(e.name, recurring.name)))
        }.map { it.id }

    /** Un movimiento que quedó con el monto viejo cuando el pago fijo ya se arregló (por mil o por un millón). */
    data class StaleEntry(val entryId: String, val name: String, val amountMinor: Long, val fixedAmountMinor: Long)

    /** Movimientos de ingreso con un monto sospechoso cuyo pago fijo ya tiene ese monto por mil o por un millón. */
    fun staleEntries(entries: List<EntryRecord>, recurring: List<RecurringRecord>, currency: Currency, dismissed: Set<String>): List<StaleEntry> {
        val limit = THRESHOLD_UNITS * currency.minorPerUnit
        return entries.mapNotNull { e ->
            if (e.kind != EntryKind.INGRESO || e.amountMinor <= 0 || e.amountMinor >= limit || e.id in dismissed) return@mapNotNull null
            val fixed = recurring.firstOrNull { r ->
                r.kind == EntryKind.INGRESO &&
                    (e.recurringId == r.id || (e.recurringId == null && sameName(e.name, r.name))) &&
                    factors.any { e.amountMinor * it == r.amountMinor }
            } ?: return@mapNotNull null
            StaleEntry(e.id, e.name, e.amountMinor, fixed.amountMinor)
        }
    }

    /** "Sueldo" y " sueldo " son el mismo nombre. */
    fun sameName(a: String, b: String): Boolean {
        val x = a.trim().lowercase()
        return x.isNotEmpty() && x == b.trim().lowercase()
    }

    /** El nombre dentro de la frase: con minúscula inicial, salvo siglas ("SENA"). */
    fun phrase(name: String): String {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return "ingreso"
        val firstWord = trimmed.takeWhile { !it.isWhitespace() }
        if (firstWord.length > 1 && firstWord == firstWord.uppercase() && firstWord != firstWord.lowercase()) return trimmed
        return trimmed.replaceFirstChar { it.lowercase() }
    }
}

/** Próximos cargos de Inicio plegables: 3 cerrados, hasta 20 abiertos. Igual que UpcomingFold de iOS. */
object UpcomingFold {
    const val COLLAPSED_COUNT = 3
    const val EXPANDED_LIMIT = 20
    /** Dónde se guarda, en este dispositivo, si la lista quedó abierta. */
    const val STORAGE_KEY = "inicio.proximosAbiertos"

    fun <T> visible(items: List<T>, expanded: Boolean): List<T> = items.take(if (expanded) EXPANDED_LIMIT else COLLAPSED_COUNT)

    /** "Ver todos (5)" o "Ver menos"; null si caben todos cerrados. */
    fun toggleTitle(total: Int, expanded: Boolean): String? =
        if (total <= COLLAPSED_COUNT) null else if (expanded) "Ver menos" else "Ver todos ($total)"
}
