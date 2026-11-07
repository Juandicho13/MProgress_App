package com.olarte.mprogress.domain

import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

// Quién te debe: plata prestada entre la persona y otras personas (no es la división en pareja de F11).
// Todo es puro, igual que Domain/Debts.swift de iOS.

/** Hacia dónde va la deuda. `raw` es lo que viaja en la nube y en el respaldo. */
enum class DebtDirection(val raw: String, val title: String) {
    /** La otra persona me debe (yo le presté). */
    ME_DEBE("me_debe", "Me debe"),
    /** Yo le debo (ella me prestó). */
    LE_DEBO("le_debo", "Le debo");

    val sign: Long get() = if (this == ME_DEBE) 1 else -1

    companion object { fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: ME_DEBE }
}

/** Una deuda con una persona. El monto es el original; lo que falta sale de restarle los abonos. */
data class DebtRecord(
    val id: String = UUID.randomUUID().toString(),
    val person: String,
    val direction: DebtDirection,
    val amountMinor: Long,
    val date: LocalDate,
    val dueDate: LocalDate? = null,
    val note: String? = null,
    /** Cuenta o producto por donde pasó la plata, si la persona lo dijo. */
    val productId: String? = null,
    /** La transferencia que movió la plata en esa cuenta (contra DebtMath.OUTSIDE_PRODUCT_ID). */
    val transferId: String? = null,
)

/** Un abono a una deuda. */
data class DebtPaymentRecord(
    val id: String = UUID.randomUUID().toString(),
    val debtId: String,
    val amountMinor: Long,
    val date: LocalDate,
    val productId: String? = null,
    val transferId: String? = null,
)

enum class DebtStatus(val title: String) { PENDIENTE("Pendiente"), VENCIDA("Vencida"), SALDADA("Saldada") }

/** Lo que hay con una persona: cuánto te debe, cuánto le debes y el neto. */
data class PersonDebts(val key: String, val name: String, val owedToMeMinor: Long, val iOweMinor: Long, val openCount: Int) {
    /** Positivo: te debe. Negativo: le debes. */
    val netMinor: Long get() = owedToMeMinor - iOweMinor
}

data class DebtTotals(val owedToMeMinor: Long, val iOweMinor: Long)

object DebtMath {
    /** Producto que no existe: la otra punta de la transferencia que mueve la plata de una deuda (no suma en el patrimonio). */
    const val OUTSIDE_PRODUCT_ID = "0d000000-0000-4000-8000-0000000000de"

    /** "  ana   maría " → "ana maría". */
    fun cleanName(raw: String) = raw.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")

    /** Clave para juntar a la misma persona: minúsculas, sin tildes ni signos. */
    fun personKey(raw: String) = InitialUpload.normalizedName(raw)

    fun paid(debt: DebtRecord, payments: List<DebtPaymentRecord>) = payments.filter { it.debtId == debt.id }.sumOf { it.amountMinor }

    /** Lo que falta: el monto menos los abonos, nunca menos de cero. */
    fun remaining(debt: DebtRecord, payments: List<DebtPaymentRecord>) = maxOf(0L, debt.amountMinor - paid(debt, payments))

    fun status(debt: DebtRecord, payments: List<DebtPaymentRecord>, today: LocalDate): DebtStatus = when {
        remaining(debt, payments) == 0L -> DebtStatus.SALDADA
        debt.dueDate != null && debt.dueDate.isBefore(today) -> DebtStatus.VENCIDA
        else -> DebtStatus.PENDIENTE
    }

    /** Un abono no puede pasarse de lo que falta. */
    fun clampPayment(amountMinor: Long, remaining: Long) = amountMinor.coerceAtMost(remaining).coerceAtLeast(0)

    fun lastPaymentDate(debt: DebtRecord, payments: List<DebtPaymentRecord>) = payments.filter { it.debtId == debt.id }.maxOfOrNull { it.date }

