package com.olarte.mprogress.data

import com.olarte.mprogress.domain.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.UUID

/**
 * Cada registro de Android en su fila del respaldo de iOS (BackupSnapshot, mismas claves) y de vuelta, como BackupRows.swift.
 * Lo usan el archivo .mprogress y la sincronización cifrada (F10): el JSON de un sobre es exactamente la fila del respaldo.
 * Las filas salen sin createdAt, updatedAt ni deletedAt: esas las pone quien llama.
 */
object SyncRows {
    /** Id local del espacio Personal en el diario de cambios; al subir se cambia por el id del espacio en la nube. */
    const val SPACE_KEY = "personal"

    /** Espacio y dueño de las filas, y cómo se escriben las fechas (6 decimales para la nube, sin decimales en el respaldo). */
    class Ctx(val spaceId: String, val ownerId: String, val date: (Instant) -> String = ServerTime::format)

    /** Tablas que Android lee y escribe, en el orden del SyncEngine. `categories` y `splits` no: Android no las tiene. */
    val TABLES = listOf("spaces", "institutions", "reward_programs", "products", "recurring", "entries", "transfers", "reminders",
        "budgets", "savings_goals", "goal_contributions")

    private val uuid = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    /** iOS solo lee UUID válidos: lo que no lo es (datos de prueba) no se sube. */
    fun isUuid(id: String) = uuid.matches(id)

    fun noon(d: LocalDate): Instant = d.atTime(12, 0).toInstant(ZoneOffset.UTC)
    fun day(text: String?): LocalDate? = text?.let(ServerTime::parse)?.atZone(ZoneId.systemDefault())?.toLocalDate()

    /** El id de aviso de un pago fijo cuando no hay uno que haya venido de iOS (el mismo que usa el respaldo). */
    fun defaultReminderId(recurringId: String) = UUID.nameUUIDFromBytes(recurringId.toByteArray()).toString()

    private fun JSONObject.opt(k: String, v: Any?): JSONObject = put(k, v ?: JSONObject.NULL)
    private fun JSONObject.str(k: String): String? = if (!has(k) || isNull(k)) null else optString(k)
    private fun JSONObject.int(k: String): Int? = if (!has(k) || isNull(k)) null else optInt(k)
    private fun JSONObject.long(k: String): Long? = if (!has(k) || isNull(k)) null else optLong(k)
    private fun JSONObject.dbl(k: String): Double? = if (!has(k) || isNull(k)) null else optDouble(k)
    private fun JSONObject.id(k: String): String? = str(k)?.lowercase()
    private fun hex(v: Long?) = v?.let { "%06X".format(it) }

    // ---------- Fila de cada registro ----------

    fun space(currency: Currency, ctx: Ctx) = JSONObject().put("id", ctx.spaceId).put("ownerId", ctx.ownerId).put("name", "Personal").put("kindRaw", "personal")
        .put("currencyCode", currency.code).put("colorHex", "F55F1F").opt("icon", null).put("shareTotalsOnly", false).put("defaultSplit", 50).opt("endsOn", null)

    fun category(c: CategoryRecord) = JSONObject().put("id", c.id).opt("ownerSpaceId", null).put("name", c.name).put("icon", c.icon)
        .opt("colorHex", null).put("sort", c.sort).opt("lastUsedAt", null)

