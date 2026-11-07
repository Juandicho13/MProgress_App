package com.olarte.mprogress.data

import com.olarte.mprogress.domain.Currency
import com.olarte.mprogress.domain.ServerTime
import org.json.JSONObject
import java.io.File
import java.time.Instant

/**
 * Diario de cambios para la sincronización (F10). Los registros de Android no guardan fechas ni estado de sincronización, así que
 * esto lleva, por cada uno: cuándo se creó y cambió en el teléfono, si está pendiente, sincronizado o falló, si se borró (lápida
 * para avisarle a la nube), la última fila que llegó o se subió (`remote`) y cómo la veía Android en ese momento (`base`).
 *
 * Con `remote` y `base` no se pierde lo que Android no maneja (comercio, ícono, quién pagó en iOS): al subir solo se cambian las
 * claves que de verdad cambiaron en Android desde la última vez.
 */
class SyncJournal(private val file: File?) {
    enum class State { LOCAL, PENDING, SYNCED, FAILED }

    class Meta(var createdAt: Instant, var updatedAt: Instant, var deletedAt: Instant? = null, var state: State = State.PENDING,
               var remote: JSONObject? = null, var base: JSONObject? = null) {
        val isPending get() = state == State.LOCAL || state == State.PENDING
    }

    val records = mutableMapOf<String, Meta>()
    /** Id del aviso de cada pago fijo cuando vino de iOS (en Android el aviso vive dentro del fijo). */
    val reminderIds = mutableMapOf<String, String>()
    val attempts = mutableMapOf<String, Int>()
    val cursors = mutableMapOf<String, Instant>()
    /** Espacio de la nube con el que se sincronizó por última vez. */
    var spaceId: String? = null

    init { load() }

    fun key(table: String, id: String) = "$table/${id.lowercase()}"
    fun meta(table: String, id: String) = records[key(table, id)]
    fun reminderId(recurringId: String) = reminderIds[recurringId] ?: SyncRows.defaultReminderId(recurringId)

    /**
     * Lo que cambió entre dos versiones de los datos por un cambio hecho en el teléfono: lo nuevo o distinto queda pendiente con la
     * hora de ahora; lo que ya estaba en la nube y se borró queda como lápida; lo que nunca subió y se borró se olvida.
     */
    fun track(old: Ledger, oldCurrency: Currency, new: Ledger, newCurrency: Currency, now: Instant = ServerTime.now()) {
        val before = SyncRows.snapshot(old, oldCurrency, ::reminderId)
        val after = SyncRows.snapshot(new, newCurrency, ::reminderId)
        var changed = false
        for ((table, items) in after) {
            val previous = before[table].orEmpty()
            for ((id, value) in items) {
                if (previous[id] == value) continue
                val k = key(table, id)
                val m = records[k]
                if (m == null) records[k] = Meta(now, now, state = State.LOCAL)
                else { m.updatedAt = maxOf(now, m.updatedAt.plusNanos(1000)); m.deletedAt = null; if (m.state != State.LOCAL) m.state = State.PENDING }
                changed = true
            }
            for (id in previous.keys - items.keys) {
                val k = key(table, id)
                val m = records[k] ?: continue
                if (m.remote == null) records.remove(k)
                else { m.deletedAt = now; m.updatedAt = maxOf(now, m.updatedAt.plusNanos(1000)); m.state = State.PENDING }
                changed = true
            }
        }
        if (changed) save()
    }

    /** Otra cuenta o espacio: todo vuelve a quedar pendiente y se olvida lo de la nube anterior. */
    fun resetForSpace(newSpaceId: String) {
        if (spaceId == newSpaceId) return
        records.entries.removeAll { it.value.deletedAt != null }
        records.values.forEach { it.state = State.PENDING; it.remote = null; it.base = null }
        reminderIds.clear(); attempts.clear(); cursors.clear()
        spaceId = newSpaceId
        save()
    }

    /** Cerrar sesión: se vuelve a bajar todo la próxima vez (como iOS). */
    fun resetCursors() { cursors.clear(); attempts.clear(); save() }

    fun clear() { records.clear(); reminderIds.clear(); attempts.clear(); cursors.clear(); spaceId = null; file?.delete() }

    // ---------- Archivo ----------

    private fun Instant.micros() = ServerTime.format(this)

    fun save() {
        val f = file ?: return
        val recs = JSONObject()
        for ((k, m) in records) {
            recs.put(k, JSONObject().put("c", m.createdAt.micros()).put("u", m.updatedAt.micros()).put("d", m.deletedAt?.micros() ?: JSONObject.NULL)
                .put("s", m.state.name).put("r", m.remote ?: JSONObject.NULL).put("b", m.base ?: JSONObject.NULL))
        }
        val o = JSONObject().put("version", 1).put("records", recs).put("reminderIds", JSONObject(reminderIds as Map<*, *>))
            .put("attempts", JSONObject(attempts as Map<*, *>)).put("cursors", JSONObject(cursors.mapValues { it.value.micros() } as Map<*, *>))
            .put("spaceId", spaceId ?: JSONObject.NULL)
        val tmp = File(f.parentFile, f.name + ".tmp")
        tmp.writeText(o.toString())
        tmp.renameTo(f)
    }

    private fun load() {
        val f = file ?: return
        if (!f.exists()) return
        runCatching {
            val o = JSONObject(f.readText())
            val recs = o.optJSONObject("records") ?: JSONObject()
            for (k in recs.keys()) {
                val m = recs.getJSONObject(k)
                records[k] = Meta(ServerTime.parse(m.getString("c"))!!, ServerTime.parse(m.getString("u"))!!,
                    if (m.isNull("d")) null else ServerTime.parse(m.getString("d")), State.valueOf(m.getString("s")),
                    m.optJSONObject("r"), m.optJSONObject("b"))
            }
            o.optJSONObject("reminderIds")?.let { r -> r.keys().forEach { reminderIds[it] = r.getString(it) } }
            o.optJSONObject("attempts")?.let { a -> a.keys().forEach { attempts[it] = a.getInt(it) } }
            o.optJSONObject("cursors")?.let { c -> c.keys().forEach { k -> ServerTime.parse(c.getString(k))?.let { cursors[k] = it } } }
            spaceId = if (o.isNull("spaceId")) null else o.optString("spaceId")
        }
    }
}
