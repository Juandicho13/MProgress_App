package com.olarte.mprogress.domain

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import java.util.UUID
import kotlin.math.floor
import kotlin.math.pow

// MARK: Pagos con fin (Paso 2)

/** Reglas de pagos fijos con fecha final o cuotas. Mismos nombres que iOS (PLAN_F12B). */
object RecurringMath {
    /** Fechas de cobro desde `nextDate` hasta `through`, sin pasar `endDate` ni las cuotas que quedan. */
    fun occurrences(item: RecurringRecord, through: LocalDate, limit: Int = 400): List<LocalDate> {
        if (!item.active || item.dateUnset || item.finished) return emptyList()
        val last = item.endDate?.let { if (it.isBefore(through)) it else through } ?: through
        val max = minOf(limit, item.remainingCount ?: limit)
        if (max <= 0) return emptyList()
        return CycleMath.occurrences(item.nextDate, last, item.cycle, item.anchor, max)
    }

    /** Lo que queda después de marcar pagado: suma una cuota y mueve la fecha; termina si se acabaron las cuotas o pasa la fecha final. */
    fun afterPaid(item: RecurringRecord): RecurringRecord {
        val paid = item.paidCount + 1
        val next = CycleMath.next(item.nextDate, item.cycle, item.anchor)
        val doneByCount = item.totalCount != null && paid >= item.totalCount
        val doneByDate = next == null || (item.endDate != null && next.isAfter(item.endDate))
        return if (doneByCount || doneByDate) item.copy(paidCount = paid, active = false, finished = true)
        else item.copy(paidCount = paid, nextDate = next!!)
    }

    /** "Cuota 3 de 12" (la próxima es paidCount + 1) o "Hasta 15 mar 2027". */
    fun endText(item: RecurringRecord): String? = when {
        item.totalCount != null -> "Cuota ${minOf(item.paidCount + 1, item.totalCount)} de ${item.totalCount}"
        item.endDate != null -> "Hasta ${item.endDate.dayOfMonth} ${DueText.months[item.endDate.monthValue - 1]} ${item.endDate.year}"
        else -> null
    }
}

// MARK: Categorías

data class CategorySpend(val categoryId: String?, val totalMinor: Long)

object CategoryMath {
    /** Gasto por categoría, de mayor a menor. Nil es "Sin categoría". */
    fun spending(entries: List<EntryRecord>): List<CategorySpend> =
        entries.filter { it.kind == EntryKind.GASTO }.groupBy { it.categoryId }
            .map { (id, items) -> CategorySpend(id, items.sumOf { it.amountMinor }) }
            .sortedByDescending { it.totalMinor }
}

// MARK: Límites (F07-04)

data class BudgetRecord(val id: String = UUID.randomUUID().toString(), val categoryId: String? = null, val limitMinor: Long)

data class BudgetStatus(val budget: BudgetRecord, val spentMinor: Long) {
    val ratio: Double get() = if (budget.limitMinor > 0) spentMinor.toDouble() / budget.limitMinor else 0.0
    val remainingMinor: Long get() = budget.limitMinor - spentMinor
    val level: BudgetLevel get() = BudgetMath.level(ratio)
}

enum class BudgetLevel { BIEN, CERCA, SUPERADO }

object BudgetMath {
    const val NEAR = 0.8

    fun level(ratio: Double) = when { ratio >= 1 -> BudgetLevel.SUPERADO; ratio >= NEAR -> BudgetLevel.CERCA; else -> BudgetLevel.BIEN }

    fun statuses(budgets: List<BudgetRecord>, entries: List<EntryRecord>, today: LocalDate): List<BudgetStatus> {
        val month = YearMonth.from(today)
        val spent = entries.filter { it.kind == EntryKind.GASTO && YearMonth.from(it.occurredAt) == month }
        return budgets.map { b -> BudgetStatus(b, spent.filter { b.categoryId == null || it.categoryId == b.categoryId }.sumOf { it.amountMinor }) }
            .sortedWith(compareBy<BudgetStatus> { it.budget.categoryId != null }.thenByDescending { it.ratio })
    }

    fun dailyAllowance(remainingMinor: Long, today: LocalDate): Long {
        val days = maxOf(1, today.lengthOfMonth() - today.dayOfMonth + 1)
        return maxOf(0, remainingMinor) / days
    }

