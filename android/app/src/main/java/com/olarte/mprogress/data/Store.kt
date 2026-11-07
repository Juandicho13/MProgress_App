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
import com.olarte.mprogress.domain.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** Banco o billetera. Como en iOS: nunca se guardan números completos ni claves, solo los últimos 4. */
data class Institution(val id: String = UUID.randomUUID().toString(), val name: String, val colorHex: Long? = null, val hidden: Boolean = false)

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
    val creditLimitMinor: Long? = null,
    val cutDay: Int? = null,
    /** Tasa efectiva anual de una cajita, en %. */
    val rateEA: Double? = null,
    /** Paso 2: programa de puntos de la tarjeta y puntos por cada $ 1.000 gastados. */
    val rewardProgramId: String? = null,
    val pointsPerThousand: Double? = null,
) {
    val record get() = ProductRecord(id, kind, balanceMinor, balanceAt, hidden, parentProductId)
    val label get() = last4?.let { "$name ·· $it" } ?: name
}

/** Movimiento leído de una notificación o SMS que falta revisar (registro automático). */
data class PendingCapture(val id: String = UUID.randomUUID().toString(), val kind: EntryKind, val amountMinor: Long, val merchant: String?,
                          val last4: String?, val bank: String?, val source: String, val text: String, val receivedAt: LocalDate)

data class Ledger(
    val institutions: List<Institution> = emptyList(),
    val products: List<Product> = emptyList(),
    val recurring: List<RecurringRecord> = emptyList(),
    val entries: List<EntryRecord> = emptyList(),
    val transfers: List<TransferRecord> = emptyList(),
    val budgets: List<BudgetRecord> = emptyList(),
    val goals: List<GoalRecord> = emptyList(),
    val contributions: List<ContributionRecord> = emptyList(),
    val rewards: List<RewardRecord> = emptyList(),
    val captures: List<PendingCapture> = emptyList(),
) {
    val productRecords get() = products.map { it.record }
    fun balance(p: Product) = MoneyCalculator.currentBalance(p.record, productRecords, entries, transfers)
    fun product(id: String?) = products.firstOrNull { it.id == id }
    fun institution(p: Product) = institutions.firstOrNull { it.id == p.institutionId }
}

/** Mensaje con Deshacer, como UndoCenter de iOS. */
data class UndoMessage(val text: String, val id: Long = System.nanoTime(), val undo: (() -> Unit)? = null)

/**
 * Base local de Android: un archivo JSON privado de la app. Todo pasa por aquí, así cambiar a Room más adelante no toca las pantallas.
 */
class Store internal constructor(private val file: File, val prefs: SharedPreferences) {
    /** Diario de cambios para la nube (F10): fechas, pendientes y lápidas de cada registro. */
    val journal = SyncJournal(File(file.parentFile, "mprogress-sync.json"))
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
    private val _currency = MutableStateFlow(Currency.from(prefs.getString(KEY_CURRENCY, "COP") ?: "COP")).also { Currency.current = it.value }
    val currency: StateFlow<Currency> = _currency
    private val _alerts = MutableStateFlow(readAlerts())
    val alerts: StateFlow<AlertSettings> = _alerts
    private val _lock = MutableStateFlow(prefs.getBoolean(KEY_LOCK, false))
    val lock: StateFlow<Boolean> = _lock
    private val _undo = MutableStateFlow<UndoMessage?>(null)
    val undo: StateFlow<UndoMessage?> = _undo
    /** Inicio: ingresos fijos pequeños que la persona confirmó que están bien (en este dispositivo). */
    private val _checkedIncomes = MutableStateFlow(prefs.getStringSet(com.olarte.mprogress.domain.IncomeCheck.STORAGE_KEY, emptySet())?.toSet() ?: emptySet())
    val checkedIncomes: StateFlow<Set<String>> = _checkedIncomes
    /** Inicio: próximos cargos abiertos o cerrados (en este dispositivo). */
    private val _upcomingExpanded = MutableStateFlow(prefs.getBoolean(com.olarte.mprogress.domain.UpcomingFold.STORAGE_KEY, false))
    val upcomingExpanded: StateFlow<Boolean> = _upcomingExpanded

    /** Se llama después de cada cambio (reprogramar avisos, refrescar widgets). Lo pone la app. */
    var onChange: ((Ledger) -> Unit)? = null
    /** Se llama después de cada cambio hecho en el teléfono (no de los que bajan de la nube): programa la sincronización. */
    var onLocalChange: (() -> Unit)? = null

