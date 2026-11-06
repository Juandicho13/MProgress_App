package com.olarte.mprogress.data

import android.content.Context
import android.content.SharedPreferences
import com.olarte.mprogress.domain.AddPlan
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.CycleAnchor
import com.olarte.mprogress.domain.CycleMath
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.EntryRecord
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.domain.QuickActionLayout
import com.olarte.mprogress.domain.RecurringRecord
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** Banco o billetera. Como en iOS: nunca se guardan números completos ni claves, solo los últimos 4. */
data class Institution(val id: String = UUID.randomUUID().toString(), val name: String)

data class Product(
    val id: String = UUID.randomUUID().toString(),
    val institutionId: String,
    val kind: ProductKind,
    val name: String,
    val last4: String? = null,
    val dueDay: Int? = null,
    /** Saldo de referencia en `balanceAt`. Crédito: lo que se debe. */
    val balanceMinor: Long = 0,
    val balanceAt: LocalDate = LocalDate.now(),
    val hidden: Boolean = false,
    val parentProductId: String? = null,
) {
    val record get() = com.olarte.mprogress.domain.ProductRecord(id, kind, balanceMinor, balanceAt, hidden, parentProductId)
}

data class Ledger(
    val institutions: List<Institution> = emptyList(),
    val products: List<Product> = emptyList(),
    val recurring: List<RecurringRecord> = emptyList(),
    val entries: List<EntryRecord> = emptyList(),
)

/**
 * Base local de Android. Fase A1: un archivo JSON privado de la app (sin dependencias extra).
 * Todo pasa por aquí, así cambiar a Room más adelante no toca las pantallas.
 */
class Store private constructor(private val file: File, val prefs: SharedPreferences) {
    private val _ledger = MutableStateFlow(load())
    val ledger: StateFlow<Ledger> = _ledger

    // Ajustes
    private val _theme = MutableStateFlow(prefs.getString(KEY_THEME, "oscuro") ?: "oscuro")
    val theme: StateFlow<String> = _theme
    private val _glass = MutableStateFlow(prefs.getString(KEY_GLASS, "normal") ?: "normal")
    val glass: StateFlow<String> = _glass
    private val _onboarded = MutableStateFlow(prefs.getBoolean(KEY_ONBOARDED, false))
    val onboarded: StateFlow<Boolean> = _onboarded
    private val _actions = MutableStateFlow(QuickActionLayout.parse(prefs.getString(QuickActionLayout.STORAGE_KEY, null)))
    val actions: StateFlow<QuickActionLayout> = _actions

    fun setTheme(v: String) { prefs.edit().putString(KEY_THEME, v).apply(); _theme.value = v }
    fun setGlass(v: String) { prefs.edit().putString(KEY_GLASS, v).apply(); _glass.value = v }
    fun setOnboarded(v: Boolean) { prefs.edit().putBoolean(KEY_ONBOARDED, v).apply(); _onboarded.value = v }
    fun setActions(v: QuickActionLayout) { prefs.edit().putString(QuickActionLayout.STORAGE_KEY, v.stored).apply(); _actions.value = v }

    private fun update(change: (Ledger) -> Ledger) {
        val next = change(_ledger.value)
        _ledger.value = next
        save(next)
    }

    /** Guarda lo de Agregar siguiendo AddPlan, igual que iOS. */
    fun add(kind: EntryKind, name: String, amountMinor: Long, cycle: Cycle, date: LocalDate, productId: String?, today: LocalDate = LocalDate.now()) {
        val plan = AddPlan.decide(cycle, date, today)
        update { l ->
            var recurring = l.recurring
            var recurringId: String? = null
            plan.recurringNext?.let { next ->
                val r = RecurringRecord(kind = kind, name = name, amountMinor = amountMinor, cycle = cycle, nextDate = next,
                    anchor = CycleAnchor.of(date), productId = productId)
                recurringId = r.id
                recurring = recurring + r
            }
            val entries = plan.entryDate?.let { l.entries + EntryRecord(kind = kind, amountMinor = amountMinor, occurredAt = it, name = name, productId = productId, recurringId = recurringId) } ?: l.entries
            l.copy(recurring = recurring, entries = entries)
        }
    }

    /** Marca pagado: crea el movimiento de hoy y mueve el fijo a la siguiente fecha (o lo cierra si es puntual). */
    fun markPaid(recurringId: String, today: LocalDate = LocalDate.now()) = update { l ->
        val r = l.recurring.firstOrNull { it.id == recurringId } ?: return@update l
        val entry = EntryRecord(kind = r.kind, amountMinor = r.amountMinor, occurredAt = today, name = r.name, productId = r.productId, recurringId = r.id)
        val next = CycleMath.next(r.nextDate, r.cycle, r.anchor)
        val updated = if (next == null) l.recurring.filter { it.id != r.id } else l.recurring.map { if (it.id == r.id) it.copy(nextDate = next) else it }
        l.copy(entries = l.entries + entry, recurring = updated)
    }