    /** Las abiertas: la que vence primero arriba (sin fecha al final), luego la más nueva. */
    fun open(debts: List<DebtRecord>, payments: List<DebtPaymentRecord>) = debts.filter { remaining(it, payments) > 0 }
        .sortedWith(compareBy<DebtRecord>({ it.dueDate == null }, { it.dueDate }).thenByDescending { it.date })

    /** Las saldadas, la que se saldó más reciente arriba. */
    fun settled(debts: List<DebtRecord>, payments: List<DebtPaymentRecord>) = debts.filter { remaining(it, payments) == 0L }
        .sortedByDescending { lastPaymentDate(it, payments) ?: it.date }

    /** Una fila por persona con deudas abiertas, la de más plata arriba. */
    fun people(debts: List<DebtRecord>, payments: List<DebtPaymentRecord>): List<PersonDebts> {
        val byKey = linkedMapOf<String, PersonDebts>()
        val newest = mutableMapOf<String, LocalDate>()
        for (debt in debts) {
            val left = remaining(debt, payments)
            if (left <= 0) continue
            val key = personKey(debt.person)
            var p = byKey[key] ?: PersonDebts(key, cleanName(debt.person), 0, 0, 0)
            p = if (debt.direction == DebtDirection.ME_DEBE) p.copy(owedToMeMinor = p.owedToMeMinor + left) else p.copy(iOweMinor = p.iOweMinor + left)
            p = p.copy(openCount = p.openCount + 1)
            val last = newest[key]
            if (last == null || !debt.date.isBefore(last)) { newest[key] = debt.date; p = p.copy(name = cleanName(debt.person)) }
            byKey[key] = p
        }
        return byKey.values.sortedWith(compareByDescending<PersonDebts> { kotlin.math.abs(it.netMinor) }.thenBy { it.name.lowercase() })
    }

    /** Todas las deudas (abiertas y saldadas) de una persona. */
    fun debtsOf(key: String, debts: List<DebtRecord>) = debts.filter { personKey(it.person) == key }

    fun totals(debts: List<DebtRecord>, payments: List<DebtPaymentRecord>): DebtTotals {
        var owed = 0L; var owe = 0L
        for (d in debts) { val left = remaining(d, payments); if (d.direction == DebtDirection.ME_DEBE) owed += left else owe += left }
        return DebtTotals(owed, owe)
    }

    /** "Te deben $ 350.000 · Debes $ 80.000". Sin nada pendiente: "Nadie te debe y no debes nada". */
    fun summaryText(t: DebtTotals, currency: Currency): String {
        val parts = mutableListOf<String>()
        if (t.owedToMeMinor > 0) parts += "Te deben ${Money(t.owedToMeMinor, currency).formatted()}"
        if (t.iOweMinor > 0) parts += "Debes ${Money(t.iOweMinor, currency).formatted()}"
        return if (parts.isEmpty()) "Nadie te debe y no debes nada" else parts.joinToString(" · ")
    }

    /** "te debe", "le debes" o "a mano". */
    fun netLabel(p: PersonDebts) = when { p.netMinor > 0 -> "te debe"; p.netMinor < 0 -> "le debes"; else -> "a mano" }

    /** Nombres ya usados que empiezan (o tienen una palabra que empieza) por lo escrito, sin repetir. Vacío: los más recientes. */
    fun suggestions(typed: String, debts: List<DebtRecord>, limit: Int = 5): List<String> {
        val query = personKey(typed)
        val seen = mutableSetOf<String>()
        val out = mutableListOf<String>()
        for (d in debts.sortedByDescending { it.date }) {
            val key = personKey(d.person)
            if (key.isEmpty() || !seen.add(key)) continue
            if (query.isEmpty() || (key != query && (key.startsWith(query) || key.split(' ').any { it.startsWith(query) }))) out += cleanName(d.person)
            if (out.size == limit) break
        }
        return out
    }

    /** La plata sale de la cuenta al prestar (me debe) y al pagar lo que debo; entra al pedir prestado y al recibir un abono. */
    fun moneyLeaves(direction: DebtDirection, isPayment: Boolean) = (direction == DebtDirection.ME_DEBE) != isPayment

