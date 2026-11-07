package com.olarte.mprogress.data

import com.olarte.mprogress.domain.DebtDirection
import com.olarte.mprogress.domain.DebtMath
import com.olarte.mprogress.domain.DebtPaymentRecord
import com.olarte.mprogress.domain.DebtRecord
import com.olarte.mprogress.domain.TransferRecord
import java.time.LocalDate

// Quién te debe en la base de Android, como DebtStore de iOS. Si la persona dice por qué cuenta pasó la plata, se guarda
// una transferencia contra DebtMath.OUTSIDE_PRODUCT_ID (un producto que no existe): el saldo de esa cuenta queda bien sin
// contar como gasto ni ingreso del mes. Todo pasa por Store.update, así se guarda, se respalda y se sincroniza.

/** Lo que se borró con una deuda, para Deshacer. */
data class RemovedDebt(val debt: DebtRecord, val payments: List<DebtPaymentRecord>, val transfers: List<TransferRecord>)

/** La transferencia de una deuda o un abono: la crea, la ajusta o la quita si ya no hay cuenta. Devuelve los datos y su id. */
private fun linkTransfer(l: Ledger, transferId: String?, productId: String?, direction: DebtDirection, isPayment: Boolean,
                         amountMinor: Long, date: LocalDate, person: String): Pair<Ledger, String?> {
    if (productId == null || amountMinor <= 0) return l.copy(transfers = l.transfers.filter { it.id != transferId }) to null
    val (from, to) = DebtMath.transferEnds(productId, direction, isPayment)
    val note = DebtMath.transferNote(person, direction, isPayment)
    val existing = l.transfers.firstOrNull { it.id == transferId }
    val t = existing?.copy(fromProductId = from, toProductId = to, amountMinor = amountMinor, occurredAt = date, note = note)
        ?: TransferRecord(fromProductId = from, toProductId = to, amountMinor = amountMinor, occurredAt = date, note = note)
    val transfers = if (existing != null) l.transfers.map { if (it.id == t.id) t else it } else l.transfers + t
    return l.copy(transfers = transfers) to t.id
}

/** Crea o cambia una deuda. Con cuenta crea o ajusta su transferencia; sin cuenta la quita. */
fun Store.saveDebt(existing: DebtRecord?, person: String, direction: DebtDirection, amountMinor: Long, date: LocalDate,
                   dueDate: LocalDate?, note: String?, productId: String?): DebtRecord {
    require(amountMinor > 0) { "La deuda va siempre positiva" }
    val name = DebtMath.cleanName(person)
    var saved: DebtRecord? = null
    update { l0 ->
        val base = existing?.let { e -> l0.debts.firstOrNull { it.id == e.id } } ?: existing
        val (l1, transferId) = linkTransfer(l0, base?.transferId, productId, direction, false, amountMinor, date, name)
        val d = (base ?: DebtRecord(person = name, direction = direction, amountMinor = amountMinor, date = date)).copy(
            person = name, direction = direction, amountMinor = amountMinor, date = date, dueDate = dueDate,
            note = note?.trim()?.ifEmpty { null }, productId = productId, transferId = transferId)
        saved = d
        var l = l1.copy(debts = if (l1.debts.any { it.id == d.id }) l1.debts.map { if (it.id == d.id) d else it } else l1.debts + d)
        // Si cambió la dirección o el nombre, los abonos con cuenta mueven la plata al otro lado.
        if (base != null && (base.direction != direction || base.person != name)) {
            for (p in l.debtPayments.filter { it.debtId == d.id && it.productId != null }) {
                val (next, id) = linkTransfer(l, p.transferId, p.productId, direction, true, p.amountMinor, p.date, name)
                l = next.copy(debtPayments = next.debtPayments.map { if (it.id == p.id) it.copy(transferId = id) else it })
            }
        }
        l
    }
    return saved!!
}

/** Abono. No pasa de lo que falta; devuelve null si no queda nada por pagar. */
fun Store.addDebtPayment(debtId: String, amountMinor: Long, date: LocalDate, productId: String?): DebtPaymentRecord? {
    var created: DebtPaymentRecord? = null
    update { l ->
        val debt = l.debts.firstOrNull { it.id == debtId } ?: return@update l
        val amount = DebtMath.clampPayment(amountMinor, DebtMath.remaining(debt, l.debtPayments))
        if (amount <= 0) return@update l
        val (l1, transferId) = linkTransfer(l, null, productId, debt.direction, true, amount, date, debt.person)
        val p = DebtPaymentRecord(debtId = debt.id, amountMinor = amount, date = date, productId = productId, transferId = transferId)
        created = p
        l1.copy(debtPayments = l1.debtPayments + p)
    }
    return created
}

/** Salda lo que falta con un solo abono. */
fun Store.settleDebt(debtId: String, date: LocalDate = LocalDate.now(), productId: String?): DebtPaymentRecord? {
    val l = ledger.value
    val debt = l.debts.firstOrNull { it.id == debtId } ?: return null
    return addDebtPayment(debtId, DebtMath.remaining(debt, l.debtPayments), date, productId)
}

/** Borra un abono y su transferencia. */
fun Store.deleteDebtPayment(id: String) = update { l ->
    val p = l.debtPayments.firstOrNull { it.id == id } ?: return@update l
    l.copy(debtPayments = l.debtPayments.filter { it.id != id }, transfers = l.transfers.filter { it.id != p.transferId })
}

/** Borra la deuda con sus abonos y transferencias. Devuelve lo que se borró, para Deshacer. */
fun Store.deleteDebt(id: String): RemovedDebt? {
    var removed: RemovedDebt? = null
    update { l ->
        val d = l.debts.firstOrNull { it.id == id } ?: return@update l
        val payments = l.debtPayments.filter { it.debtId == id }
        val transferIds = (payments.mapNotNull { it.transferId } + listOfNotNull(d.transferId)).toSet()
        removed = RemovedDebt(d, payments, l.transfers.filter { it.id in transferIds })
        l.copy(debts = l.debts.filter { it.id != id }, debtPayments = l.debtPayments.filter { it.debtId != id },
            transfers = l.transfers.filter { it.id !in transferIds })
    }
    return removed
}

/** Deshacer el borrado: vuelve la deuda, sus abonos y sus transferencias con los mismos ids. */
fun Store.restoreDebt(r: RemovedDebt) = update { l ->
    if (l.debts.any { it.id == r.debt.id }) l
    else l.copy(debts = l.debts + r.debt, debtPayments = l.debtPayments + r.payments.filter { p -> l.debtPayments.none { it.id == p.id } },
        transfers = l.transfers + r.transfers.filter { t -> l.transfers.none { it.id == t.id } })
}