    fun addInstitution(name: String): String {
        val inst = Institution(name = name)
        update { it.copy(institutions = it.institutions + inst) }
        return inst.id
    }

    fun addProduct(institutionId: String, kind: ProductKind, name: String, last4: String?, balanceMinor: Long, dueDay: Int?) = update { l ->
        val parent = if (kind == ProductKind.DEBITO) l.products.firstOrNull { it.institutionId == institutionId && it.kind == ProductKind.CUENTA }?.id else null
        l.copy(products = l.products + Product(institutionId = institutionId, kind = kind, name = name, last4 = last4?.filter(Char::isDigit)?.takeLast(4)?.ifBlank { null },
            dueDay = dueDay, balanceMinor = balanceMinor, parentProductId = parent))
    }

    /** Ajusta el saldo a lo que dice el banco hoy. */
    fun setBalance(productId: String, balanceMinor: Long) = update { l ->
        l.copy(products = l.products.map { if (it.id == productId) it.copy(balanceMinor = balanceMinor, balanceAt = LocalDate.now().plusDays(1)) else it })
    }

    fun deleteProduct(id: String) = update { l -> l.copy(products = l.products.filter { it.id != id }) }

    fun deleteInstitution(id: String) = update { l ->
        l.copy(institutions = l.institutions.filter { it.id != id }, products = l.products.filter { it.institutionId != id })
    }

    fun deleteEntry(id: String) = update { l -> l.copy(entries = l.entries.filter { it.id != id }) }

    fun setRecurringDate(id: String, day: Int?, productId: String?, today: LocalDate = LocalDate.now()) = update { l ->
        l.copy(recurring = l.recurring.map { r ->
            if (r.id != id) r else {
                val withProduct = r.copy(productId = productId ?: r.productId)
                if (day == null) withProduct else {
                    var next = today.withDayOfMonth(minOf(day, today.lengthOfMonth()))
                    if (next.isBefore(today)) next = next.plusMonths(1).let { it.withDayOfMonth(minOf(day, it.lengthOfMonth())) }
                    withProduct.copy(nextDate = next, anchor = CycleAnchor(day, next.monthValue), dateUnset = false)
                }
            }
        })
    }

    /** Termina el onboarding: bancos, luego sueldo, luego fijos (con día o "más tarde"). */
    fun finishOnboarding(plan: OnboardingDraft, today: LocalDate = LocalDate.now()) {
        update { l ->
            val institutions = l.institutions.toMutableList()
            val products = l.products.toMutableList()
            for (bank in plan.banks) {
                val inst = Institution(name = bank.name)
                institutions += inst
                val account = bank.products.firstOrNull { it.kind == ProductKind.CUENTA }?.let { Product(institutionId = inst.id, kind = it.kind, name = it.name) }
                account?.let { products += it }
                bank.products.filter { it.kind != ProductKind.CUENTA }.forEach {
                    products += Product(institutionId = inst.id, kind = it.kind, name = it.name, last4 = it.last4?.takeLast(4),
                        parentProductId = if (it.kind == ProductKind.DEBITO) account?.id else null)
                }
            }
            val recurring = l.recurring.toMutableList()
            fun nextFor(day: Int): LocalDate {
                var n = today.withDayOfMonth(minOf(day, today.lengthOfMonth()))
                if (n.isBefore(today)) n = n.plusMonths(1).let { it.withDayOfMonth(minOf(day, it.lengthOfMonth())) }
                return n
            }
            if (plan.incomeMinor > 0) {
                val n = nextFor(plan.incomeDay)
                recurring += RecurringRecord(kind = EntryKind.INGRESO, name = "Sueldo", amountMinor = plan.incomeMinor, cycle = Cycle.Mensual,
                    nextDate = n, anchor = CycleAnchor(plan.incomeDay, n.monthValue), productId = plan.incomeProductIndex?.let { products.getOrNull(it)?.id })
            }
            for (f in plan.fixed) {
                val n = f.day?.let { nextFor(it) } ?: today
                recurring += RecurringRecord(kind = EntryKind.GASTO, name = f.name, amountMinor = f.amountMinor, cycle = Cycle.Mensual,
                    nextDate = n, anchor = CycleAnchor(f.day ?: n.dayOfMonth, n.monthValue), dateUnset = f.day == null,
                    productId = f.productIndex?.let { products.getOrNull(it)?.id })
            }
            l.copy(institutions = institutions, products = products, recurring = recurring)
        }
        setOnboarded(true)
    }

    /** Borrar cuenta y datos: deja la app como recién instalada. */
    fun eraseAll() {
        file.delete()
        prefs.edit().clear().apply()
        _ledger.value = Ledger()
        _theme.value = "oscuro"; _glass.value = "normal"
        _actions.value = QuickActionLayout.standard
        _onboarded.value = false
    }

    // ---------- JSON ----------

    private fun load(): Ledger = try {
        if (!file.exists()) Ledger() else decode(JSONObject(file.readText()))
    } catch (e: Exception) { Ledger() }

    private fun save(l: Ledger) {
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(encode(l).toString())
        tmp.renameTo(file)
    }

