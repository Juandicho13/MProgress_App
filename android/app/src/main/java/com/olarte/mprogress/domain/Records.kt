package com.olarte.mprogress.domain

import java.time.LocalDate
import java.util.UUID

enum class EntryKind { GASTO, INGRESO;
    val sign: Long get() = if (this == INGRESO) 1 else -1
}

enum class ProductKind(val title: String) {
    CUENTA("Cuenta"), DEBITO("Tarjeta débito"), CREDITO("Tarjeta crédito"), BOLSILLO("Bolsillo o cajita"), EFECTIVO("Efectivo");
    val isDebt get() = this == CREDITO
}

data class EntryRecord(
    val id: String = UUID.randomUUID().toString(),
    val kind: EntryKind,
    val amountMinor: Long,
    val occurredAt: LocalDate,
    val name: String = "",
    val categoryId: String? = null,
    val productId: String? = null,
    val recurringId: String? = null,
) { val signedMinor get() = kind.sign * amountMinor }

data class RecurringRecord(
    val id: String = UUID.randomUUID().toString(),
    val kind: EntryKind,
    val name: String,
    val amountMinor: Long,
    val cycle: Cycle,
    val nextDate: LocalDate,
    val anchor: CycleAnchor = CycleAnchor.of(nextDate),
    val active: Boolean = true,
    val dateUnset: Boolean = false,
    val categoryId: String? = null,
    val productId: String? = null,
)

data class UpcomingCharge(val recurringId: String, val name: String, val kind: EntryKind, val amountMinor: Long,
                          val date: LocalDate, val urgency: Urgency, val daysLeft: Int)

data class MonthSummary(val expectedIncomeMinor: Long, val spentMinor: Long, val pendingFixedMinor: Long,
                        val remainingMinor: Long, val spentRatio: Double, val daysLeft: Int)