    fun setTheme(v: String) { prefs.edit().putString(KEY_THEME, v).apply(); _theme.value = v }
    fun setGlass(v: String) { prefs.edit().putString(KEY_GLASS, v).apply(); _glass.value = v }
    fun setOnboarded(v: Boolean) { prefs.edit().putBoolean(KEY_ONBOARDED, v).apply(); _onboarded.value = v }
    fun setActions(v: QuickActionLayout) { prefs.edit().putString(QuickActionLayout.STORAGE_KEY, v.stored).apply(); _actions.value = v }
    fun setCurrency(c: Currency) {
        val old = _currency.value
        prefs.edit().putString(KEY_CURRENCY, c.code).apply(); Currency.current = c; _currency.value = c
        journal.track(_ledger.value, old, _ledger.value, c)
        onChange?.invoke(_ledger.value)
        onLocalChange?.invoke()
    }
    fun setLock(v: Boolean) { prefs.edit().putBoolean(KEY_LOCK, v).apply(); _lock.value = v }
    fun markIncomeChecked(id: String) {
        val next = _checkedIncomes.value + id
        prefs.edit().putStringSet(com.olarte.mprogress.domain.IncomeCheck.STORAGE_KEY, next).apply(); _checkedIncomes.value = next
    }
    fun setUpcomingExpanded(v: Boolean) { prefs.edit().putBoolean(com.olarte.mprogress.domain.UpcomingFold.STORAGE_KEY, v).apply(); _upcomingExpanded.value = v }
    fun setAlerts(a: AlertSettings) {
        prefs.edit().putBoolean("avisos.activos", a.enabled).putInt("avisos.diasAntes", a.daysBefore).putInt("avisos.minutos", a.atMinutes)
            .putBoolean("avisos.limites", a.budgets).putBoolean("avisos.tarjetas", a.cards).apply()
        _alerts.value = a; onChange?.invoke(_ledger.value)
    }
    private fun readAlerts() = AlertSettings(prefs.getBoolean("avisos.activos", true), prefs.getInt("avisos.diasAntes", 3), prefs.getInt("avisos.minutos", 540), prefs.getBoolean("avisos.limites", true), prefs.getBoolean("avisos.tarjetas", true))

    fun showUndo(text: String, undo: (() -> Unit)? = null) { _undo.value = UndoMessage(text, undo = undo) }
    fun clearUndo() { _undo.value = null }

    private fun update(change: (Ledger) -> Ledger) {
        val old = _ledger.value
        val next = change(old)
        _ledger.value = next
        save(next)
        if (next !== old) runCatching { journal.track(old, _currency.value, next, _currency.value) }
        onChange?.invoke(next)
        onLocalChange?.invoke()
    }

    /** Reemplaza todo (restaurar respaldo). */
    fun replaceAll(l: Ledger) = update { SyncRows.canonical(l) }

    /** Lo que bajó de la nube: se guarda sin marcarlo pendiente (el diario lo actualiza quien sincroniza). */
    fun applyRemote(l: Ledger, currency: Currency?) {
        if (currency != null && currency != _currency.value) {
            prefs.edit().putString(KEY_CURRENCY, currency.code).apply(); Currency.current = currency; _currency.value = currency
        }
        _ledger.value = l
        save(l)
        onChange?.invoke(l)
    }

    // ---------- Movimientos ----------

    /** Puntos que suma un gasto con una tarjeta que tiene programa (Paso 2). */
    private fun pointsFor(l: Ledger, kind: EntryKind, amountMinor: Long, productId: String?): Long {
        if (kind != EntryKind.GASTO) return 0
        val p = l.product(productId) ?: return 0
        if (p.rewardProgramId == null || l.rewards.none { it.id == p.rewardProgramId }) return 0
        return RewardMath.pointsFor(amountMinor, p.pointsPerThousand, _currency.value)
    }

    private fun addPoints(l: Ledger, productId: String?, points: Long): Ledger {
        if (points == 0L) return l
        val programId = l.product(productId)?.rewardProgramId ?: return l
        return l.copy(rewards = l.rewards.map { if (it.id == programId) it.copy(balance = maxOf(0, it.balance + points)) else it })
    }