    private fun encode(l: Ledger) = JSONObject().apply {
        put("version", 1)
        put("institutions", JSONArray(l.institutions.map { JSONObject().put("id", it.id).put("name", it.name) }))
        put("products", JSONArray(l.products.map {
            JSONObject().put("id", it.id).put("institutionId", it.institutionId).put("kind", it.kind.name).put("name", it.name)
                .put("last4", it.last4 ?: JSONObject.NULL).put("dueDay", it.dueDay ?: JSONObject.NULL)
                .put("balanceMinor", it.balanceMinor).put("balanceAt", it.balanceAt.toString()).put("hidden", it.hidden)
                .put("parentProductId", it.parentProductId ?: JSONObject.NULL)
        }))
        put("recurring", JSONArray(l.recurring.map {
            JSONObject().put("id", it.id).put("kind", it.kind.name).put("name", it.name).put("amountMinor", it.amountMinor)
                .put("cycle", it.cycle.raw).put("intervalDays", it.cycle.intervalDays ?: JSONObject.NULL)
                .put("nextDate", it.nextDate.toString()).put("anchorDay", it.anchor.day).put("anchorMonth", it.anchor.month)
                .put("active", it.active).put("dateUnset", it.dateUnset).put("productId", it.productId ?: JSONObject.NULL)
        }))
        put("entries", JSONArray(l.entries.map {
            JSONObject().put("id", it.id).put("kind", it.kind.name).put("amountMinor", it.amountMinor).put("occurredAt", it.occurredAt.toString())
                .put("name", it.name).put("productId", it.productId ?: JSONObject.NULL).put("recurringId", it.recurringId ?: JSONObject.NULL)
        }))
    }

    private fun JSONObject.str(k: String): String? = if (isNull(k)) null else optString(k)
    private fun JSONObject.int(k: String): Int? = if (isNull(k) || !has(k)) null else optInt(k)
    private fun <T> JSONArray?.list(f: (JSONObject) -> T): List<T> = if (this == null) emptyList() else (0 until length()).map { f(getJSONObject(it)) }

    private fun decode(o: JSONObject) = Ledger(
        institutions = o.optJSONArray("institutions").list { Institution(it.getString("id"), it.getString("name")) },
        products = o.optJSONArray("products").list {
            Product(it.getString("id"), it.getString("institutionId"), ProductKind.valueOf(it.getString("kind")), it.getString("name"), it.str("last4"), it.int("dueDay"),
                it.optLong("balanceMinor", 0), it.str("balanceAt")?.let(LocalDate::parse) ?: LocalDate.now(), it.optBoolean("hidden", false), it.str("parentProductId"))
        },
        recurring = o.optJSONArray("recurring").list {
            RecurringRecord(id = it.getString("id"), kind = EntryKind.valueOf(it.getString("kind")), name = it.getString("name"),
                amountMinor = it.getLong("amountMinor"), cycle = Cycle.from(it.getString("cycle"), it.int("intervalDays")),
                nextDate = LocalDate.parse(it.getString("nextDate")), anchor = CycleAnchor(it.getInt("anchorDay"), it.getInt("anchorMonth")),
                active = it.optBoolean("active", true), dateUnset = it.optBoolean("dateUnset", false), productId = it.str("productId"))
        },
        entries = o.optJSONArray("entries").list {
            EntryRecord(id = it.getString("id"), kind = EntryKind.valueOf(it.getString("kind")), amountMinor = it.getLong("amountMinor"),
                occurredAt = LocalDate.parse(it.getString("occurredAt")), name = it.optString("name"),
                productId = it.str("productId"), recurringId = it.str("recurringId"))
        },
    )

    companion object {
        const val KEY_THEME = "apariencia.tema"
        const val KEY_GLASS = "apariencia.vidrio"
        const val KEY_ONBOARDED = "onboarding.hecho"
        @Volatile private var instance: Store? = null
        fun get(context: Context): Store = instance ?: synchronized(this) {
            instance ?: Store(File(context.filesDir, "mprogress.json"), context.getSharedPreferences("mprogress", Context.MODE_PRIVATE)).also { instance = it }
        }
    }
}

/** Lo que se arma en el onboarding antes de guardar. */
data class OnboardingDraft(
    val incomeMinor: Long = 0,
    val incomeDay: Int = 1,
    val incomeProductIndex: Int? = null,
    val banks: List<BankDraft> = emptyList(),
    val fixed: List<FixedDraft> = emptyList(),
) {
    /** Productos en el orden en que se crean, para elegir con qué se paga. */
    val allProducts: List<Pair<String, ProductDraft>> get() = banks.flatMap { b -> b.products.sortedBy { it.kind != ProductKind.CUENTA }.map { b.name to it } }
}

data class BankDraft(val name: String, val products: List<ProductDraft>)
data class ProductDraft(val kind: ProductKind, val name: String, val last4: String? = null)
data class FixedDraft(val name: String, val amountMinor: Long, val day: Int? = null, val productIndex: Int? = null)