    fun institution(it: Institution, sort: Int, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("name", it.name)
        .opt("colorHex", hex(it.colorHex)).opt("icon", null).put("hidden", it.hidden).put("sort", sort)

    fun product(it: Product, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("institutionId", it.institutionId)
        .opt("parentProductId", it.parentProductId).put("kindRaw", it.kind.name.lowercase()).put("name", it.name).opt("last4", Store.cleanLast4(it.last4))
        .put("balanceMinor", it.balanceMinor).put("balanceAt", ctx.date(noon(it.balanceAt))).opt("creditLimitMinor", it.creditLimitMinor).opt("cutDay", it.cutDay)
        .opt("dueDay", it.dueDay).opt("rateEA", it.rateEA).opt("lockedUntil", null).put("inWallet", it.kind == ProductKind.CREDITO || it.kind == ProductKind.DEBITO)
        .put("hidden", it.hidden).opt("rewardProgramId", it.rewardProgramId).opt("pointsPerThousand", it.pointsPerThousand)

    fun recurring(it: RecurringRecord, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("kindRaw", it.kind.name.lowercase()).put("name", it.name)
        .opt("icon", null).put("amountMinor", it.amountMinor).put("cycleRaw", it.cycle.raw).opt("intervalDays", it.cycle.intervalDays).put("nextDate", ctx.date(noon(it.nextDate)))
        .put("anchorDay", it.anchor.day).put("anchorMonth", it.anchor.month).opt("categoryId", it.categoryId).opt("productId", it.productId).opt("responsibleId", null)
        .put("active", it.active).opt("createdBy", null).put("dateUnset", it.dateUnset).opt("endDate", it.endDate?.let { d -> ctx.date(noon(d)) }).opt("totalCount", it.totalCount)
        .put("paidCount", it.paidCount)

    /** La hora opcional de Android va dentro de la fecha; sin hora, al mediodía UTC (el mismo día en Colombia). */
    fun occurred(e: EntryRecord): Instant = e.atMinutes?.let { e.occurredAt.atTime(LocalTime.of(it / 60, it % 60)).atZone(ZoneId.systemDefault()).toInstant() } ?: noon(e.occurredAt)

    fun entry(it: EntryRecord, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("kindRaw", it.kind.name.lowercase())
        .put("amountMinor", it.amountMinor).put("occurredAt", ctx.date(occurred(it))).put("name", it.name).opt("merchant", null).opt("icon", null)
        .opt("categoryId", it.categoryId).opt("productId", it.productId).opt("recurringId", it.recurringId).opt("paidBy", null).opt("methodRaw", null)
        .put("sourceRaw", when (it.source) { "sms", "notificacion" -> "sms"; "recibo" -> "recibo"; else -> "manual" }).put("needsReview", false)
        .opt("notes", it.notes).opt("createdBy", null)

    fun transfer(it: TransferRecord, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("fromProductId", it.fromProductId)
        .put("toProductId", it.toProductId).put("amountMinor", it.amountMinor).put("occurredAt", ctx.date(noon(it.occurredAt))).opt("notes", it.note)

    fun reminder(id: String, r: RecurringRecord, ctx: Ctx) = JSONObject().put("id", id).put("spaceId", ctx.spaceId).put("recurringId", r.id)
        .put("daysBefore", r.alert.daysBefore).put("targetRaw", "yo").opt("userId", null).put("atMinutes", r.alert.atMinutes)
        .put("notifyPartnerOnPaid", false).put("sameDay", false).put("modeRaw", r.alert.mode.raw)

    fun budget(it: BudgetRecord, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).opt("categoryId", it.categoryId).put("monthlyLimitMinor", it.limitMinor)

    fun goal(it: GoalRecord, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("name", it.name).put("targetAmountMinor", it.targetMinor)
        .opt("targetDate", it.targetDate?.let { d -> ctx.date(noon(d)) }).opt("productId", it.productId)

    fun contribution(it: ContributionRecord, ctx: Ctx) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("goalId", it.goalId).opt("userId", null)
        .put("amountMinor", it.amountMinor).put("occurredAt", ctx.date(noon(it.occurredAt)))

    fun reward(it: RewardRecord, ctx: Ctx, balanceAt: Instant) = JSONObject().put("id", it.id).put("spaceId", ctx.spaceId).put("name", it.name).put("kindRaw", it.kind.raw)
        .put("balance", it.balance).opt("valuePerPoint", it.valuePerPoint).opt("expiresAt", it.expiresAt?.let { d -> ctx.date(noon(d)) }).opt("productId", null).opt("colorHex", null)
        .put("balanceAt", ctx.date(balanceAt))

    // ---------- De la fila al registro ----------

    private fun kind(raw: String?) = if (raw == "ingreso") EntryKind.INGRESO else EntryKind.GASTO

    fun institutionFrom(o: JSONObject) = Institution(o.getString("id").lowercase(), o.getString("name"), o.str("colorHex")?.toLongOrNull(16), o.optBoolean("hidden"))

    fun productFrom(o: JSONObject) = Product(o.getString("id").lowercase(), o.getString("institutionId").lowercase(), ProductKind.valueOf(o.getString("kindRaw").uppercase()),
        o.getString("name"), Store.cleanLast4(o.str("last4")), o.int("dueDay"), o.optLong("balanceMinor"), day(o.str("balanceAt")) ?: LocalDate.now(), o.optBoolean("hidden"),
        o.id("parentProductId"), o.long("creditLimitMinor"), o.int("cutDay"), o.dbl("rateEA"), o.id("rewardProgramId"), o.dbl("pointsPerThousand"))

    fun recurringFrom(o: JSONObject, alert: AlertRule = AlertRule()): RecurringRecord {
        val r = RecurringRecord(id = o.getString("id").lowercase(), kind = kind(o.getString("kindRaw")), name = o.getString("name"), amountMinor = o.getLong("amountMinor"),
            cycle = Cycle.from(o.getString("cycleRaw"), o.int("intervalDays")), nextDate = day(o.getString("nextDate")) ?: LocalDate.now(),
            anchor = CycleAnchor(o.getInt("anchorDay"), o.getInt("anchorMonth")), active = o.optBoolean("active", true), dateUnset = o.optBoolean("dateUnset", false),
            categoryId = o.id("categoryId"), productId = o.id("productId"), endDate = day(o.str("endDate")), totalCount = o.int("totalCount"),
            paidCount = o.optInt("paidCount", 0), alert = alert)
        val ended = !r.active && ((r.totalCount != null && r.paidCount >= r.totalCount) || (r.endDate != null && r.nextDate.isAfter(r.endDate)))
        return if (ended) r.copy(finished = true) else r
    }

    fun alertFrom(o: JSONObject) = AlertRule(AlertMode.from(o.str("modeRaw") ?: "personalizado"), o.optInt("daysBefore", 3), o.optInt("atMinutes", 540))

    fun entryFrom(o: JSONObject) = EntryRecord(id = o.getString("id").lowercase(), kind = kind(o.getString("kindRaw")), amountMinor = o.getLong("amountMinor"),
        occurredAt = day(o.getString("occurredAt")) ?: LocalDate.now(), name = o.optString("name"), categoryId = o.id("categoryId"), productId = o.id("productId"),
        recurringId = o.id("recurringId"), notes = o.str("notes"), source = o.str("sourceRaw").let { s -> if (s == "applePay" || s == "wallet") "sms" else s ?: "manual" })

    fun transferFrom(o: JSONObject) = TransferRecord(o.getString("id").lowercase(), o.getString("fromProductId").lowercase(), o.getString("toProductId").lowercase(),
        o.getLong("amountMinor"), day(o.getString("occurredAt")) ?: LocalDate.now(), o.str("notes"))

    fun budgetFrom(o: JSONObject) = BudgetRecord(o.getString("id").lowercase(), o.id("categoryId"), o.getLong("monthlyLimitMinor"))
    fun goalFrom(o: JSONObject) = GoalRecord(o.getString("id").lowercase(), o.getString("name"), o.getLong("targetAmountMinor"), day(o.str("targetDate")), o.id("productId"))
    fun contributionFrom(o: JSONObject) = ContributionRecord(o.getString("id").lowercase(), o.getString("goalId").lowercase(), o.getLong("amountMinor"),
        day(o.getString("occurredAt")) ?: LocalDate.now())
    fun rewardFrom(o: JSONObject) = RewardRecord(o.getString("id").lowercase(), o.getString("name"), RewardKind.from(o.str("kindRaw")), o.optLong("balance"),
        o.dbl("valuePerPoint"), day(o.str("expiresAt")))

    // ---------- Estado para el diario de cambios ----------

    /**
     * Lo que cuenta como "el registro" en cada tabla, para saber qué cambió entre dos versiones de los datos. Los avisos salen de
     * los pagos fijos (en Android el aviso vive dentro del fijo); el espacio es solo la moneda.
     */
    fun snapshot(l: Ledger, currency: Currency, reminderId: (String) -> String): Map<String, Map<String, Any>> = mapOf(
        "spaces" to mapOf(SPACE_KEY to currency.code),
        "institutions" to l.institutions.associateBy { it.id },
        "reward_programs" to l.rewards.associateBy { it.id },
        "products" to l.products.associateBy { it.id },
        "recurring" to l.recurring.associateBy { it.id },
        "entries" to l.entries.associateBy { it.id },
        "transfers" to l.transfers.associateBy { it.id },
        "reminders" to l.recurring.filter { it.alert.mode != AlertMode.GENERAL }.associate { reminderId(it.id) to (it.id to it.alert) },
        "budgets" to l.budgets.associateBy { it.id },
        "savings_goals" to l.goals.associateBy { it.id },
        "goal_contributions" to l.contributions.associateBy { it.id },
    ).mapValues { (_, m) -> m.filterKeys { it == SPACE_KEY || isUuid(it) } }

    /** La fila de un registro del estado de `snapshot`. */
    fun render(table: String, id: String, value: Any, l: Ledger, ctx: Ctx, rewardBalanceAt: Instant = ServerTime.now()): JSONObject = when (table) {
        "spaces" -> space(Currency.from(value as String), ctx)
        "institutions" -> (value as Institution).let { institution(it, l.institutions.indexOfFirst { i -> i.id == it.id }.coerceAtLeast(0), ctx) }
        "reward_programs" -> reward(value as RewardRecord, ctx, rewardBalanceAt)
        "products" -> product(value as Product, ctx)
        "recurring" -> recurring(value as RecurringRecord, ctx)
        "entries" -> entry(value as EntryRecord, ctx)
        "transfers" -> transfer(value as TransferRecord, ctx)
        "reminders" -> {
            val recurringId = (value as Pair<*, *>).first as String
            reminder(id, l.recurring.first { it.id == recurringId }, ctx)
        }
        "budgets" -> budget(value as BudgetRecord, ctx)
        "savings_goals" -> goal(value as GoalRecord, ctx)
        "goal_contributions" -> contribution(value as ContributionRecord, ctx)
        else -> error("Tabla desconocida: $table")
    }

    /** Ids siempre en minúscula (como Postgres), así un registro de iOS y uno de Android se encuentran aunque vengan escritos distinto. */
    fun canonical(l: Ledger): Ledger {
        fun String.c() = lowercase()
        fun String?.c() = this?.lowercase()
        return l.copy(
            institutions = l.institutions.map { it.copy(id = it.id.c()) },
            products = l.products.map { it.copy(id = it.id.c(), institutionId = it.institutionId.c(), parentProductId = it.parentProductId.c(), rewardProgramId = it.rewardProgramId.c()) },
            recurring = l.recurring.map { it.copy(id = it.id.c(), categoryId = it.categoryId.c(), productId = it.productId.c()) },
            entries = l.entries.map { it.copy(id = it.id.c(), categoryId = it.categoryId.c(), productId = it.productId.c(), recurringId = it.recurringId.c()) },
            transfers = l.transfers.map { it.copy(id = it.id.c(), fromProductId = it.fromProductId.c(), toProductId = it.toProductId.c()) },
            budgets = l.budgets.map { it.copy(id = it.id.c(), categoryId = it.categoryId.c()) },
            goals = l.goals.map { it.copy(id = it.id.c(), productId = it.productId.c()) },
            contributions = l.contributions.map { it.copy(id = it.id.c(), goalId = it.goalId.c()) },
            rewards = l.rewards.map { it.copy(id = it.id.c()) },
        )
    }

    /** Arreglo JSON de filas. */
    fun array(rows: List<JSONObject>) = JSONArray(rows)
}
