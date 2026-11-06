import Foundation
import SwiftData

// Modelos locales (HANDOFF 8.1). Replican las tablas de Supabase.
// Reglas: todo con valor por defecto, sin relaciones obligatorias ni @Attribute(.unique),
// referencias por UUID, borrado suave con deletedAt y syncState para la sincronización (F10).

enum SyncState: String, Codable, Sendable {
    case local, pending, synced, failed
}

/// Lo que comparten todos los modelos que se sincronizan.
protocol SyncTracked: AnyObject {
    var id: UUID { get }
    var spaceId: UUID { get }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var syncStateRaw: String { get set }
}

extension SyncTracked {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    var isRemoved: Bool { deletedAt != nil }

    /// Marca un cambio: actualiza la fecha y lo deja pendiente de sincronizar.
    func touch(_ now: Date = .now) {
        updatedAt = now
        syncStateRaw = SyncState.pending.rawValue
    }
}

@Model
final class Space: SyncTracked {
    var id: UUID = UUID()
    var ownerId: UUID = UUID()
    var name: String = "Personal"
    var kindRaw: String = "personal"
    var currencyCode: String = "COP"
    var colorHex: String = "#ff6b2c"
    var icon: String?
    var shareTotalsOnly: Bool = false
    var defaultSplit: Int = 50
    var endsOn: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    /// Un espacio es su propio espacio.
    var spaceId: UUID { id }

    var currency: Currency { Currency.from(code: currencyCode) }

    init(id: UUID = UUID(), ownerId: UUID, name: String, kindRaw: String = "personal", currencyCode: String = "COP") {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.kindRaw = kindRaw
        self.currencyCode = currencyCode
    }
}

@Model
final class SpendCategory: SyncTracked {
    var id: UUID = UUID()
    /// Nil para las categorías globales de la app.
    var ownerSpaceId: UUID?
    var name: String = ""
    var icon: String = "square.grid.2x2"
    var colorHex: String?
    var sort: Int = 0
    var lastUsedAt: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    var spaceId: UUID { ownerSpaceId ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
    var isGlobal: Bool { ownerSpaceId == nil }

    init(id: UUID = UUID(), ownerSpaceId: UUID?, name: String, icon: String, sort: Int) {
        self.id = id
        self.ownerSpaceId = ownerSpaceId
        self.name = name
        self.icon = icon
        self.sort = sort
    }
}

@Model
final class Institution: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var name: String = ""
    var colorHex: String?
    var icon: String?
    var hidden: Bool = false
    var sort: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(id: UUID = UUID(), spaceId: UUID, name: String, colorHex: String? = nil) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class Product: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var institutionId: UUID = UUID()
    var parentProductId: UUID?
    var kindRaw: String = ProductKind.cuenta.rawValue
    var name: String = ""
    var last4: String?
    var balanceMinor: Int64 = 0
    var balanceAt: Date = Date.now
    var creditLimitMinor: Int64?
    var cutDay: Int?
    var dueDay: Int?
    var rateEA: Decimal?
    var lockedUntil: Date?
    var inWallet: Bool = false
    var hidden: Bool = false
    /// Programa de puntos o millas donde acumula esta tarjeta (PLAN_F12B).
    var rewardProgramId: UUID?
    /// Puntos por cada 1.000 de la moneda gastados con esta tarjeta.
    var pointsPerThousand: Decimal?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    var kind: ProductKind {
        get { ProductKind(rawValue: kindRaw) ?? .cuenta }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), spaceId: UUID, institutionId: UUID, kind: ProductKind, name: String) {
        self.id = id
        self.spaceId = spaceId
        self.institutionId = institutionId
        self.kindRaw = kind.rawValue
        self.name = name
    }

    var record: ProductRecord {
        ProductRecord(id: id, kind: kind, name: name, balanceMinor: balanceMinor, balanceAt: balanceAt, rateEA: rateEA, hidden: hidden,
                      parentProductId: parentProductId, dueDay: dueDay, rewardProgramId: rewardProgramId, pointsPerThousand: pointsPerThousand)
    }
}

