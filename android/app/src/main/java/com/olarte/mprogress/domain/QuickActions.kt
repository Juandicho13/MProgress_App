package com.olarte.mprogress.domain

/** Acciones del menú Más. El usuario las ordena y fija 3 en Inicio. Mismo formato de guardado que iOS. */
enum class QuickActionKind(val raw: String, val title: String, val shortTitle: String, val glyph: String) {
    GASTO("gasto", "Gasto", "Gasto", "+"),
    INGRESO("ingreso", "Ingreso extra", "Ingreso", "↓"),
    FIJOS("fijos", "Pagos fijos", "Fijos", "≡"),
    RAPIDO("rapido", "Registro rápido", "Rápido", "⚡"),
    RECIBO("recibo", "Escanear recibo", "Recibo", "▤");

    companion object { fun from(raw: String) = entries.firstOrNull { it.raw == raw } }
}

data class QuickActionLayout private constructor(val order: List<QuickActionKind>, val pinned: List<QuickActionKind>) {
    val unpinned get() = order.filter { it !in pinned }
    val stored get() = order.joinToString(",") { it.raw } + "|" + pinned.joinToString(",") { it.raw }
    fun isPinned(kind: QuickActionKind) = kind in pinned

    /** Fija o suelta. Si ya hay 3, la nueva reemplaza la última fijada. */
    fun togglePin(kind: QuickActionKind): QuickActionLayout =
        if (kind in pinned) of(order, pinned - kind)
        else of(order, (if (pinned.size >= LIMIT) pinned.dropLast(1) else pinned) + kind)

    fun movePinned(from: Int, to: Int) = of(order, moved(pinned, from, to))
    fun moveUnpinned(from: Int, to: Int) = of(pinned + moved(unpinned, from, to), pinned)

    companion object {
        const val STORAGE_KEY = "inicio.acciones"
        const val LIMIT = 3
        val standard = of(QuickActionKind.entries, listOf(QuickActionKind.GASTO, QuickActionKind.INGRESO, QuickActionKind.FIJOS))
        /**
         * Acciones que existieron y se quitaron (Gasto fijo, Sueldo o fijo y Pago anual repetían Pagos fijos; Historial ya está en
         * Inicio › Movimientos › Ver todo; Registro automático vive en Ajustes; Límites y Ahorro, en Dinero). Si estaban fijadas, su lugar se llena con las de por defecto.
         */
        val retired = setOf("fijo", "sueldo", "anual", "historial", "automatico", "limites", "ahorro")

        /** Completa las fijadas con las de por defecto, sin repetir, hasta llegar a 3. */
        fun filled(pinned: List<QuickActionKind>): List<QuickActionKind> {
            val result = pinned.distinct().toMutableList()
            for (kind in standard.pinned + QuickActionKind.entries) if (result.size < LIMIT && kind !in result) result += kind
            return result
        }

        fun of(order: List<QuickActionKind>, pinned: List<QuickActionKind>): QuickActionLayout {
            val o = order.distinct().toMutableList()
            QuickActionKind.entries.forEach { if (it !in o) o += it }
            return QuickActionLayout(o, pinned.distinct().take(LIMIT))
        }

        fun parse(stored: String?): QuickActionLayout {
            val parts = stored?.split("|") ?: return standard
            if (parts.size != 2) return standard
            fun kinds(t: String) = t.split(",").mapNotNull { QuickActionKind.from(it) }
            val pinned = kinds(parts[1])
            return of(kinds(parts[0]), if (parts[1].split(",").any { it in retired }) filled(pinned) else pinned)
        }

        private fun moved(list: List<QuickActionKind>, from: Int, to: Int): List<QuickActionKind> {
            if (from !in list.indices) return list
            val r = list.toMutableList()
            val item = r.removeAt(from)
            r.add(to.coerceIn(0, r.size), item)
            return r
        }
    }
}