    /** Las dos puntas (desde, hacia) de la transferencia que mueve la plata en la cuenta elegida. */
    fun transferEnds(productId: String, direction: DebtDirection, isPayment: Boolean): Pair<String, String> =
        if (moneyLeaves(direction, isPayment)) productId to OUTSIDE_PRODUCT_ID else OUTSIDE_PRODUCT_ID to productId

    fun productQuestion(direction: DebtDirection, isPayment: Boolean) = if (moneyLeaves(direction, isPayment)) "¿De dónde salió la plata?" else "¿A dónde llegó?"

    /** "Préstamo a Ana", "Abono de Ana". */
    fun transferNote(person: String, direction: DebtDirection, isPayment: Boolean): String {
        val name = cleanName(person)
        return when {
            direction == DebtDirection.ME_DEBE && !isPayment -> "Préstamo a $name"
            direction == DebtDirection.LE_DEBO && !isPayment -> "Préstamo de $name"
            direction == DebtDirection.ME_DEBE -> "Abono de $name"
            else -> "Abono a $name"
        }
    }

    /** El día antes de la fecha límite a la hora de los avisos. Null si no tiene fecha, ya está saldada o la hora ya pasó. */
    fun reminderDate(debt: DebtRecord, payments: List<DebtPaymentRecord>, atMinutes: Int, now: LocalDateTime): LocalDateTime? {
        val due = debt.dueDate ?: return null
        if (remaining(debt, payments) <= 0) return null
        val m = atMinutes.coerceIn(0, 1439)
        val fire = due.minusDays(1).atTime(m / 60, m % 60)
        return if (fire.isAfter(now)) fire else null
    }

    /** Avisos del día antes de cada fecha límite. Ids "deuda.<id>". */
    fun reminders(debts: List<DebtRecord>, payments: List<DebtPaymentRecord>, atMinutes: Int, currency: Currency, now: LocalDateTime): List<PlannedNotification> =
        debts.mapNotNull { d ->
            val fire = reminderDate(d, payments, atMinutes, now) ?: return@mapNotNull null
            val amount = Money(remaining(d, payments), currency).formatted()
            val name = cleanName(d.person)
            val (title, body) = if (d.direction == DebtDirection.ME_DEBE) "Mañana $name te paga" to "Quedó de pagarte $amount. Si quieres, recuérdale desde Dinero."
                else "Mañana le pagas a $name" to "Le debes $amount. Si ya le pagaste, anota el abono en Dinero."
            PlannedNotification("deuda.${d.id.lowercase()}", fire, title, body)
        }.sortedBy { it.fireAt }

    /** Mensaje amable para recordarle a alguien lo que te debe. Se comparte con la hoja del sistema. */
    fun shareText(person: String, remainingMinor: Long, dueDate: LocalDate?, currency: Currency, today: LocalDate): String {
        val clean = cleanName(person)
        val name = clean.split(' ').firstOrNull()?.takeIf { it.isNotEmpty() } ?: clean
        val amount = Money(remainingMinor, currency).formatted()
        var text = "Hola $name, ¿cómo vas? Te escribo para recordarte los $amount que te presté."
        text += if (dueDate != null) {
            " Quedamos para el ${dueDate.dayOfMonth} de ${DueText.monthName(dueDate)}." +
                if (dueDate.isBefore(today)) " Cuando puedas me los pasas." else " Si puedes, me los pasas para esa fecha."
        } else " Cuando puedas me los pasas."
        return "$text Gracias."
    }

    /** Lo que le falta a la persona por pagarte y la fecha límite más cercana, para "Recordarle". */
    fun owedToMe(key: String, debts: List<DebtRecord>, payments: List<DebtPaymentRecord>): Pair<Long, LocalDate?> {
        val mine = debtsOf(key, debts).filter { it.direction == DebtDirection.ME_DEBE && remaining(it, payments) > 0 }
        return mine.sumOf { remaining(it, payments) } to mine.mapNotNull { it.dueDate }.minOrNull()
    }
}