@Model
final class Recurring: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var kindRaw: String = EntryKind.gasto.rawValue
    var name: String = ""
    var icon: String?
    var amountMinor: Int64 = 0
    var cycleRaw: String = "mensual"
    var intervalDays: Int?
    var nextDate: Date = Date.now
    var anchorDay: Int = 1
    var anchorMonth: Int = 1
    var categoryId: UUID?
    var productId: UUID?
    var responsibleId: UUID?
    var active: Bool = true
    /// Se creó sin fecha ("Más tarde" en el onboarding). No avisa ni sale en próximos hasta que tenga fecha.
    var dateUnset: Bool = false
    /// Último día con cobro, incluido (PLAN_F12B "Pagos con fin"). Nil: no termina por fecha.
    var endDate: Date?
    /// Número de cuotas. Nil: no termina por cuotas.
    var totalCount: Int?
    /// Cuotas pagadas: cada "marcar pagado" suma 1.
    var paidCount: Int = 0
    var createdBy: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .gasto }
        set { kindRaw = newValue.rawValue }
    }

    var cycle: Cycle {
        get { Cycle(rawValue: cycleRaw, intervalDays: intervalDays) }
        set {
            cycleRaw = newValue.rawValue
            intervalDays = newValue.intervalDays
        }
    }

    var anchor: CycleAnchor { CycleAnchor(day: anchorDay, month: anchorMonth) }

    var endChoice: RecurringEndChoice { RecurringEndChoice.of(endDate: endDate, totalCount: totalCount) }

    /// Ya no le quedan cobros: terminó sus cuotas o pasó su fecha final.
    func isFinished(calendar: Calendar = .current) -> Bool {
        RecurringEnd.isFinished(nextDate: nextDate, endDate: endDate, totalCount: totalCount, paidCount: paidCount, calendar: calendar)
    }

    /// "Cuota 3 de 12", "Hasta 15 mar 2027", "Terminado" o nil.
    func endText(calendar: Calendar = .current) -> String? {
        RecurringEnd.progressText(endDate: endDate, totalCount: totalCount, paidCount: paidCount,
                                  finished: isFinished(calendar: calendar), calendar: calendar)
    }

    init(id: UUID = UUID(), spaceId: UUID, kind: EntryKind, name: String, amountMinor: Int64, cycle: Cycle, nextDate: Date, calendar: Calendar = .current) {
        self.id = id
        self.spaceId = spaceId
        self.kindRaw = kind.rawValue
        self.name = name
        self.amountMinor = amountMinor
        self.cycleRaw = cycle.rawValue
        self.intervalDays = cycle.intervalDays
        self.nextDate = nextDate
        let anchor = CycleAnchor(date: nextDate, calendar: calendar)
        self.anchorDay = anchor.day
        self.anchorMonth = anchor.month
    }

    var record: RecurringRecord {
        RecurringRecord(id: id, kind: kind, name: name, amountMinor: amountMinor, cycle: cycle, nextDate: nextDate, anchor: anchor,
                        active: active && !dateUnset && deletedAt == nil, categoryId: categoryId, productId: productId,
                        endDate: endDate, totalCount: totalCount, paidCount: paidCount)
    }
}

@Model
final class Entry: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var kindRaw: String = EntryKind.gasto.rawValue
    var amountMinor: Int64 = 0
    var occurredAt: Date = Date.now
    var name: String = ""
    var merchant: String?
    var icon: String?
    var categoryId: UUID?
    var productId: UUID?
    var recurringId: UUID?
    var paidBy: UUID?
    var methodRaw: String?
    var sourceRaw: String = "manual"
    var needsReview: Bool = false
    var notes: String?
    var createdBy: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .gasto }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), spaceId: UUID, kind: EntryKind, amountMinor: Int64, occurredAt: Date, name: String) {
        self.id = id
        self.spaceId = spaceId
        self.kindRaw = kind.rawValue
        self.amountMinor = amountMinor
        self.occurredAt = occurredAt
        self.name = name
    }

    var record: EntryRecord {
        EntryRecord(id: id, kind: kind, amountMinor: amountMinor, occurredAt: occurredAt, name: name, categoryId: categoryId, productId: productId, recurringId: recurringId, paidBy: paidBy)
    }
}

@Model
final class Split: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var entryId: UUID = UUID()
    var userId: UUID = UUID()
    var amountMinor: Int64 = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(spaceId: UUID, entryId: UUID, userId: UUID, amountMinor: Int64) {
        self.spaceId = spaceId
        self.entryId = entryId
        self.userId = userId
        self.amountMinor = amountMinor
    }
}