    /** Guarda lo de Agregar siguiendo AddPlan, igual que iOS. Devuelve el movimiento creado, si hubo. */
    fun add(kind: EntryKind, name: String, amountMinor: Long, cycle: Cycle, date: LocalDate, productId: String?, today: LocalDate = LocalDate.now(),
            categoryId: String? = null, notes: String? = null, atMinutes: Int? = null, source: String = "manual",
            endDate: LocalDate? = null, totalCount: Int? = null, alert: AlertRule = AlertRule()): EntryRecord? {
        val plan = AddPlan.decide(cycle, date, today)
        var created: EntryRecord? = null
        update { l ->
            var recurring = l.recurring
            var recurringId: String? = null
            plan.recurringNext?.let { next ->
                // Si el primer cobro ya se registró hoy, cuenta como la primera cuota.
                val paid = if (plan.entryDate != null && totalCount != null) 1 else 0
                var r = RecurringRecord(kind = kind, name = name, amountMinor = amountMinor, cycle = cycle, nextDate = next,
                    anchor = CycleAnchor.of(date), productId = productId, categoryId = categoryId, endDate = endDate, totalCount = totalCount, paidCount = paid, alert = alert)
                if ((totalCount != null && paid >= totalCount) || (endDate != null && next.isAfter(endDate))) r = r.copy(active = false, finished = true)
                recurringId = r.id
                recurring = recurring + r
            }
            var out = l.copy(recurring = recurring)
            plan.entryDate?.let {
                val points = pointsFor(l, kind, amountMinor, productId)
                val e = EntryRecord(kind = kind, amountMinor = amountMinor, occurredAt = it, name = name, productId = productId, recurringId = recurringId,
                    categoryId = categoryId, notes = notes?.ifBlank { null }, atMinutes = atMinutes, source = source, pointsEarned = points)
                created = e
                out = addPoints(out.copy(entries = out.entries + e), productId, points)
            }
            out
        }
        return created
    }

    /** Editar un movimiento ya guardado. */
    fun updateEntry(e: EntryRecord) = update { l ->
        val old = l.entries.firstOrNull { it.id == e.id } ?: return@update l
        var out = addPoints(l, old.productId, -old.pointsEarned)
        val points = pointsFor(out, e.kind, e.amountMinor, e.productId)
        out = out.copy(entries = out.entries.map { if (it.id == e.id) e.copy(pointsEarned = points) else it })
        addPoints(out, e.productId, points)
    }

    fun deleteEntry(id: String) = update { l ->
        val e = l.entries.firstOrNull { it.id == id } ?: return@update l
        addPoints(l.copy(entries = l.entries.filter { it.id != id }), e.productId, -e.pointsEarned)
    }

    fun restoreEntry(e: EntryRecord) = update { l -> addPoints(l.copy(entries = l.entries + e), e.productId, e.pointsEarned) }

    /** Duplicar hoy: mismo monto, nombre, categoría y producto. */
    fun duplicate(e: EntryRecord, today: LocalDate = LocalDate.now()): EntryRecord {
        val points = pointsFor(_ledger.value, e.kind, e.amountMinor, e.productId)
        val copy = e.copy(id = UUID.randomUUID().toString(), occurredAt = today, recurringId = null, source = "manual", pointsEarned = points)
        update { l -> addPoints(l.copy(entries = l.entries + copy), copy.productId, points) }
        return copy
    }

    // ---------- Pagos fijos ----------

    /** Marca pagado: crea el movimiento de hoy, suma una cuota y mueve el fijo. Devuelve el movimiento y si terminó. */
    fun markPaid(recurringId: String, today: LocalDate = LocalDate.now()): Pair<EntryRecord, Boolean>? {
        var result: Pair<EntryRecord, Boolean>? = null
        update { l ->
            val r = l.recurring.firstOrNull { it.id == recurringId } ?: return@update l
            val points = pointsFor(l, r.kind, r.amountMinor, r.productId)
            val entry = EntryRecord(kind = r.kind, amountMinor = r.amountMinor, occurredAt = today, name = r.name, productId = r.productId,
                recurringId = r.id, categoryId = r.categoryId, pointsEarned = points)
            val updated = if (r.cycle == Cycle.Puntual) null else RecurringMath.afterPaid(r)
            result = entry to (updated?.finished == true)
            val recurring = if (updated == null) l.recurring.filter { it.id != r.id } else l.recurring.map { if (it.id == r.id) updated else it }
            addPoints(l.copy(entries = l.entries + entry, recurring = recurring), r.productId, points)
        }
        return result
    }

    /** Deshacer marcar pagado: borra el movimiento y deja el fijo como estaba. */
    fun undoPaid(previous: RecurringRecord, entry: EntryRecord) = update { l ->
        val recurring = if (l.recurring.any { it.id == previous.id }) l.recurring.map { if (it.id == previous.id) previous else it } else l.recurring + previous
        addPoints(l.copy(entries = l.entries.filter { it.id != entry.id }, recurring = recurring), entry.productId, -entry.pointsEarned)
    }

