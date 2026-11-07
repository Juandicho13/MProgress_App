package com.olarte.mprogress.data

import com.olarte.mprogress.domain.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/** Formato del archivo local y del respaldo. Todos los campos nuevos son opcionales para leer archivos viejos. */
object LedgerJson {
    const val VERSION = 2

    private fun JSONObject.opt(k: String, v: Any?): JSONObject = put(k, v ?: JSONObject.NULL)
    private fun JSONObject.str(k: String): String? = if (!has(k) || isNull(k)) null else optString(k)
    private fun JSONObject.int(k: String): Int? = if (!has(k) || isNull(k)) null else optInt(k)
    private fun JSONObject.long(k: String): Long? = if (!has(k) || isNull(k)) null else optLong(k)
    private fun JSONObject.dbl(k: String): Double? = if (!has(k) || isNull(k)) null else optDouble(k)
    private fun JSONObject.date(k: String): LocalDate? = str(k)?.let(LocalDate::parse)
    private fun <T> JSONArray?.list(f: (JSONObject) -> T): List<T> = if (this == null) emptyList() else (0 until length()).mapNotNull { runCatching { f(getJSONObject(it)) }.getOrNull() }
    private fun <T> arr(items: List<T>, f: (T) -> JSONObject) = JSONArray(items.map(f))

    fun encode(l: Ledger): JSONObject = JSONObject().apply {
        put("version", VERSION)
        put("institutions", arr(l.institutions) { JSONObject().put("id", it.id).put("name", it.name).opt("color", it.colorHex).put("hidden", it.hidden) })
        put("products", arr(l.products) {
            JSONObject().put("id", it.id).put("institutionId", it.institutionId).put("kind", it.kind.name).put("name", it.name)
                .opt("last4", it.last4).opt("dueDay", it.dueDay).put("balanceMinor", it.balanceMinor).put("balanceAt", it.balanceAt.toString())
                .put("hidden", it.hidden).opt("parentProductId", it.parentProductId).opt("creditLimitMinor", it.creditLimitMinor).opt("cutDay", it.cutDay)
                .opt("rateEA", it.rateEA).opt("rewardProgramId", it.rewardProgramId).opt("pointsPerThousand", it.pointsPerThousand)
        })
        put("recurring", arr(l.recurring) {
            JSONObject().put("id", it.id).put("kind", it.kind.name).put("name", it.name).put("amountMinor", it.amountMinor)
                .put("cycle", it.cycle.raw).opt("intervalDays", it.cycle.intervalDays).put("intervalMonths", it.cycle.intervalMonths)
                .put("nextDate", it.nextDate.toString()).put("anchorDay", it.anchor.day).put("anchorMonth", it.anchor.month)
                .put("active", it.active).put("dateUnset", it.dateUnset).opt("productId", it.productId).opt("categoryId", it.categoryId)
                .opt("endDate", it.endDate?.toString()).opt("totalCount", it.totalCount).put("paidCount", it.paidCount).put("finished", it.finished)
                .put("alertMode", it.alert.mode.raw).put("alertDays", it.alert.daysBefore).put("alertMinutes", it.alert.atMinutes)
        })
        put("entries", arr(l.entries) {
            JSONObject().put("id", it.id).put("kind", it.kind.name).put("amountMinor", it.amountMinor).put("occurredAt", it.occurredAt.toString())
                .put("name", it.name).opt("productId", it.productId).opt("recurringId", it.recurringId).opt("categoryId", it.categoryId)
                .opt("notes", it.notes).opt("atMinutes", it.atMinutes).put("source", it.source).put("pointsEarned", it.pointsEarned)
                .opt("merchant", it.merchant)
        })
        put("transfers", arr(l.transfers) {
            JSONObject().put("id", it.id).put("from", it.fromProductId).put("to", it.toProductId).put("amountMinor", it.amountMinor)
                .put("occurredAt", it.occurredAt.toString()).opt("note", it.note)
        })
        put("budgets", arr(l.budgets) { JSONObject().put("id", it.id).opt("categoryId", it.categoryId).put("limitMinor", it.limitMinor) })
        put("goals", arr(l.goals) {
            JSONObject().put("id", it.id).put("name", it.name).put("targetMinor", it.targetMinor).opt("targetDate", it.targetDate?.toString()).opt("productId", it.productId)
        })
        put("contributions", arr(l.contributions) { JSONObject().put("id", it.id).put("goalId", it.goalId).put("amountMinor", it.amountMinor).put("occurredAt", it.occurredAt.toString()) })
        put("rewards", arr(l.rewards) {
            JSONObject().put("id", it.id).put("name", it.name).put("kind", it.kind.raw).put("balance", it.balance).opt("valuePerPoint", it.valuePerPoint)
                .opt("expiresAt", it.expiresAt?.toString())
        })
        put("captures", arr(l.captures) {
            JSONObject().put("id", it.id).put("kind", it.kind.name).put("amountMinor", it.amountMinor).opt("merchant", it.merchant).opt("last4", it.last4)
                .opt("bank", it.bank).put("source", it.source).put("text", it.text).put("receivedAt", it.receivedAt.toString())
        })
        put("merchantAliases", arr(l.merchantAliases) { JSONObject().put("id", it.id).put("key", it.key).put("name", it.name).opt("categoryId", it.categoryId) })
    }