@Model
final class Transfer: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var fromProductId: UUID = UUID()
    var toProductId: UUID = UUID()
    var amountMinor: Int64 = 0
    var occurredAt: Date = Date.now
    var notes: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(spaceId: UUID, fromProductId: UUID, toProductId: UUID, amountMinor: Int64, occurredAt: Date) {
        self.spaceId = spaceId
        self.fromProductId = fromProductId
        self.toProductId = toProductId
        self.amountMinor = amountMinor
        self.occurredAt = occurredAt
    }

    var record: TransferRecord {
        TransferRecord(id: id, fromProductId: fromProductId, toProductId: toProductId, amountMinor: amountMinor, occurredAt: occurredAt)
    }
}

@Model
final class Reminder: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var recurringId: UUID = UUID()
    var daysBefore: Int = 3
    var targetRaw: String = "todos"
    var userId: UUID?
    var atMinutes: Int = 540
    var notifyPartnerOnPaid: Bool = false
    /// Además de los días antes, avisar el mismo día del cobro.
    var sameDay: Bool = true
    /// "general", "personalizado" o "ninguno" (PLAN_F12B "Avisos en dos niveles"). Los avisos de antes eran personalizados.
    var modeRaw: String = ReminderMode.personalizado.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(spaceId: UUID, recurringId: UUID, daysBefore: Int = 3) {
        self.spaceId = spaceId
        self.recurringId = recurringId
        self.daysBefore = min(14, max(0, daysBefore))
    }

    var mode: ReminderMode {
        get { ReminderMode(rawValue: modeRaw) ?? .personalizado }
        set { modeRaw = newValue.rawValue }
    }

    var rule: ReminderRule {
        ReminderRule(recurringId: recurringId, daysBefore: daysBefore, atMinutes: atMinutes, sameDay: sameDay, mode: mode)
    }
}

@Model
final class Budget: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    /// Nil es el límite total del mes.
    var categoryId: UUID?
    var monthlyLimitMinor: Int64 = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(spaceId: UUID, categoryId: UUID?, monthlyLimitMinor: Int64) {
        self.spaceId = spaceId
        self.categoryId = categoryId
        self.monthlyLimitMinor = monthlyLimitMinor
    }

    var record: BudgetRecord {
        BudgetRecord(id: id, categoryId: categoryId, limitMinor: monthlyLimitMinor)
    }
}

@Model
final class SavingsGoal: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var name: String = ""
    var targetAmountMinor: Int64 = 0
    var targetDate: Date?
    var productId: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(spaceId: UUID, name: String, targetAmountMinor: Int64) {
        self.spaceId = spaceId
        self.name = name
        self.targetAmountMinor = targetAmountMinor
    }

    var record: GoalRecord {
        GoalRecord(id: id, name: name, targetMinor: targetAmountMinor, targetDate: targetDate, productId: productId)
    }
}

@Model
final class GoalContribution: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var goalId: UUID = UUID()
    var userId: UUID?
    var amountMinor: Int64 = 0
    var occurredAt: Date = Date.now
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(spaceId: UUID, goalId: UUID, userId: UUID?, amountMinor: Int64, occurredAt: Date) {
        self.spaceId = spaceId
        self.goalId = goalId
        self.userId = userId
        self.amountMinor = amountMinor
        self.occurredAt = occurredAt
    }
}

/// Programa de puntos o millas: Puntos Colombia, LifeMiles y otros. El saldo lo pone la persona.
@Model
final class RewardProgram: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var name: String = ""
    var kindRaw: String = RewardKind.puntos.rawValue
    var balance: Int64 = 0
    /// Lo que vale cada punto en la moneda del espacio, si la persona lo sabe.
    var valuePerPoint: Decimal?
    var expiresAt: Date?
    /// Tarjeta con la que se acumula, si alguna.
    var productId: UUID?
    var colorHex: String?
    var balanceAt: Date = Date.now
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    var kind: RewardKind {
        get { RewardKind(rawValue: kindRaw) ?? .puntos }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), spaceId: UUID, name: String, kind: RewardKind, balance: Int64) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.kindRaw = kind.rawValue
        self.balance = balance
    }

    var record: RewardRecord {
        RewardRecord(id: id, name: name, kind: kind, balance: balance, valuePerPoint: valuePerPoint, expiresAt: expiresAt)
    }
}