    fun updateRecurring(r: RecurringRecord) = update { l -> l.copy(recurring = l.recurring.map { if (it.id == r.id) r else it }) }
    /** Cambia solo el monto de un pago fijo (arreglo rápido del sueldo en Inicio); pasa por update, así se sincroniza. */
    fun setRecurringAmount(id: String, amountMinor: Long) {
        require(amountMinor > 0) { "El monto va siempre positivo" }
        update { l -> l.copy(recurring = l.recurring.map { if (it.id == id) it.copy(amountMinor = amountMinor) else it }) }
    }
    fun deleteRecurring(id: String) = update { l -> l.copy(recurring = l.recurring.filter { it.id != id }) }
    fun restoreRecurring(r: RecurringRecord) = update { l -> l.copy(recurring = l.recurring + r) }

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

    // ---------- Bancos y productos ----------

    fun addInstitution(name: String, colorHex: Long? = null): String {
        val inst = Institution(name = name, colorHex = colorHex)
        update { it.copy(institutions = it.institutions + inst) }
        return inst.id
    }

    fun addProduct(institutionId: String, kind: ProductKind, name: String, last4: String?, balanceMinor: Long, dueDay: Int?): String {
        val p = Product(institutionId = institutionId, kind = kind, name = name, last4 = cleanLast4(last4), dueDay = dueDay, balanceMinor = balanceMinor)
        saveProduct(p)
        return p.id
    }

    /** Crea o edita un producto completo. Un débito nuevo sin cuenta queda ligado a la cuenta del banco. */
    fun saveProduct(p: Product) = update { l ->
        val clean = p.copy(last4 = cleanLast4(p.last4))
        if (l.products.any { it.id == p.id }) l.copy(products = l.products.map { if (it.id == p.id) clean else it })
        else {
            val parent = if (p.kind == ProductKind.DEBITO && p.parentProductId == null) l.products.firstOrNull { it.institutionId == p.institutionId && it.kind == ProductKind.CUENTA }?.id else p.parentProductId
            l.copy(products = l.products + clean.copy(parentProductId = parent))
        }
    }

    /** Ajusta el saldo a lo que dice el banco hoy. */
    fun setBalance(productId: String, balanceMinor: Long) = update { l ->
        l.copy(products = l.products.map { if (it.id == productId) it.copy(balanceMinor = balanceMinor, balanceAt = LocalDate.now().plusDays(1)) else it })
    }

    /** Edita nombre, últimos 4, día de pago y, si cambió, el saldo de hoy. */
    fun updateProduct(id: String, name: String, last4: String?, dueDay: Int?, balanceMinor: Long?) = update { l ->
        l.copy(products = l.products.map { p ->
            if (p.id != id) p else p.copy(name = name, last4 = cleanLast4(last4), dueDay = dueDay).let {
                if (balanceMinor != null) it.copy(balanceMinor = balanceMinor, balanceAt = LocalDate.now().plusDays(1)) else it
            }
        })
    }

    fun renameInstitution(id: String, name: String) = update { l -> l.copy(institutions = l.institutions.map { if (it.id == id) it.copy(name = name) else it }) }
    fun setInstitutionHidden(id: String, hidden: Boolean) = update { l -> l.copy(institutions = l.institutions.map { if (it.id == id) it.copy(hidden = hidden) else it }) }

    /** Los movimientos que se pagaron con esto se quedan, sin producto. */
    fun deleteProduct(id: String) = update { l ->
        l.copy(products = l.products.filter { it.id != id }, entries = l.entries.map { if (it.productId == id) it.copy(productId = null) else it },
            recurring = l.recurring.map { if (it.productId == id) it.copy(productId = null) else it })
    }

    fun deleteInstitution(id: String) = update { l ->
        val ids = l.products.filter { it.institutionId == id }.map { it.id }.toSet()
        l.copy(institutions = l.institutions.filter { it.id != id }, products = l.products.filter { it.institutionId != id },
            entries = l.entries.map { if (it.productId in ids) it.copy(productId = null) else it })
    }

    // ---------- Transferencias ----------

    fun addTransfer(t: TransferRecord) = update { l -> l.copy(transfers = l.transfers + t) }
    fun deleteTransfer(id: String) = update { l -> l.copy(transfers = l.transfers.filter { it.id != id }) }

    // ---------- Límites y ahorro ----------

    fun saveBudget(b: BudgetRecord) = update { l ->
        val rest = l.budgets.filter { it.id != b.id && it.categoryId != b.categoryId }
        l.copy(budgets = rest + b)
    }
    fun deleteBudget(id: String) = update { l -> l.copy(budgets = l.budgets.filter { it.id != id }) }