    /** Límites que un gasto nuevo hace cruzar al 80 % o al 100 %. */
    fun crossings(before: List<BudgetStatus>, after: List<BudgetStatus>): List<BudgetStatus> {
        val prev = before.associate { it.budget.id to it.level }
        return after.filter { it.level > BudgetLevel.BIEN && it.level > (prev[it.budget.id] ?: BudgetLevel.BIEN) }
    }
}

// MARK: Ahorro (F07-05)

data class GoalRecord(val id: String = UUID.randomUUID().toString(), val name: String, val targetMinor: Long,
                      val targetDate: LocalDate? = null, val productId: String? = null)

data class ContributionRecord(val id: String = UUID.randomUUID().toString(), val goalId: String, val amountMinor: Long, val occurredAt: LocalDate)

data class GoalProgress(val goal: GoalRecord, val savedMinor: Long, val monthlyNeededMinor: Long? = null) {
    val ratio: Double get() = if (goal.targetMinor > 0) minOf(1.0, savedMinor.toDouble() / goal.targetMinor) else 0.0
    val missingMinor: Long get() = maxOf(0, goal.targetMinor - savedMinor)
}

object SavingsMath {
    fun progress(goal: GoalRecord, contributions: List<ContributionRecord>, productBalance: Long?, today: LocalDate): GoalProgress {
        val saved = productBalance ?: contributions.filter { it.goalId == goal.id }.sumOf { it.amountMinor }
        val base = GoalProgress(goal, saved)
        val date = goal.targetDate ?: return base
        if (base.missingMinor <= 0) return base
        val months = monthsBetween(today, date)
        return base.copy(monthlyNeededMinor = if (months > 0) (base.missingMinor + months - 1) / months else base.missingMinor)
    }

    /** Meses que quedan contando el actual: de noviembre a junio son 8. */
    fun monthsBetween(from: LocalDate, to: LocalDate): Int =
        maxOf(0, (to.year - from.year) * 12 + (to.monthValue - from.monthValue) + 1)

    fun savedThisMonth(contributions: List<ContributionRecord>, today: LocalDate) =
        contributions.filter { YearMonth.from(it.occurredAt) == YearMonth.from(today) }.sumOf { it.amountMinor }
}

// MARK: Avisos (F07-02 y Paso 2)

/** Aviso general (Ajustes › Avisos). */
data class AlertSettings(val enabled: Boolean = true, val daysBefore: Int = 3, val atMinutes: Int = 540, val budgets: Boolean = true, val cards: Boolean = true)

data class PlannedNotification(val id: String, val fireAt: LocalDateTime, val title: String, val body: String)

object ReminderPlanner {
    const val MAX_PENDING = 60

    /** Regla efectiva de un pago fijo: la general, la propia o ninguna. */
    fun effective(rule: AlertRule, general: AlertSettings): Pair<Int, Int>? = when (rule.mode) {
        AlertMode.NINGUNO -> null
        AlertMode.PERSONALIZADO -> rule.daysBefore.coerceIn(0, 14) to rule.atMinutes
        AlertMode.GENERAL -> if (general.enabled) general.daysBefore.coerceIn(0, 14) to general.atMinutes else null
    }

    fun plan(recurring: List<RecurringRecord>, general: AlertSettings, currency: Currency, now: LocalDateTime, horizonDays: Int = 60,
             cards: List<Triple<String, String, Int>> = emptyList()): List<PlannedNotification> {
        val horizon = now.plusDays(horizonDays.toLong())
        val out = mutableListOf<PlannedNotification>()
        for (item in recurring) {
            val (days, minutes) = effective(item.alert, general) ?: continue
            for (due in RecurringMath.occurrences(item, horizon.toLocalDate().plusDays(days.toLong()), 30)) {
                val fire = due.minusDays(days.toLong()).atStartOfDay().plusMinutes(minutes.coerceIn(0, 1439).toLong())
                if (!fire.isAfter(now) || fire.isAfter(horizon)) continue
                out += PlannedNotification("mp.fijo.${item.id}.$due.$days", fire, item.name,
                    body(item.name, item.kind, Money(item.amountMinor, currency).formatted(), days))
            }
        }
        if (general.cards) for ((id, name, day) in cards) {
            var cursor = now.toLocalDate()
            repeat(3) {
                var due = cursor.withDayOfMonth(minOf(day, cursor.lengthOfMonth()))
                if (due.isBefore(cursor)) due = cursor.withDayOfMonth(1).plusMonths(1).let { it.withDayOfMonth(minOf(day, it.lengthOfMonth())) }
                val days = general.daysBefore.coerceIn(0, 14)
                val fire = due.minusDays(days.toLong()).atStartOfDay().plusMinutes(general.atMinutes.toLong())
                if (fire.isAfter(now) && !fire.isAfter(horizon)) out += PlannedNotification("mp.tarjeta.$id.$due", fire, "Pago de $name",
                    if (days == 0) "Hoy es el día de pago de tu tarjeta." else "Tu tarjeta se paga ${inDays(days)}.")
                cursor = due.plusDays(1)
            }
        }
        return out.sortedWith(compareBy({ it.fireAt }, { it.id })).take(MAX_PENDING)
    }

