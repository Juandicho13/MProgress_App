package com.olarte.mprogress.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.olarte.mprogress.domain.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Respaldo (F09-06). El archivo .mprogress usa el mismo formato que iOS (BackupSnapshot, versión 1), así un respaldo
 * hecho en el iPhone se abre en Android y al revés. Los respaldos automáticos diarios van cifrados con una llave del teléfono.
 */
object BackupCodec {
    const val VERSION = 1
    private const val SPACE = "5A000000-0000-4000-8000-000000000001"
    private const val OWNER = "5A000000-0000-4000-8000-0000000000FF"

    private fun iso(d: LocalDate) = d.atTime(12, 0).atOffset(ZoneOffset.UTC).toInstant().toString()
    /** Sin decimales: el decodificador `.iso8601` del respaldo de iOS no lee fracciones de segundo. */
    private fun now() = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString()
    private fun day(s: String): LocalDate = Instant.parse(s).atZone(ZoneId.systemDefault()).toLocalDate()
    private fun JSONObject.opt(k: String, v: Any?): JSONObject = put(k, v ?: JSONObject.NULL)
    private fun JSONObject.str(k: String): String? = if (!has(k) || isNull(k)) null else optString(k)
    private fun JSONObject.int(k: String): Int? = if (!has(k) || isNull(k)) null else optInt(k)
    private fun JSONObject.long(k: String): Long? = if (!has(k) || isNull(k)) null else optLong(k)
    private fun JSONObject.dbl(k: String): Double? = if (!has(k) || isNull(k)) null else optDouble(k)
    private fun JSONObject.alive() = !has("deletedAt") || isNull("deletedAt")
    private fun <T> JSONArray?.rows(f: (JSONObject) -> T?): List<T> = if (this == null) emptyList() else (0 until length()).mapNotNull { i -> getJSONObject(i).takeIf { it.alive() }?.let(f) }
    private fun stamps(o: JSONObject) = o.put("createdAt", now()).put("updatedAt", now()).put("deletedAt", JSONObject.NULL)
    private fun hex(v: Long?) = v?.let { "%06X".format(it) }

