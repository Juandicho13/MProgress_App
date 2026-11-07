package com.olarte.mprogress.data

import com.olarte.mprogress.domain.AlertMode
import com.olarte.mprogress.domain.AlertRule
import com.olarte.mprogress.domain.Currency
import com.olarte.mprogress.domain.LocalSyncStore
import com.olarte.mprogress.domain.ServerTime
import com.olarte.mprogress.domain.SyncEngine
import com.olarte.mprogress.domain.SyncRecord
import org.json.JSONObject
import java.time.Instant

/**
 * La base local para el SyncEngine (F10), como SwiftDataSyncStore de iOS. Cada registro viaja como su fila del respaldo en JSON
 * (fechas ISO 8601 con 6 decimales). Lo que baja se escribe en los datos de Android de una vez por tabla.
 * Se usa siempre en el hilo principal, igual que Store.
 */
class LedgerSyncStore(private val store: Store, private val spaceId: String, private val ownerId: String) : LocalSyncStore {
    private val journal = store.journal
    private val ctx = SyncRows.Ctx(spaceId.lowercase(), ownerId.lowercase())
    /** Lo que Android tenía de cada registro al armar los pendientes, para guardarlo como `base` si sube bien. */
    private val renderedAtPush = mutableMapOf<String, JSONObject?>()
    private var working: Ledger? = null
    private var workingCurrency: Currency? = null
    /** Se escribió algo que vino de la nube (para refrescar widgets y avisos). */
    var appliedChanges = 0
        private set
    /** Filas que bajaron pero Android no pudo leer (otra versión de iOS, tipo que no existe aquí). Se ignoran. */
    var unreadableRows = 0
        private set

    private fun localId(table: String, id: String) = if (table == "spaces") SyncRows.SPACE_KEY else id.lowercase()
    private fun remoteId(table: String, id: String) = if (table == "spaces") ctx.spaceId else id

    /** El valor de merge: la última fila de la nube, con encima solo las claves que cambiaron en Android desde `base`. */
    private fun merged(current: JSONObject, meta: SyncJournal.Meta): JSONObject {
        val out = JSONObject((meta.remote ?: JSONObject()).toString())
        val base = meta.base
        for (k in current.keys()) {
            if (base == null || !base.has(k) || base.opt(k).toString() != current.opt(k).toString()) out.put(k, current.opt(k))
        }
        return out
    }

    private fun stamped(row: JSONObject, table: String, meta: SyncJournal.Meta): JSONObject {
        if (table == "spaces") row.put("id", ctx.spaceId).put("ownerId", ctx.ownerId) else row.put("spaceId", ctx.spaceId)
        return row.put("createdAt", ServerTime.format(meta.createdAt)).put("updatedAt", ServerTime.format(meta.updatedAt))
            .put("deletedAt", meta.deletedAt?.let(ServerTime::format) ?: JSONObject.NULL)
    }

    override fun pending(): List<SyncRecord> {
        val ledger = store.ledger.value
        val snap = SyncRows.snapshot(ledger, store.currency.value, journal::reminderId)
        val result = mutableListOf<SyncRecord>()
        val now = ServerTime.now()
        var created = false
        renderedAtPush.clear()
        for (table in SyncEngine.TABLES) {
            val items = snap[table] ?: continue
            for ((id, value) in items) {
                val key = journal.key(table, id)
                // La moneda del espacio no se sube al entrar por primera vez: primero se baja la que tenga la cuenta (la del iPhone).
                if (table == "spaces" && journal.records[key] == null) continue
                val meta = journal.records[key] ?: SyncJournal.Meta(now, now, state = SyncJournal.State.LOCAL).also { journal.records[key] = it; created = true }
                if (!meta.isPending) continue
                val current = SyncRows.render(table, id, value, ledger, ctx)
                renderedAtPush[key] = current
                val row = stamped(merged(current, meta), table, meta)
                result += SyncRecord(table, remoteId(table, id), meta.updatedAt, null, row.toString().toByteArray(), ctx.spaceId)
            }
            // Lápidas: lo que estaba en la nube y se borró aquí.
            val prefix = "$table/"
            for ((key, meta) in journal.records) {
                if (!key.startsWith(prefix) || meta.deletedAt == null || !meta.isPending) continue
                val id = key.removePrefix(prefix)
                renderedAtPush[key] = null
                val row = stamped(JSONObject((meta.remote ?: JSONObject().put("id", id)).toString()), table, meta)
                result += SyncRecord(table, remoteId(table, id), meta.updatedAt, meta.deletedAt, row.toString().toByteArray(), ctx.spaceId)
            }
        }
        if (created) journal.save()
        return result
    }