    fun decode(o: JSONObject) = Ledger(
        institutions = o.optJSONArray("institutions").list { Institution(it.getString("id"), it.getString("name"), it.long("color"), it.optBoolean("hidden", false)) },
        products = o.optJSONArray("products").list {
            Product(it.getString("id"), it.getString("institutionId"), ProductKind.valueOf(it.getString("kind")), it.getString("name"), it.str("last4"), it.int("dueDay"),
                it.optLong("balanceMinor", 0), it.date("balanceAt") ?: LocalDate.now(), it.optBoolean("hidden", false), it.str("parentProductId"),
                it.long("creditLimitMinor"), it.int("cutDay"), it.dbl("rateEA"), it.str("rewardProgramId"), it.dbl("pointsPerThousand"))
        },
        recurring = o.optJSONArray("recurring").list {
            RecurringRecord(id = it.getString("id"), kind = EntryKind.valueOf(it.getString("kind")), name = it.getString("name"),
                amountMinor = it.getLong("amountMinor"), cycle = Cycle.from(it.getString("cycle"), it.int("intervalDays"), it.int("intervalMonths")),
                nextDate = LocalDate.parse(it.getString("nextDate")), anchor = CycleAnchor(it.getInt("anchorDay"), it.getInt("anchorMonth")),
                active = it.optBoolean("active", true), dateUnset = it.optBoolean("dateUnset", false), productId = it.str("productId"),
                categoryId = it.str("categoryId"), endDate = it.date("endDate"), totalCount = it.int("totalCount"), paidCount = it.optInt("paidCount", 0),
                finished = it.optBoolean("finished", false),
                alert = AlertRule(AlertMode.from(it.str("alertMode")), it.optInt("alertDays", 3), it.optInt("alertMinutes", 540)))
        },
        entries = o.optJSONArray("entries").list {
            EntryRecord(id = it.getString("id"), kind = EntryKind.valueOf(it.getString("kind")), amountMinor = it.getLong("amountMinor"),
                occurredAt = LocalDate.parse(it.getString("occurredAt")), name = it.optString("name"),
                productId = it.str("productId"), recurringId = it.str("recurringId"), categoryId = it.str("categoryId"), notes = it.str("notes"),
                atMinutes = it.int("atMinutes"), source = it.str("source") ?: "manual", pointsEarned = it.optLong("pointsEarned", 0), merchant = it.str("merchant"))
        },
        transfers = o.optJSONArray("transfers").list {
            TransferRecord(it.getString("id"), it.getString("from"), it.getString("to"), it.getLong("amountMinor"), LocalDate.parse(it.getString("occurredAt")), it.str("note"))
        },
        budgets = o.optJSONArray("budgets").list { BudgetRecord(it.getString("id"), it.str("categoryId"), it.getLong("limitMinor")) },
        goals = o.optJSONArray("goals").list { GoalRecord(it.getString("id"), it.getString("name"), it.getLong("targetMinor"), it.date("targetDate"), it.str("productId")) },
        contributions = o.optJSONArray("contributions").list { ContributionRecord(it.getString("id"), it.getString("goalId"), it.getLong("amountMinor"), LocalDate.parse(it.getString("occurredAt"))) },
        rewards = o.optJSONArray("rewards").list {
            RewardRecord(it.getString("id"), it.getString("name"), RewardKind.from(it.str("kind")), it.optLong("balance", 0), it.dbl("valuePerPoint"), it.date("expiresAt"))
        },
        captures = o.optJSONArray("captures").list {
            PendingCapture(it.getString("id"), EntryKind.valueOf(it.getString("kind")), it.getLong("amountMinor"), it.str("merchant"), it.str("last4"),
                it.str("bank"), it.optString("source"), it.optString("text"), it.date("receivedAt") ?: LocalDate.now())
        },
        merchantAliases = o.optJSONArray("merchantAliases").list { MerchantAliasRule(it.getString("id"), it.getString("key"), it.getString("name"), it.str("categoryId")) },
    )
}