    fun saveGoal(g: GoalRecord) = update { l -> l.copy(goals = if (l.goals.any { it.id == g.id }) l.goals.map { if (it.id == g.id) g else it } else l.goals + g) }
    fun deleteGoal(id: String) = update { l -> l.copy(goals = l.goals.filter { it.id != id }, contributions = l.contributions.filter { it.goalId != id }) }
    fun addContribution(c: ContributionRecord) = update { l -> l.copy(contributions = l.contributions + c) }

    // ---------- Puntos y millas ----------

    fun saveReward(r: RewardRecord) = update { l -> l.copy(rewards = if (l.rewards.any { it.id == r.id }) l.rewards.map { if (it.id == r.id) r else it } else l.rewards + r) }
    fun deleteReward(id: String) = update { l ->
        l.copy(rewards = l.rewards.filter { it.id != id }, products = l.products.map { if (it.rewardProgramId == id) it.copy(rewardProgramId = null) else it })
    }

    // ---------- Registro automático ----------

    fun addCapture(c: PendingCapture) = update { l -> l.copy(captures = l.captures + c) }
    fun removeCapture(id: String) = update { l -> l.copy(captures = l.captures.filter { it.id != id }) }

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
                    nextDate = n, anchor = CycleAnchor(plan.incomeDay, n.monthValue), productId = plan.incomeProductIndex?.let { products.getOrNull(it)?.id },
                    categoryId = Categories.byName("Finanzas")?.id)
            }
            for (f in plan.fixed) {
                val n = f.day?.let { nextFor(it) } ?: today
                recurring += RecurringRecord(kind = EntryKind.GASTO, name = f.name, amountMinor = f.amountMinor, cycle = Cycle.Mensual,
                    nextDate = n, anchor = CycleAnchor(f.day ?: n.dayOfMonth, n.monthValue), dateUnset = f.day == null,
                    productId = f.productIndex?.let { products.getOrNull(it)?.id }, categoryId = Categories.byName(fixedCategory[f.name])?.id)
            }
            l.copy(institutions = institutions, products = products, recurring = recurring)
        }
        prefs.edit().putStringSet("onboarding.intereses", plan.interests.toSet()).apply()
        setOnboarded(true)
    }

    /** Borrar cuenta y datos: deja la app como recién instalada. */
    fun eraseAll() {
        file.delete()
        journal.clear()
        prefs.edit().clear().apply()
        _ledger.value = Ledger()
        onChange?.invoke(Ledger())
        _theme.value = "oscuro"; _glass.value = "normal"; _lock.value = false; _alerts.value = AlertSettings()
        _currency.value = Currency.COP; Currency.current = Currency.COP
        _actions.value = QuickActionLayout.standard
        _onboarded.value = false
        _checkedIncomes.value = emptySet(); _upcomingExpanded.value = false
    }

    // ---------- JSON ----------

    private fun load(): Ledger = try {
        if (!file.exists()) Ledger() else SyncRows.canonical(LedgerJson.decode(JSONObject(file.readText())))
    } catch (e: Exception) { Ledger() }

    private fun save(l: Ledger) {
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(encode(l).toString())
        tmp.renameTo(file)
    }

    fun encode(l: Ledger): JSONObject = LedgerJson.encode(l)

    companion object {
        const val KEY_THEME = "apariencia.tema"
        const val KEY_GLASS = "apariencia.vidrio"
        const val KEY_ONBOARDED = "onboarding.hecho"
        const val KEY_CURRENCY = "espacio.moneda"
        const val KEY_LOCK = "seguridad.bloqueo"
        /** Categoría de cada fijo sugerido del onboarding, como FixedSuggestion de iOS. */
        val fixedCategory = mapOf("Renta" to "Renta", "Streaming" to "Entretenimiento", "Música" to "Música", "Nube" to "Productividad",
            "Gimnasio" to "Deporte", "Suscripción IA" to "Productividad")
        fun cleanLast4(v: String?) = v?.filter(Char::isDigit)?.takeLast(4)?.takeIf { it.length == 4 }
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
    /** Intereses elegidos en el onboarding (se guardan como en iOS, en onboarding.intereses). */
    val interests: List<String> = emptyList(),
) {
    /** Productos en el orden en que se crean, para elegir con qué se paga. */
    val allProducts: List<Pair<String, ProductDraft>> get() = banks.flatMap { b -> b.products.sortedBy { it.kind != ProductKind.CUENTA }.map { b.name to it } }
}

data class BankDraft(val name: String, val products: List<ProductDraft>)
data class ProductDraft(val kind: ProductKind, val name: String, val last4: String? = null)
data class FixedDraft(val name: String, val amountMinor: Long, val day: Int? = null, val productIndex: Int? = null)