    fun encode(l: Ledger, currency: Currency): JSONObject = JSONObject().apply {
        put("version", VERSION); put("createdAt", now()); put("app", "MProgress")
        put("spaces", JSONArray().put(stamps(JSONObject().put("id", SPACE).put("ownerId", OWNER).put("name", "Personal").put("kindRaw", "personal")
            .put("currencyCode", currency.code).put("colorHex", "F55F1F").opt("icon", null).put("shareTotalsOnly", false).put("defaultSplit", 50).opt("endsOn", null))))
        put("categories", JSONArray(Categories.all.map { stamps(JSONObject().put("id", it.id).opt("ownerSpaceId", null).put("name", it.name).put("icon", it.icon)
            .opt("colorHex", null).put("sort", it.sort).opt("lastUsedAt", null)) } +
            // Las propias van con su espacio, como en iOS.
            l.categories.map { stamps(JSONObject().put("id", it.id).put("ownerSpaceId", SPACE).put("name", it.name).put("icon", it.icon)
                .opt("colorHex", null).put("sort", it.sort).opt("lastUsedAt", null)) }))
        put("institutions", JSONArray(l.institutions.mapIndexed { i, it -> stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("name", it.name)
            .opt("colorHex", hex(it.colorHex)).opt("icon", null).put("hidden", it.hidden).put("sort", i)) }))
        put("products", JSONArray(l.products.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("institutionId", it.institutionId)
            .opt("parentProductId", it.parentProductId).put("kindRaw", it.kind.name.lowercase()).put("name", it.name).opt("last4", it.last4)
            .put("balanceMinor", it.balanceMinor).put("balanceAt", iso(it.balanceAt)).opt("creditLimitMinor", it.creditLimitMinor).opt("cutDay", it.cutDay)
            .opt("dueDay", it.dueDay).opt("rateEA", it.rateEA).opt("lockedUntil", null).put("inWallet", it.kind == ProductKind.CREDITO || it.kind == ProductKind.DEBITO)
            .put("hidden", it.hidden).opt("rewardProgramId", it.rewardProgramId).opt("pointsPerThousand", it.pointsPerThousand)) }))
        put("recurring", JSONArray(l.recurring.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("kindRaw", it.kind.name.lowercase()).put("name", it.name)
            .opt("icon", null).put("amountMinor", it.amountMinor).put("cycleRaw", it.cycle.raw).opt("intervalDays", it.cycle.intervalDays).put("nextDate", iso(it.nextDate))
            .put("intervalMonths", it.cycle.intervalMonths).opt("firstDay", it.cycle.firstDay).opt("secondDay", it.cycle.secondDay)
            .put("anchorDay", it.anchor.day).put("anchorMonth", it.anchor.month).opt("categoryId", it.categoryId).opt("productId", it.productId).opt("responsibleId", null)
            .put("active", it.active).opt("createdBy", null).put("dateUnset", it.dateUnset).opt("endDate", it.endDate?.let(::iso)).opt("totalCount", it.totalCount)
            .put("paidCount", it.paidCount)) }))
        put("entries", JSONArray(l.entries.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("kindRaw", it.kind.name.lowercase())
            .put("amountMinor", it.amountMinor).put("occurredAt", iso(it.occurredAt)).put("name", it.name).opt("merchant", it.merchant).opt("icon", null)
            .opt("categoryId", it.categoryId).opt("productId", it.productId).opt("recurringId", it.recurringId).opt("paidBy", null).opt("methodRaw", null)
            .put("sourceRaw", when (it.source) { "sms", "notificacion" -> "sms"; "recibo" -> "recibo"; else -> "manual" }).put("needsReview", false)
            .opt("notes", it.notes).opt("createdBy", null)) }))
        put("transfers", JSONArray(l.transfers.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("fromProductId", it.fromProductId)
            .put("toProductId", it.toProductId).put("amountMinor", it.amountMinor).put("occurredAt", iso(it.occurredAt)).opt("notes", it.note)) }))
        put("reminders", JSONArray(l.recurring.filter { it.alert.mode != AlertMode.GENERAL }.map { stamps(JSONObject().put("id", java.util.UUID.nameUUIDFromBytes(it.id.toByteArray()).toString())
            .put("spaceId", SPACE).put("recurringId", it.id).put("daysBefore", it.alert.daysBefore).put("targetRaw", "yo").opt("userId", null)
            .put("atMinutes", it.alert.atMinutes).put("notifyPartnerOnPaid", false).put("sameDay", false).put("modeRaw", it.alert.mode.raw)) }))
        put("budgets", JSONArray(l.budgets.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).opt("categoryId", it.categoryId).put("monthlyLimitMinor", it.limitMinor)) }))
        put("goals", JSONArray(l.goals.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("name", it.name).put("targetAmountMinor", it.targetMinor)
            .opt("targetDate", it.targetDate?.let(::iso)).opt("productId", it.productId)) }))
        put("contributions", JSONArray(l.contributions.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("goalId", it.goalId).opt("userId", null)
            .put("amountMinor", it.amountMinor).put("occurredAt", iso(it.occurredAt))) }))
        put("rewards", JSONArray(l.rewards.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("name", it.name).put("kindRaw", it.kind.raw)
            .put("balance", it.balance).opt("valuePerPoint", it.valuePerPoint).opt("expiresAt", it.expiresAt?.let(::iso)).opt("productId", null).opt("colorHex", null)
            .put("balanceAt", now())) }))
        put("merchantAliases", JSONArray(l.merchantAliases.map { stamps(JSONObject().put("id", it.id).put("spaceId", SPACE).put("key", it.key).put("name", it.name)
            .opt("categoryId", it.categoryId)) }))
        // Quién te debe: mismas claves que BackupSnapshot.debts y debtPayments de iOS.
        put("debts", JSONArray(l.debts.map { stamps(DebtRows.debt(it, SPACE, ::iso)) }))
        put("debtPayments", JSONArray(l.debtPayments.map { stamps(DebtRows.payment(it, SPACE, ::iso)) }))
    }

    class NotMProgress : Exception("Este archivo no es un respaldo de MProgress.")
    class Newer(v: Int) : Exception("Este respaldo es de una versión más nueva de la app ($v). Actualiza MProgress para abrirlo.")

    /** Lee un .mprogress (de iOS o Android). Devuelve los datos y la moneda del espacio. */
    fun decode(text: String): Pair<Ledger, Currency> {
        val o = runCatching { JSONObject(text) }.getOrNull()?.takeIf { it.optString("app") == "MProgress" } ?: throw NotMProgress()
        if (o.optInt("version", 1) > VERSION) throw Newer(o.optInt("version"))
        val currency = o.optJSONArray("spaces")?.let { a -> (0 until a.length()).map { a.getJSONObject(it) }.firstOrNull { it.optString("kindRaw") == "personal" } }
            ?.optString("currencyCode")?.let(Currency::from) ?: Currency.COP
        val reminders = o.optJSONArray("reminders").rows { it }.associateBy { it.optString("recurringId") }
        fun kind(raw: String) = if (raw == "ingreso") EntryKind.INGRESO else EntryKind.GASTO
        val ledger = Ledger(
            institutions = o.optJSONArray("institutions").rows { Institution(it.getString("id"), it.getString("name"), it.str("colorHex")?.toLongOrNull(16), it.optBoolean("hidden")) },
            products = o.optJSONArray("products").rows {
                Product(it.getString("id"), it.getString("institutionId"), ProductKind.valueOf(it.getString("kindRaw").uppercase()), it.getString("name"), it.str("last4"),
                    it.int("dueDay"), it.optLong("balanceMinor"), day(it.getString("balanceAt")), it.optBoolean("hidden"), it.str("parentProductId"),
                    it.long("creditLimitMinor"), it.int("cutDay"), it.dbl("rateEA"), it.str("rewardProgramId"), it.dbl("pointsPerThousand"))
            },
            recurring = o.optJSONArray("recurring").rows {
                val rem = reminders[it.getString("id")]
                RecurringRecord(id = it.getString("id"), kind = kind(it.getString("kindRaw")), name = it.getString("name"), amountMinor = it.getLong("amountMinor"),
                    cycle = Cycle.from(it.getString("cycleRaw"), it.int("intervalDays"), it.int("intervalMonths"), it.int("firstDay"), it.int("secondDay")), nextDate = day(it.getString("nextDate")),
                    anchor = CycleAnchor(it.getInt("anchorDay"), it.getInt("anchorMonth")), active = it.optBoolean("active", true), dateUnset = it.optBoolean("dateUnset", false),
                    categoryId = it.str("categoryId"), productId = it.str("productId"), endDate = it.str("endDate")?.let(::day), totalCount = it.int("totalCount"),
                    paidCount = it.optInt("paidCount", 0),
                    alert = rem?.let { r -> AlertRule(AlertMode.from(r.str("modeRaw") ?: "personalizado"), r.optInt("daysBefore", 3), r.optInt("atMinutes", 540)) } ?: AlertRule())
                    .let { r -> if (!r.active && ((r.totalCount != null && r.paidCount >= r.totalCount) || (r.endDate != null && r.nextDate.isAfter(r.endDate)))) r.copy(finished = true) else r }
            },
            entries = o.optJSONArray("entries").rows {
                EntryRecord(id = it.getString("id"), kind = kind(it.getString("kindRaw")), amountMinor = it.getLong("amountMinor"), occurredAt = day(it.getString("occurredAt")),
                    name = it.optString("name"), categoryId = it.str("categoryId"), productId = it.str("productId"), recurringId = it.str("recurringId"),
                    notes = it.str("notes"), source = it.str("sourceRaw").let { s -> if (s == "applePay") "sms" else s ?: "manual" }, merchant = it.str("merchant"))
            },
            transfers = o.optJSONArray("transfers").rows { TransferRecord(it.getString("id"), it.getString("fromProductId"), it.getString("toProductId"), it.getLong("amountMinor"), day(it.getString("occurredAt")), it.str("notes")) },
            budgets = o.optJSONArray("budgets").rows { BudgetRecord(it.getString("id"), it.str("categoryId"), it.getLong("monthlyLimitMinor")) },
            goals = o.optJSONArray("goals").rows { GoalRecord(it.getString("id"), it.getString("name"), it.getLong("targetAmountMinor"), it.str("targetDate")?.let(::day), it.str("productId")) },
            contributions = o.optJSONArray("contributions").rows { ContributionRecord(it.getString("id"), it.getString("goalId"), it.getLong("amountMinor"), day(it.getString("occurredAt"))) },
            rewards = o.optJSONArray("rewards").rows { RewardRecord(it.getString("id"), it.getString("name"), RewardKind.from(it.str("kindRaw")), it.optLong("balance"), it.dbl("valuePerPoint"), it.str("expiresAt")?.let(::day)) },
            merchantAliases = o.optJSONArray("merchantAliases").rows { MerchantAliasRule(it.getString("id"), it.getString("key"), it.getString("name"), it.str("categoryId")) },
            // Solo las propias (con espacio); las de la app ya están en Categories.all.
            categories = o.optJSONArray("categories").rows { c ->
                if (c.str("ownerSpaceId") == null) null else CategoryRecord(c.getString("id"), c.getString("name"), c.optString("icon", "square.grid.2x2"), c.optInt("sort", 50))
            },
        )
        val withDebts = ledger.copy(debts = DebtRows.alive(o.optJSONArray("debts")) { DebtRows.debtFrom(it) { t -> day(t) } },
            debtPayments = DebtRows.alive(o.optJSONArray("debtPayments")) { DebtRows.paymentFrom(it) { t -> day(t) } })
        return withDebts to currency
    }

    fun summary(l: Ledger) = "${l.entries.size} movimientos, ${l.recurring.size} pagos fijos y ${l.institutions.size} bancos"

    fun fileName(date: LocalDate, ext: String = "mprogress") = "MProgress-%04d-%02d-%02d.$ext".format(date.year, date.monthValue, date.dayOfMonth)

    /** Movimientos en CSV para Excel: fecha, tipo, nombre, categoría, monto con signo, moneda, pagado con y notas. */
    fun csv(l: Ledger, currency: Currency): String {
        fun esc(f: String) = if (f.any { it == ',' || it == '"' || it == '\n' }) "\"" + f.replace("\"", "\"\"") + "\"" else f
        fun plain(minor: Long): String {
            val sign = if (minor < 0) "-" else ""; val v = kotlin.math.abs(minor); val units = v / currency.minorPerUnit
            return if (currency.shownDigits == 0) "$sign$units" else "%s%d.%0${currency.minorDigits}d".format(sign, units, v % currency.minorPerUnit)
        }
        val lines = mutableListOf("Fecha,Tipo,Nombre,Categoría,Monto,Moneda,Pagado con,Notas")
        l.entries.sortedByDescending { it.occurredAt }.forEach { e ->
            lines += listOf(e.occurredAt.toString(), if (e.kind == EntryKind.INGRESO) "Ingreso" else "Gasto", e.name, Categories.byId(e.categoryId)?.name ?: "",
                plain(e.signedMinor), currency.code, l.product(e.productId)?.let { p -> p.name + (p.last4?.let { " $it" } ?: "") } ?: "", e.notes ?: "").joinToString(",") { esc(it) }
        }
        return lines.joinToString("\n") + "\n"
    }
}

