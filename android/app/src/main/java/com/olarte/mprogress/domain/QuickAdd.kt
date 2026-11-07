package com.olarte.mprogress.domain

/** Reglas del registro rápido, como QuickAddMath de iOS. */
object QuickAddMath {
    /** Nombre del movimiento: lo que escribió la persona ("almuerzo" pasa a "Almuerzo") o "Gasto rápido". */
    fun name(kind: EntryKind, concept: String?): String {
        val clean = concept?.trim().orEmpty()
        if (clean.isEmpty()) return if (kind == EntryKind.INGRESO) "Ingreso rápido" else "Gasto rápido"
        val cut = clean.take(60)
        return cut.substring(0, 1).uppercase() + cut.substring(1)
    }
}

/** Un nombre que la persona usa seguido, con la categoría que le puso la última vez. */
data class QuickName(val name: String, val categoryId: String? = null)

/** Sugerencias de "¿En qué?" en el registro rápido. Igual que QuickNames de iOS (Domain/QuickNames.swift). */
object QuickNames {
    /** Cuántas sugerencias se muestran. */
    const val LIMIT = 6
    /** Cuántos movimientos recientes del mismo tipo se miran. */
    const val WINDOW = 150

    /** Nombres que pone la app sola: no se sugieren. */
    private val defaults = setOf("gasto rapido", "ingreso rapido", "gasto", "ingreso")

    fun isDefault(name: String) = InitialUpload.normalizedName(name) in defaults

    /**
     * Los nombres más usados entre los últimos movimientos de ese tipo (sin pagos fijos ni nombres por defecto).
     * Empate: el más reciente primero (mismo día: el que se anotó después). Se muestra como se escribió la última vez.
     */
    fun recent(entries: List<EntryRecord>, kind: EntryKind, limit: Int = LIMIT): List<QuickName> {
        val candidates = entries.withIndex()
            .filter { (_, e) -> e.kind == kind && e.recurringId == null && e.name.isNotBlank() && !isDefault(e.name) }
            .sortedWith(compareByDescending<IndexedValue<EntryRecord>> { it.value.occurredAt }.thenByDescending { it.index })
            .take(WINDOW)
            .map { it.value }

        class Group(val name: String, var categoryId: String?, var count: Int, val firstSeen: Int)
        val groups = LinkedHashMap<String, Group>()
        candidates.forEachIndexed { position, e ->
            val key = InitialUpload.normalizedName(e.name)
            if (key.isEmpty()) return@forEachIndexed
            val g = groups[key]
            if (g == null) groups[key] = Group(e.name.trim(), e.categoryId, 1, position)
            else { g.count += 1; if (g.categoryId == null) g.categoryId = e.categoryId }
        }
        return groups.values.sortedWith(compareByDescending<Group> { it.count }.thenBy { it.firstSeen })
            .take(limit).map { QuickName(it.name, it.categoryId) }
    }

    /** Las que siguen sirviendo mientras se escribe: empiezan por lo escrito y no son exactamente lo escrito. Sin texto, todas. */
    fun matching(names: List<QuickName>, typed: String): List<QuickName> {
        val key = InitialUpload.normalizedName(typed)
        if (key.isEmpty()) return names
        return names.filter { InitialUpload.normalizedName(it.name).let { c -> c.startsWith(key) && c != key } }
    }

    /** La categoría que se usó la última vez con ese nombre, si el nombre es una de las sugerencias. */
    fun categoryId(name: String, names: List<QuickName>): String? {
        val key = InitialUpload.normalizedName(name)
        if (key.isEmpty()) return null
        return names.firstOrNull { InitialUpload.normalizedName(it.name) == key }?.categoryId
    }
}
