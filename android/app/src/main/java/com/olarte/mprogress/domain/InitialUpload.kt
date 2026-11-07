package com.olarte.mprogress.domain

import java.text.Normalizer
import java.time.Instant
import java.util.Locale

/**
 * F10-05: la primera vez que un dispositivo entra a la cuenta (o crea la llave del espacio) sube todo lo local una sola vez,
 * igual que ios/MProgress/Domain/InitialUpload.swift.
 *
 * Reglas: las filas conservan su id (upsert por id, nada se duplica); primero se baja lo que ya hay en la nube y luego se sube solo
 * lo que la nube no tiene o lo que cambió aquí después; lo que se creó igual en dos teléfonos antes de entrar (la misma regla de
 * comercio, una categoría con el mismo nombre) se une con la fila de la nube por una clave estable; los ajustes del espacio vienen de
 * la nube si ya existen allá; y se marca hecho por espacio y usuario (`storageKey`).
 */
object InitialUpload {
    /** Lotes más pequeños en la primera subida para que el avance se vea. */
    const val BATCH_SIZE = 50
    const val DONE_TEXT = "Tus datos ya están en la nube, cifrados"

    /** Una fila, local o de la nube, con lo justo para planear. */
    data class Item(val table: String, val id: String, val updatedAt: Instant, val deleted: Boolean = false, val seedKey: String? = null)

    data class Ref(val table: String, val id: String)

    data class Plan(
        /** Filas locales que se suben: la nube no las tiene o aquí cambiaron después. */
        val push: List<Ref> = emptyList(),
        /** Filas de la nube que se escriben aquí: este dispositivo no las tiene o allá cambiaron después. */
        val take: List<Ref> = emptyList(),
        /** Duplicados locales que se cambian por la fila de la nube: tabla › id local › id de la nube. */
        val remap: Map<String, Map<String, String>> = emptyMap(),
        /** Iguales en los dos lados: no se hace nada. */
        val unchanged: Int = 0,
    )

    /** Tablas cuyas filas se unen por una clave estable. */
    val SEED_TABLES = setOf("categories", "merchant_alias")

    /** Arma el plan de la primera subida. Puro: no toca los datos ni la red. */
    fun plan(local: List<Item>, remote: List<Item>): Plan {
        val remoteById = linkedMapOf<Ref, Item>()
        for (item in remote) {
            val ref = Ref(item.table, item.id.lowercase())
            val seen = remoteById[ref]
            if (seen == null || item.updatedAt > seen.updatedAt) remoteById[ref] = item
        }
        val remoteBySeed = mutableMapOf<String, Item>()
        for (item in remoteById.values) {
            val key = item.seedKey ?: continue
            if (item.deleted) continue
            val slot = item.table + "|" + key
            val current = remoteBySeed[slot]
            // Si la nube ya tiene dos con la misma clave, se usa la más vieja (y si empatan, el id menor): todos eligen igual.
            if (current != null && (current.updatedAt < item.updatedAt || (current.updatedAt == item.updatedAt && current.id.lowercase() < item.id.lowercase()))) continue
            remoteBySeed[slot] = item
        }

        val push = mutableListOf<Ref>()
        val take = mutableListOf<Ref>()
        val remap = linkedMapOf<String, MutableMap<String, String>>()
        var unchanged = 0
        val localRefs = mutableSetOf<Ref>()
        for (item in local) {
            val ref = Ref(item.table, item.id.lowercase())
            if (!localRefs.add(ref)) continue
            val theirs = remoteById[ref]
            val twin = item.seedKey?.let { remoteBySeed[item.table + "|" + it] }
            when {
                theirs != null -> when {
                    item.table == "spaces" -> take += ref
                    item.updatedAt > theirs.updatedAt -> push += ref
                    item.updatedAt < theirs.updatedAt -> take += ref
                    else -> unchanged++
                }
                !item.deleted && twin != null && !twin.id.equals(item.id, ignoreCase = true) ->
                    remap.getOrPut(item.table) { linkedMapOf() }[ref.id] = twin.id.lowercase()
                else -> push += ref
            }
        }
        for (ref in remoteById.keys) if (ref !in localRefs) take += ref
        return Plan(push, take, remap, unchanged)
    }

    /** El id que queda después de unir duplicados. */
    fun remapped(id: String?, map: Map<String, String>): String? = id?.let { map[it.lowercase()] ?: it }

    // ---------- Claves estables ----------

    /** "Mascotas ", "mascotas" y "MASCOTÁS" dan "mascotas": minúsculas, sin tildes, solo letras y números, un espacio. */
    fun normalizedName(raw: String): String {
        val folded = Normalizer.normalize(raw, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase(Locale.ROOT)
        val out = StringBuilder()
        var pendingSpace = false
        for (c in folded) {
            if (c.isLetterOrDigit()) {
                if (pendingSpace && out.isNotEmpty()) out.append(' ')
                pendingSpace = false
                out.append(c)
            } else pendingSpace = true
        }
        return out.toString()
    }

    /** Clave de una categoría: nombre normalizado y, si la categoría tiene tipo (gasto o ingreso), el tipo. */
    fun categoryKey(name: String, kind: String? = null): String? {
        val clean = normalizedName(name)
        if (clean.isEmpty()) return null
        return if (kind.isNullOrEmpty()) clean else normalizedName(kind) + "|" + clean
    }

    /** La clave estable de una fila a partir de sus campos de texto (`field("name")`). Null si la tabla no se une. */
    fun seedKey(table: String, field: (String) -> String?): String? = when (table) {
        "categories" -> field("name")?.let { categoryKey(it, field("kindRaw")) }
        "merchant_alias" -> field("key")?.let(::normalizedName)?.takeIf { it.isNotEmpty() }
        else -> null
    }

    // ---------- Textos y marca de hecho ----------

    /** "Subiendo tus datos: 120 de 340". */
    fun progressText(done: Int, total: Int) = if (total <= 0) "Preparando tus datos…" else "Subiendo tus datos: ${minOf(done, total)} de $total"

    /** Llave en las preferencias del dispositivo: la primera subida de este usuario a este espacio ya se hizo. */
    fun storageKey(spaceId: String, userId: String) = "nube.subidaInicial.${spaceId.lowercase()}.${userId.lowercase()}"
}

/** La base local con lo que necesita la primera subida (LedgerSyncStore en la app). */
interface InitialUploadLocal : LocalSyncStore {
    /** Todas las filas locales que se sincronizan, pendientes o no, con su clave estable. */
    fun uploadItems(): List<InitialUpload.Item>
    /** La clave estable de una fila que bajó (lee su JSON). */
    fun seedKey(record: SyncRecord): String?
    /** Pasa las referencias de cada duplicado local al id de la nube y borra el duplicado (nunca subió). */
    fun resolveDuplicates(remap: Map<String, Map<String, String>>)
    /** Deja estas filas pendientes para subirlas. */
    fun queue(refs: List<InitialUpload.Ref>)
}