    override fun markSynced(records: List<SyncRecord>) {
        for (r in records) {
            val key = journal.key(r.table, localId(r.table, r.id))
            journal.attempts.remove(key)
            val meta = journal.records[key] ?: continue
            // Si cambió mientras se subía, sigue pendiente para la próxima vez.
            if (meta.updatedAt != r.updatedAt) continue
            meta.state = SyncJournal.State.SYNCED
            meta.remote = JSONObject(String(r.payload))
            meta.base = renderedAtPush[key]
        }
        journal.save()
    }

    override fun markFailed(records: List<SyncRecord>, attempts: Int) {
        for (r in records) {
            val key = journal.key(r.table, localId(r.table, r.id))
            journal.attempts[key] = attempts
            if (attempts >= SyncEngine.MAX_ATTEMPTS) journal.records[key]?.state = SyncJournal.State.FAILED
        }
        journal.save()
    }

    override fun attempts(record: SyncRecord) = journal.attempts[journal.key(record.table, localId(record.table, record.id))] ?: 0

    override fun local(table: String, id: String): SyncRecord? {
        if (table == "spaces" && !id.equals(ctx.spaceId, ignoreCase = true)) return null
        val meta = journal.meta(table, localId(table, id)) ?: return null
        return SyncRecord(table, id, meta.updatedAt, meta.deletedAt)
    }

    override fun apply(record: SyncRecord) {
        val table = record.table
        if (table !in SyncRows.TABLES) return
        if (table == "spaces" && !record.id.equals(ctx.spaceId, ignoreCase = true)) return
        val id = localId(table, record.id)
        val key = journal.key(table, id)
        val existing = journal.records[key]
        if (existing != null && existing.state == SyncJournal.State.SYNCED && existing.updatedAt == record.updatedAt && existing.deletedAt == record.deletedAt) return
        val row = runCatching { JSONObject(String(record.payload)) }.getOrNull() ?: run { unreadableRows++; return }
        var l = working ?: store.ledger.value
        var base: JSONObject? = null
        try {
            if (record.deletedAt != null) l = remove(l, table, id, row)
            else {
                val (next, value) = upsert(l, table, id, row)
                l = next
                if (value != null) base = SyncRows.render(table, id, value, l, ctx, ServerTime.parse(row.optString("balanceAt")) ?: Instant.EPOCH)
            }
        } catch (e: Exception) {
            unreadableRows++
            return
        }
        working = l
        val created = ServerTime.parse(row.optString("createdAt")) ?: existing?.createdAt ?: record.updatedAt
        journal.records[key] = SyncJournal.Meta(created, record.updatedAt, record.deletedAt, SyncJournal.State.SYNCED, row, base)
        journal.attempts.remove(key)
        appliedChanges++
    }

    private fun <T> List<T>.upsertBy(item: T, id: (T) -> String): List<T> =
        if (any { id(it) == id(item) }) map { if (id(it) == id(item)) item else it } else this + item