/** Respaldo automático diario, cifrado con una llave guardada en el Android Keystore. Se guardan los últimos 7. */
object BackupService {
    const val KEY_LAST = "respaldo.ultimo"
    private const val ALIAS = "mprogress.respaldo"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        return gen.generateKey()
    }

    private fun folder(context: Context) = File(context.filesDir, "respaldos").apply { mkdirs() }

    /** Hace el respaldo de hoy si falta. */
    fun autoIfNeeded(context: Context, store: Store) {
        val last = store.prefs.getLong(KEY_LAST, 0)
        if (last > 0 && Instant.ofEpochMilli(last).atZone(ZoneId.systemDefault()).toLocalDate() == LocalDate.now()) return
        runCatching { backupNow(context, store) }
    }

    fun backupNow(context: Context, store: Store) {
        val plain = BackupCodec.encode(store.ledger.value, store.currency.value).toString().toByteArray()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val data = cipher.iv + cipher.doFinal(plain)
        File(folder(context), BackupCodec.fileName(LocalDate.now(), "mprogress.cifrado")).writeBytes(data)
        folder(context).listFiles()?.sortedByDescending { it.name }?.drop(7)?.forEach { it.delete() }
        store.prefs.edit().putLong(KEY_LAST, System.currentTimeMillis()).apply()
    }

    fun list(context: Context): List<File> = folder(context).listFiles()?.sortedByDescending { it.name } ?: emptyList()

    fun read(file: File): String {
        val bytes = file.readBytes()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12))) }
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)))
    }
}
