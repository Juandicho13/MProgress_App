package com.olarte.mprogress.data

import com.olarte.mprogress.domain.DebtDirection
import com.olarte.mprogress.domain.DebtPaymentRecord
import com.olarte.mprogress.domain.DebtRecord
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/**
 * Deudas y abonos en el archivo local, en el respaldo .mprogress y en la nube (entidades "debts" y "debt_payments" dentro de
 * sync_records), con las mismas claves que BackupSnapshot.DebtRow y DebtPaymentRow de iOS. Las fechas van al mediodía UTC,
 * como las demás fechas sin hora de Android.
 */
object DebtRows {
    const val DEBTS = "debts"
    const val PAYMENTS = "debt_payments"

    private fun JSONObject.opt(k: String, v: Any?): JSONObject = put(k, v ?: JSONObject.NULL)
    private fun JSONObject.str(k: String): String? = if (!has(k) || isNull(k)) null else optString(k)
    private fun JSONObject.id(k: String): String? = str(k)?.lowercase()
    private fun <T> JSONArray?.list(f: (JSONObject) -> T): List<T> =
        if (this == null) emptyList() else (0 until length()).mapNotNull { i -> runCatching { f(getJSONObject(i)) }.getOrNull() }

    // ---------- Archivo local (LedgerJson) ----------

    fun encodeLocal(l: Ledger, into: JSONObject) {
        into.put("debts", JSONArray(l.debts.map {
            JSONObject().put("id", it.id).put("person", it.person).put("direction", it.direction.raw).put("amountMinor", it.amountMinor)
                .put("date", it.date.toString()).opt("dueDate", it.dueDate?.toString()).opt("note", it.note).opt("productId", it.productId)
                .opt("transferId", it.transferId)
        }))
        into.put("debtPayments", JSONArray(l.debtPayments.map {
            JSONObject().put("id", it.id).put("debtId", it.debtId).put("amountMinor", it.amountMinor).put("date", it.date.toString())
                .opt("productId", it.productId).opt("transferId", it.transferId)
        }))
    }

    fun decodeLocal(o: JSONObject, l: Ledger): Ledger = l.copy(
        debts = o.optJSONArray("debts").list {
            DebtRecord(it.getString("id"), it.getString("person"), DebtDirection.from(it.str("direction")), it.getLong("amountMinor"),
                LocalDate.parse(it.getString("date")), it.str("dueDate")?.let(LocalDate::parse), it.str("note"), it.str("productId"), it.str("transferId"))
        },
        debtPayments = o.optJSONArray("debtPayments").list {
            DebtPaymentRecord(it.getString("id"), it.getString("debtId"), it.getLong("amountMinor"), LocalDate.parse(it.getString("date")),
                it.str("productId"), it.str("transferId"))
        },
    )

    // ---------- Fila del respaldo y de la nube ----------

    /** `date` escribe una fecha sin hora (al mediodía UTC) en el formato de quien llama. */
    fun debt(it: DebtRecord, spaceId: String, date: (LocalDate) -> String) = JSONObject().put("id", it.id).put("spaceId", spaceId)
        .put("person", it.person).put("directionRaw", it.direction.raw).put("amountMinor", it.amountMinor).put("occurredAt", date(it.date))
        .opt("dueDate", it.dueDate?.let(date)).opt("notes", it.note).opt("productId", it.productId).opt("transferId", it.transferId)

    fun payment(it: DebtPaymentRecord, spaceId: String, date: (LocalDate) -> String) = JSONObject().put("id", it.id).put("spaceId", spaceId)
        .put("debtId", it.debtId).put("amountMinor", it.amountMinor).put("occurredAt", date(it.date)).opt("productId", it.productId)
        .opt("transferId", it.transferId)

    /** `day` lee una fecha ISO 8601 del respaldo o la nube como día local. */
    fun debtFrom(o: JSONObject, day: (String) -> LocalDate?) = DebtRecord(o.getString("id").lowercase(), o.getString("person"),
        DebtDirection.from(o.str("directionRaw")), o.getLong("amountMinor"), day(o.getString("occurredAt")) ?: LocalDate.now(),
        o.str("dueDate")?.let(day), o.str("notes"), o.id("productId"), o.id("transferId"))

    fun paymentFrom(o: JSONObject, day: (String) -> LocalDate?) = DebtPaymentRecord(o.getString("id").lowercase(), o.getString("debtId").lowercase(),
        o.getLong("amountMinor"), day(o.getString("occurredAt")) ?: LocalDate.now(), o.id("productId"), o.id("transferId"))

    /** Filas vivas de un arreglo del respaldo (sin deletedAt). */
    fun <T> alive(a: JSONArray?, f: (JSONObject) -> T): List<T> = a.list { it }.filter { !it.has("deletedAt") || it.isNull("deletedAt") }
        .mapNotNull { runCatching { f(it) }.getOrNull() }

    // ---------- Nube ----------

    fun syncDate(ctx: SyncRows.Ctx): (LocalDate) -> String = { d -> ctx.date(SyncRows.noon(d)) }

    /** Ids en minúscula, como Postgres. */
    fun canonical(l: Ledger) = l.copy(
        debts = l.debts.map { it.copy(id = it.id.lowercase(), productId = it.productId?.lowercase(), transferId = it.transferId?.lowercase()) },
        debtPayments = l.debtPayments.map { it.copy(id = it.id.lowercase(), debtId = it.debtId.lowercase(), productId = it.productId?.lowercase(),
            transferId = it.transferId?.lowercase()) },
    )

    fun upsert(l: Ledger, table: String, o: JSONObject): Pair<Ledger, Any?> = when (table) {
        DEBTS -> debtFrom(o, SyncRows::day).let { d -> l.copy(debts = if (l.debts.any { it.id == d.id }) l.debts.map { if (it.id == d.id) d else it } else l.debts + d) to d }
        PAYMENTS -> paymentFrom(o, SyncRows::day).let { p ->
            l.copy(debtPayments = if (l.debtPayments.any { it.id == p.id }) l.debtPayments.map { if (it.id == p.id) p else it } else l.debtPayments + p) to p
        }
        else -> l to null
    }

    fun remove(l: Ledger, table: String, id: String): Ledger = when (table) {
        DEBTS -> l.copy(debts = l.debts.filter { it.id != id })
        PAYMENTS -> l.copy(debtPayments = l.debtPayments.filter { it.id != id })
        else -> l
    }
}