    fun body(name: String, kind: EntryKind, amount: String, days: Int): String {
        val verb = if (kind == EntryKind.INGRESO) "llega" else "vence"
        return "$name $verb ${inDays(days)} · $amount"
    }

    fun inDays(days: Int) = when (days) { 0 -> "hoy"; 1 -> "mañana"; else -> "en $days días" }

    /** "9:00 a. m." */
    fun timeText(minutes: Int): String {
        val hour = (minutes / 60) % 24; val minute = minutes % 60
        val twelve = if (hour % 12 == 0) 12 else hour % 12
        return "%d:%02d %s".format(twelve, minute, if (hour < 12) "a. m." else "p. m.")
    }
}

// MARK: Puntos y millas

enum class RewardKind(val raw: String, val title: String, val unit: String) {
    PUNTOS("puntos", "Puntos", "puntos"), MILLAS("millas", "Millas", "millas");
    companion object { fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: PUNTOS }
}

data class RewardRecord(val id: String = UUID.randomUUID().toString(), val name: String, val kind: RewardKind, val balance: Long,
                        val valuePerPoint: Double? = null, val expiresAt: LocalDate? = null)

object RewardMath {
    val suggestions = listOf(
        Triple("Puntos Colombia", RewardKind.PUNTOS, 0xFF6B2CL), Triple("LifeMiles", RewardKind.MILLAS, 0xED4C5CL), Triple("LATAM Pass", RewardKind.MILLAS, 0x4A90D9L),
        Triple("Puntos Davivienda", RewardKind.PUNTOS, 0xFF7A85L), Triple("Puntos BBVA", RewardKind.PUNTOS, 0x5B8DEFL), Triple("Otro", RewardKind.PUNTOS, 0x3A3F47L),
    )

    fun estimatedValueMinor(r: RewardRecord, currency: Currency): Long? {
        val v = r.valuePerPoint ?: return null
        if (v <= 0) return null
        return Math.round(r.balance * v * currency.minorPerUnit)
    }

    fun totalValueMinor(rewards: List<RewardRecord>, currency: Currency) = rewards.mapNotNull { estimatedValueMinor(it, currency) }.sum()

    fun expiryText(r: RewardRecord, today: LocalDate): String? {
        val date = r.expiresAt ?: return null
        val days = Urgency.days(today, date)
        return when { days < 0 -> "Vencieron"; days == 0 -> "Vencen hoy"; days <= 60 -> "Vencen en $days ${if (days == 1) "día" else "días"}"; else -> null }
    }

    fun balanceText(r: RewardRecord) = "${Money.groupThousands(r.balance)} ${r.kind.unit}"

    /** Paso 2: puntos de un gasto = floor(monto / 1000 × puntos por cada $ 1.000), en unidades de la moneda. */
    fun pointsFor(amountMinor: Long, pointsPerThousand: Double?, currency: Currency = Currency.COP): Long {
        val rate = pointsPerThousand ?: return 0
        if (rate <= 0 || amountMinor <= 0) return 0
        val units = amountMinor.toDouble() / currency.minorPerUnit
        return floor(units / 1000.0 * rate + 1e-9).toLong()
    }
}

/** Rendimiento aproximado de un mes para una cajita con tasa efectiva anual. */
fun monthlyYield(balanceMinor: Long, rateEA: Double?): Long {
    val rate = (rateEA ?: return 0) / 100
    if (rate <= 0 || balanceMinor <= 0) return 0
    return Math.round(balanceMinor * ((1 + rate).pow(1.0 / 12.0) - 1))
}
