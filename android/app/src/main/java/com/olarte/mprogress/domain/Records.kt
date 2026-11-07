package com.olarte.mprogress.domain

import java.time.LocalDate
import java.util.UUID

enum class EntryKind { GASTO, INGRESO;
    val sign: Long get() = if (this == INGRESO) 1 else -1
}

/** Bolsillo: plata apartada dentro de una cuenta (Nequi, Bancolombia). Cajita: ahorro aparte que suele rendir (Nu). */
enum class ProductKind(val title: String) {
    CUENTA("Cuenta"), DEBITO("Tarjeta débito"), CREDITO("Tarjeta crédito"), BOLSILLO("Bolsillo"), EFECTIVO("Efectivo"), CAJITA("Cajita");
    val isDebt get() = this == CREDITO
    /** Bolsillos y cajitas pueden tener tasa E.A. y rendimiento del mes. */
    val earnsYield get() = this == BOLSILLO || this == CAJITA
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
    val notes: String? = null,
    /** Hora opcional, en minutos desde la medianoche. */
    val atMinutes: Int? = null,
    /** manual, sms, notificacion, recibo. */
    val source: String = "manual",
    /** Puntos que sumó este gasto al programa de su tarjeta (se restan al borrarlo). */
    val pointsEarned: Long = 0,
    /** Comercio tal como llegó del banco o del recibo (registro automático), para aprender el nombre que le da la persona. */
    val merchant: String? = null,
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
    /** Paso 2: fecha final incluida; no hay cobros después. */
    val endDate: LocalDate? = null,
    /** Paso 2: número de cuotas y cuántas van pagadas. */
    val totalCount: Int? = null,
    val paidCount: Int = 0,
    /** Terminó por cuotas o por fecha final (no es lo mismo que pausado). */
    val finished: Boolean = false,
    val alert: AlertRule = AlertRule(),
) {
    /** Cobros que quedan por cuotas; null si no tiene cuotas. */
    val remainingCount: Int? get() = totalCount?.let { maxOf(0, it - paidCount) }
}

/** Aviso de un pago fijo: como el general, personalizado o sin aviso. */
enum class AlertMode(val raw: String, val title: String) {
    GENERAL("general", "Como el general"), PERSONALIZADO("personalizado", "Personalizado"), NINGUNO("ninguno", "Sin aviso");
    companion object { fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: GENERAL }
}

data class AlertRule(val mode: AlertMode = AlertMode.GENERAL, val daysBefore: Int = 3, val atMinutes: Int = 540)

data class TransferRecord(val id: String = UUID.randomUUID().toString(), val fromProductId: String, val toProductId: String,
                          val amountMinor: Long, val occurredAt: LocalDate, val note: String? = null)

data class CategoryRecord(val id: String, val name: String, val icon: String, val sort: Int)

/** Las mismas categorías de iOS (Data/Seed), con los mismos ids (en minúscula, como todos los ids de Android desde F10). */
object Categories {
    val all = listOf(
        CategoryRecord("0a000000-0000-4000-8000-000000000001", "Entretenimiento", "play.rectangle", 1),
        CategoryRecord("0a000000-0000-4000-8000-000000000002", "Música", "music.note", 2),
        CategoryRecord("0a000000-0000-4000-8000-000000000003", "Productividad", "briefcase", 3),
        CategoryRecord("0a000000-0000-4000-8000-000000000004", "Servicios", "wrench.and.screwdriver", 4),
        CategoryRecord("0a000000-0000-4000-8000-000000000005", "Renta", "house", 5),
        CategoryRecord("0a000000-0000-4000-8000-000000000006", "Mercado", "cart", 6),
        CategoryRecord("0a000000-0000-4000-8000-000000000007", "Transporte", "car", 7),
        CategoryRecord("0a000000-0000-4000-8000-000000000008", "Salidas", "fork.knife", 8),
        CategoryRecord("0a000000-0000-4000-8000-000000000009", "Deporte", "dumbbell", 9),
        CategoryRecord("0a000000-0000-4000-8000-000000000010", "Salud", "cross.case", 10),
        CategoryRecord("0a000000-0000-4000-8000-000000000011", "Educación", "graduationcap", 11),
        CategoryRecord("0a000000-0000-4000-8000-000000000012", "Social", "person.2", 12),
        CategoryRecord("0a000000-0000-4000-8000-000000000013", "Negocios", "building.2", 13),
        CategoryRecord("0a000000-0000-4000-8000-000000000014", "Finanzas", "banknote", 14),
        CategoryRecord("0a000000-0000-4000-8000-000000000099", "Otros", "square.grid.2x2", 99),
    )
    /** Categorías propias (las crea la persona en el selector). Las pone Store cada vez que cambia el ledger. */
    @Volatile var custom: List<CategoryRecord> = emptyList()
    /** Las que se pueden elegir: las de la app y las propias, por orden ("Otros" al final). */
    fun available(): List<CategoryRecord> = (all + custom).sortedBy { it.sort }
    /** Las de la app no se borran ni se cambian. */
    fun isBuiltIn(id: String?) = all.any { it.id.equals(id, ignoreCase = true) }
    fun byId(id: String?) = all.firstOrNull { it.id.equals(id, ignoreCase = true) } ?: custom.firstOrNull { it.id.equals(id, ignoreCase = true) }
    fun byName(name: String?) = all.firstOrNull { it.name == name }
}

data class UpcomingCharge(val recurringId: String, val name: String, val kind: EntryKind, val amountMinor: Long,
                          val date: LocalDate, val urgency: Urgency, val daysLeft: Int)

data class MonthSummary(val expectedIncomeMinor: Long, val spentMinor: Long, val pendingFixedMinor: Long,
                        val remainingMinor: Long, val spentRatio: Double, val daysLeft: Int)