    /** Escribe una fila en los datos. Devuelve el valor como lo ve el diario, para guardar la `base`. */
    private fun upsert(l: Ledger, table: String, id: String, o: JSONObject): Pair<Ledger, Any?> = when (table) {
        "spaces" -> { val c = Currency.from(o.optString("currencyCode", "COP")); workingCurrency = c; l to c.code }
        "institutions" -> SyncRows.institutionFrom(o).let { l.copy(institutions = l.institutions.upsertBy(it) { x -> x.id }) to it }
        "reward_programs" -> SyncRows.rewardFrom(o).let { l.copy(rewards = l.rewards.upsertBy(it) { x -> x.id }) to it }
        "products" -> SyncRows.productFrom(o).let { l.copy(products = l.products.upsertBy(it) { x -> x.id }) to it }
        "recurring" -> {
            val alert = l.recurring.firstOrNull { it.id == id }?.alert ?: AlertRule()
            SyncRows.recurringFrom(o, alert).let { l.copy(recurring = l.recurring.upsertBy(it) { x -> x.id }) to it }
        }
        "entries" -> {
            val old = l.entries.firstOrNull { it.id == id }
            var e = SyncRows.entryFrom(o)
            // Lo que solo existe en Android se conserva: los puntos que sumó y la hora si el día no cambió.
            if (old != null) e = e.copy(pointsEarned = old.pointsEarned, atMinutes = if (old.occurredAt == e.occurredAt) old.atMinutes else null)
            l.copy(entries = l.entries.upsertBy(e) { x -> x.id }) to e
        }
        "transfers" -> SyncRows.transferFrom(o).let { l.copy(transfers = l.transfers.upsertBy(it) { x -> x.id }) to it }
        "reminders" -> {
            val recurringId = o.getString("recurringId").lowercase()
            val alert = SyncRows.alertFrom(o)
            journal.reminderIds[recurringId] = id
            if (l.recurring.none { it.id == recurringId }) l to null
            else l.copy(recurring = l.recurring.map { if (it.id == recurringId) it.copy(alert = alert) else it }) to
                (if (alert.mode == AlertMode.GENERAL) null else recurringId to alert)
        }
        "budgets" -> SyncRows.budgetFrom(o).let { l.copy(budgets = l.budgets.upsertBy(it) { x -> x.id }) to it }
        "savings_goals" -> SyncRows.goalFrom(o).let { l.copy(goals = l.goals.upsertBy(it) { x -> x.id }) to it }
        "goal_contributions" -> SyncRows.contributionFrom(o).let { l.copy(contributions = l.contributions.upsertBy(it) { x -> x.id }) to it }
        else -> l to null
    }

    private fun remove(l: Ledger, table: String, id: String, o: JSONObject): Ledger = when (table) {
        "institutions" -> l.copy(institutions = l.institutions.filter { it.id != id })
        "reward_programs" -> l.copy(rewards = l.rewards.filter { it.id != id })
        "products" -> l.copy(products = l.products.filter { it.id != id })
        "recurring" -> l.copy(recurring = l.recurring.filter { it.id != id })
        "entries" -> l.copy(entries = l.entries.filter { it.id != id })
        "transfers" -> l.copy(transfers = l.transfers.filter { it.id != id })
        "reminders" -> {
            val recurringId = o.optString("recurringId").lowercase()
            if (journal.reminderId(recurringId) != id) l
            else l.copy(recurring = l.recurring.map { if (it.id == recurringId) it.copy(alert = AlertRule()) else it })
        }
        "budgets" -> l.copy(budgets = l.budgets.filter { it.id != id })
        "savings_goals" -> l.copy(goals = l.goals.filter { it.id != id })
        "goal_contributions" -> l.copy(contributions = l.contributions.filter { it.id != id })
        else -> l
    }

    override fun cursor(table: String): Instant? = journal.cursors[table]

    override fun setCursor(date: Instant, table: String) {
        journal.cursors[table] = date
        // Se guarda una vez por tabla, no en cada fila.
        val l = working
        if (l != null || workingCurrency != null) store.applyRemote(l ?: store.ledger.value, workingCurrency)
        working = null
        workingCurrency = null
        journal.save()
    }

    /** Cuántos cambios esperan subir (para la pastilla "Sin conexión · 3 cambios sin sincronizar"). */
    fun pendingCount(): Int {
        val snap = SyncRows.snapshot(store.ledger.value, store.currency.value, journal::reminderId)
        var n = 0
        for ((table, items) in snap) for (id in items.keys) {
            val m = journal.meta(table, id)
            if ((m == null && table != "spaces") || m?.isPending == true) n++
        }
        n += journal.records.values.count { it.deletedAt != null && it.isPending }
        return n
    }

    fun failedCount() = journal.records.values.count { it.state == SyncJournal.State.FAILED }

    /** Vuelve a intentar los que fallaron 3 veces. */
    fun retryFailed() {
        journal.records.values.filter { it.state == SyncJournal.State.FAILED }.forEach { it.state = SyncJournal.State.PENDING }
        journal.attempts.clear()
        journal.save()
    }
}
