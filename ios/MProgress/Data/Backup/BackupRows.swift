import Foundation
import SwiftData

/// Cada modelo de SwiftData en su fila del respaldo y de vuelta. Lo usan el respaldo (BackupService) y la
/// sincronización cifrada (F10): el JSON de un sobre es exactamente la fila del respaldo.
/// `fill` copia todo lo de la fila (fechas incluidas) menos `syncStateRaw`, que decide quien llama.
@MainActor
enum BackupRows {
    typealias S = BackupSnapshot

    // MARK: Espacios

    static func row(_ m: Space) -> S.SpaceRow {
        .init(id: m.id, ownerId: m.ownerId, name: m.name, kindRaw: m.kindRaw, currencyCode: m.currencyCode, colorHex: m.colorHex,
              icon: m.icon, shareTotalsOnly: m.shareTotalsOnly, defaultSplit: m.defaultSplit, endsOn: m.endsOn,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.SpaceRow) -> Space {
        let m = Space(id: r.id, ownerId: r.ownerId, name: r.name, kindRaw: r.kindRaw, currencyCode: r.currencyCode)
        fill(m, r)
        return m
    }

    static func fill(_ m: Space, _ r: S.SpaceRow) {
        m.id = r.id
        m.ownerId = r.ownerId
        m.name = r.name
        m.kindRaw = r.kindRaw
        m.currencyCode = r.currencyCode
        m.colorHex = r.colorHex
        m.icon = r.icon
        m.shareTotalsOnly = r.shareTotalsOnly
        m.defaultSplit = r.defaultSplit
        m.endsOn = r.endsOn
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Categorías

    static func row(_ m: SpendCategory) -> S.CategoryRow {
        .init(id: m.id, ownerSpaceId: m.ownerSpaceId, name: m.name, icon: m.icon, colorHex: m.colorHex, sort: m.sort,
              lastUsedAt: m.lastUsedAt, createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.CategoryRow) -> SpendCategory {
        let m = SpendCategory(id: r.id, ownerSpaceId: r.ownerSpaceId, name: r.name, icon: r.icon, sort: r.sort)
        fill(m, r)
        return m
    }

    static func fill(_ m: SpendCategory, _ r: S.CategoryRow) {
        m.id = r.id
        m.ownerSpaceId = r.ownerSpaceId
        m.name = r.name
        m.icon = r.icon
        m.colorHex = r.colorHex
        m.sort = r.sort
        m.lastUsedAt = r.lastUsedAt
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Bancos

    static func row(_ m: Institution) -> S.InstitutionRow {
        .init(id: m.id, spaceId: m.spaceId, name: m.name, colorHex: m.colorHex, icon: m.icon, hidden: m.hidden, sort: m.sort,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.InstitutionRow) -> Institution {
        let m = Institution(id: r.id, spaceId: r.spaceId, name: r.name, colorHex: r.colorHex)
        fill(m, r)
        return m
    }

    static func fill(_ m: Institution, _ r: S.InstitutionRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.name = r.name
        m.colorHex = r.colorHex
        m.icon = r.icon
        m.hidden = r.hidden
        m.sort = r.sort
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Productos

    static func row(_ m: Product) -> S.ProductRow {
        .init(id: m.id, spaceId: m.spaceId, institutionId: m.institutionId, parentProductId: m.parentProductId, kindRaw: m.kindRaw,
              name: m.name, last4: m.last4, balanceMinor: m.balanceMinor, balanceAt: m.balanceAt, creditLimitMinor: m.creditLimitMinor,
              cutDay: m.cutDay, dueDay: m.dueDay, rateEA: m.rateEA, lockedUntil: m.lockedUntil, inWallet: m.inWallet, hidden: m.hidden,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt,
              rewardProgramId: m.rewardProgramId, pointsPerThousand: m.pointsPerThousand)
    }

    static func make(_ r: S.ProductRow) -> Product {
        let m = Product(id: r.id, spaceId: r.spaceId, institutionId: r.institutionId, kind: ProductKind(rawValue: r.kindRaw) ?? .cuenta, name: r.name)
        fill(m, r)
        return m
    }

    static func fill(_ m: Product, _ r: S.ProductRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.institutionId = r.institutionId
        m.parentProductId = r.parentProductId
        m.kindRaw = r.kindRaw
        m.name = r.name
        // Nunca el número completo: solo 4 dígitos válidos.
        m.last4 = MoneyStore.cleanLast4(r.last4)
        m.balanceMinor = r.balanceMinor
        m.balanceAt = r.balanceAt
        m.creditLimitMinor = r.creditLimitMinor
        m.cutDay = r.cutDay
        m.dueDay = r.dueDay
        m.rateEA = r.rateEA
        m.lockedUntil = r.lockedUntil
        m.inWallet = r.inWallet
        m.hidden = r.hidden
        m.rewardProgramId = r.rewardProgramId
        m.pointsPerThousand = r.pointsPerThousand
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Pagos fijos

    static func row(_ m: Recurring) -> S.RecurringRow {
        .init(id: m.id, spaceId: m.spaceId, kindRaw: m.kindRaw, name: m.name, icon: m.icon, amountMinor: m.amountMinor,
              cycleRaw: m.cycleRaw, intervalDays: m.intervalDays, nextDate: m.nextDate, anchorDay: m.anchorDay, anchorMonth: m.anchorMonth,
              categoryId: m.categoryId, productId: m.productId, responsibleId: m.responsibleId, active: m.active, createdBy: m.createdBy,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt, dateUnset: m.dateUnset,
              endDate: m.endDate, totalCount: m.totalCount, paidCount: m.paidCount, intervalMonths: m.intervalMonths)
    }

    static func make(_ r: S.RecurringRow) -> Recurring {
        let m = Recurring(id: r.id, spaceId: r.spaceId, kind: EntryKind(rawValue: r.kindRaw) ?? .gasto, name: r.name, amountMinor: r.amountMinor,
                          cycle: Cycle(rawValue: r.cycleRaw, intervalDays: r.intervalDays, intervalMonths: r.intervalMonths), nextDate: r.nextDate)
        fill(m, r)
        return m
    }

    static func fill(_ m: Recurring, _ r: S.RecurringRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.kindRaw = r.kindRaw
        m.name = r.name
        m.icon = r.icon
        m.amountMinor = r.amountMinor
        m.cycleRaw = r.cycleRaw
        m.intervalDays = r.intervalDays
        m.intervalMonths = min(24, max(1, r.intervalMonths ?? 1))
        m.nextDate = r.nextDate
        m.anchorDay = r.anchorDay
        m.anchorMonth = r.anchorMonth
        m.categoryId = r.categoryId
        m.productId = r.productId
        m.responsibleId = r.responsibleId
        m.active = r.active
        m.dateUnset = r.dateUnset ?? false
        m.endDate = r.endDate
        m.totalCount = r.totalCount
        m.paidCount = r.paidCount ?? 0
        m.createdBy = r.createdBy
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Movimientos

    static func row(_ m: Entry) -> S.EntryRow {
        .init(id: m.id, spaceId: m.spaceId, kindRaw: m.kindRaw, amountMinor: m.amountMinor, occurredAt: m.occurredAt, name: m.name,
              merchant: m.merchant, icon: m.icon, categoryId: m.categoryId, productId: m.productId, recurringId: m.recurringId,
              paidBy: m.paidBy, methodRaw: m.methodRaw, sourceRaw: m.sourceRaw, needsReview: m.needsReview, notes: m.notes,
              createdBy: m.createdBy, createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.EntryRow) -> Entry {
        let m = Entry(id: r.id, spaceId: r.spaceId, kind: EntryKind(rawValue: r.kindRaw) ?? .gasto, amountMinor: r.amountMinor,
                      occurredAt: r.occurredAt, name: r.name)
        fill(m, r)
        return m
    }

    static func fill(_ m: Entry, _ r: S.EntryRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.kindRaw = r.kindRaw
        m.amountMinor = r.amountMinor
        m.occurredAt = r.occurredAt
        m.name = r.name
        m.merchant = r.merchant
        m.icon = r.icon
        m.categoryId = r.categoryId
        m.productId = r.productId
        m.recurringId = r.recurringId
        m.paidBy = r.paidBy
        m.methodRaw = r.methodRaw
        m.sourceRaw = r.sourceRaw
        m.needsReview = r.needsReview
        m.notes = r.notes
        m.createdBy = r.createdBy
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Transferencias

    static func row(_ m: Transfer) -> S.TransferRow {
        .init(id: m.id, spaceId: m.spaceId, fromProductId: m.fromProductId, toProductId: m.toProductId, amountMinor: m.amountMinor,
              occurredAt: m.occurredAt, notes: m.notes, createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.TransferRow) -> Transfer {
        let m = Transfer(spaceId: r.spaceId, fromProductId: r.fromProductId, toProductId: r.toProductId, amountMinor: r.amountMinor, occurredAt: r.occurredAt)
        fill(m, r)
        return m
    }

    static func fill(_ m: Transfer, _ r: S.TransferRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.fromProductId = r.fromProductId
        m.toProductId = r.toProductId
        m.amountMinor = r.amountMinor
        m.occurredAt = r.occurredAt
        m.notes = r.notes
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Avisos

    static func row(_ m: Reminder) -> S.ReminderRow {
        .init(id: m.id, spaceId: m.spaceId, recurringId: m.recurringId, daysBefore: m.daysBefore, targetRaw: m.targetRaw, userId: m.userId,
              atMinutes: m.atMinutes, notifyPartnerOnPaid: m.notifyPartnerOnPaid, sameDay: m.sameDay,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt, modeRaw: m.modeRaw)
    }

    static func make(_ r: S.ReminderRow) -> Reminder {
        let m = Reminder(spaceId: r.spaceId, recurringId: r.recurringId, daysBefore: r.daysBefore)
        fill(m, r)
        return m
    }

    static func fill(_ m: Reminder, _ r: S.ReminderRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.recurringId = r.recurringId
        m.daysBefore = min(14, max(0, r.daysBefore))
        m.targetRaw = r.targetRaw
        m.userId = r.userId
        m.atMinutes = r.atMinutes
        m.notifyPartnerOnPaid = r.notifyPartnerOnPaid
        m.sameDay = r.sameDay
        m.modeRaw = r.modeRaw ?? ReminderMode.personalizado.rawValue
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Límites

    static func row(_ m: Budget) -> S.BudgetRow {
        .init(id: m.id, spaceId: m.spaceId, categoryId: m.categoryId, monthlyLimitMinor: m.monthlyLimitMinor,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.BudgetRow) -> Budget {
        let m = Budget(spaceId: r.spaceId, categoryId: r.categoryId, monthlyLimitMinor: r.monthlyLimitMinor)
        fill(m, r)
        return m
    }

    static func fill(_ m: Budget, _ r: S.BudgetRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.categoryId = r.categoryId
        m.monthlyLimitMinor = r.monthlyLimitMinor
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Metas

    static func row(_ m: SavingsGoal) -> S.GoalRow {
        .init(id: m.id, spaceId: m.spaceId, name: m.name, targetAmountMinor: m.targetAmountMinor, targetDate: m.targetDate,
              productId: m.productId, createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.GoalRow) -> SavingsGoal {
        let m = SavingsGoal(spaceId: r.spaceId, name: r.name, targetAmountMinor: r.targetAmountMinor)
        fill(m, r)
        return m
    }

    static func fill(_ m: SavingsGoal, _ r: S.GoalRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.name = r.name
        m.targetAmountMinor = r.targetAmountMinor
        m.targetDate = r.targetDate
        m.productId = r.productId
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Aportes

    static func row(_ m: GoalContribution) -> S.ContributionRow {
        .init(id: m.id, spaceId: m.spaceId, goalId: m.goalId, userId: m.userId, amountMinor: m.amountMinor, occurredAt: m.occurredAt,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.ContributionRow) -> GoalContribution {
        let m = GoalContribution(spaceId: r.spaceId, goalId: r.goalId, userId: r.userId, amountMinor: r.amountMinor, occurredAt: r.occurredAt)
        fill(m, r)
        return m
    }

    static func fill(_ m: GoalContribution, _ r: S.ContributionRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.goalId = r.goalId
        m.userId = r.userId
        m.amountMinor = r.amountMinor
        m.occurredAt = r.occurredAt
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Puntos y millas

    static func row(_ m: RewardProgram) -> S.RewardRow {
        .init(id: m.id, spaceId: m.spaceId, name: m.name, kindRaw: m.kindRaw, balance: m.balance, valuePerPoint: m.valuePerPoint,
              expiresAt: m.expiresAt, productId: m.productId, colorHex: m.colorHex, balanceAt: m.balanceAt,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.RewardRow) -> RewardProgram {
        let m = RewardProgram(id: r.id, spaceId: r.spaceId, name: r.name, kind: RewardKind(rawValue: r.kindRaw) ?? .puntos, balance: r.balance)
        fill(m, r)
        return m
    }

    static func fill(_ m: RewardProgram, _ r: S.RewardRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.name = r.name
        m.kindRaw = r.kindRaw
        m.balance = r.balance
        m.valuePerPoint = r.valuePerPoint
        m.expiresAt = r.expiresAt
        m.productId = r.productId
        m.colorHex = r.colorHex
        m.balanceAt = r.balanceAt
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    // MARK: Nombres de comercios

    static func row(_ m: MerchantAlias) -> S.MerchantAliasRow {
        .init(id: m.id, spaceId: m.spaceId, key: m.merchantKey, name: m.name, categoryId: m.categoryId,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.MerchantAliasRow) -> MerchantAlias {
        let m = MerchantAlias(id: r.id, spaceId: r.spaceId, key: r.key, name: r.name, categoryId: r.categoryId)
        fill(m, r)
        return m
    }

    static func fill(_ m: MerchantAlias, _ r: S.MerchantAliasRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.merchantKey = r.key
        m.name = r.name
        m.categoryId = r.categoryId
        stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
    }

    private static func stamp<T: SyncTracked>(_ model: T, _ created: Date, _ updated: Date, _ deleted: Date?) {
        model.createdAt = created
        model.updatedAt = updated
        model.deletedAt = deleted
    }
}
