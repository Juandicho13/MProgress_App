import Foundation
import SwiftData

/// Avisos de pagos fijos, límites y metas de ahorro de un espacio (F07).
@MainActor
final class PlanningStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Avisos

    func reminder(for recurringId: UUID) throws -> Reminder? {
        try context.fetch(FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.recurringId == recurringId && $0.deletedAt == nil }
        )).first
    }

    /// Crea o cambia el aviso de un pago fijo. Solo hay uno por pago fijo.
    @discardableResult
    func setReminder(spaceId: UUID, recurringId: UUID, daysBefore: Int, atMinutes: Int, sameDay: Bool, now: Date = .now) throws -> Reminder {
        let reminder = try reminder(for: recurringId) ?? {
            let created = Reminder(spaceId: spaceId, recurringId: recurringId)
            context.insert(created)
            return created
        }()
        reminder.daysBefore = min(14, max(0, daysBefore))
        reminder.atMinutes = min(1439, max(0, atMinutes))
        reminder.sameDay = sameDay
        reminder.touch(now)
        try context.save()
        return reminder
    }

    func removeReminder(for recurringId: UUID, now: Date = .now) throws {
        guard let reminder = try reminder(for: recurringId) else { return }
        reminder.deletedAt = now
        reminder.touch(now)
        try context.save()
    }

    func reminders(spaceId: UUID) throws -> [Reminder] {
        try context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate<Reminder> { $0.spaceId == spaceId && $0.deletedAt == nil }))
    }

    // MARK: Límites

    func budgets(spaceId: UUID) throws -> [Budget] {
        try context.fetch(FetchDescriptor<Budget>(predicate: #Predicate<Budget> { $0.spaceId == spaceId && $0.deletedAt == nil }))
    }

    /// Crea o cambia el límite de una categoría (nil: el total del mes). Uno por categoría.
    @discardableResult
    func setBudget(spaceId: UUID, categoryId: UUID?, limitMinor: Int64, now: Date = .now) throws -> Budget {
        precondition(limitMinor > 0, "El límite va siempre positivo")
        let budget = try budgets(spaceId: spaceId).first { $0.categoryId == categoryId } ?? {
            let created = Budget(spaceId: spaceId, categoryId: categoryId, monthlyLimitMinor: limitMinor)
            context.insert(created)
            return created
        }()
        budget.monthlyLimitMinor = limitMinor
        budget.touch(now)
        try context.save()
        return budget
    }

    func removeBudget(_ budget: Budget, now: Date = .now) throws {
        budget.deletedAt = now
        budget.touch(now)
        try context.save()
    }

    // MARK: Ahorro

    func goals(spaceId: UUID) throws -> [SavingsGoal] {
        try context.fetch(FetchDescriptor<SavingsGoal>(
            predicate: #Predicate<SavingsGoal> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        ))
    }

    @discardableResult
    func addGoal(spaceId: UUID, name: String, targetMinor: Int64, targetDate: Date? = nil, productId: UUID? = nil, now: Date = .now) throws -> SavingsGoal {
        precondition(targetMinor > 0, "La meta va siempre positiva")
        let goal = SavingsGoal(spaceId: spaceId, name: name.trimmingCharacters(in: .whitespaces), targetAmountMinor: targetMinor)
        goal.targetDate = targetDate
        goal.productId = productId
        goal.touch(now)
        context.insert(goal)
        try context.save()
        return goal
    }

    func updateGoal(_ goal: SavingsGoal, name: String, targetMinor: Int64, targetDate: Date?, productId: UUID?, now: Date = .now) throws {
        precondition(targetMinor > 0, "La meta va siempre positiva")
        goal.name = name.trimmingCharacters(in: .whitespaces)
        goal.targetAmountMinor = targetMinor
        goal.targetDate = targetDate
        goal.productId = productId
        goal.touch(now)
        try context.save()
    }

    /// Aporte a una meta. Positivo suma, negativo retira.
    @discardableResult
    func contribute(to goal: SavingsGoal, amountMinor: Int64, userId: UUID? = nil, on date: Date = .now) throws -> GoalContribution {
        precondition(amountMinor != 0, "El aporte no puede ser cero")
        let contribution = GoalContribution(spaceId: goal.spaceId, goalId: goal.id, userId: userId, amountMinor: amountMinor, occurredAt: date)
        contribution.touch(date)
        context.insert(contribution)
        try context.save()
        return contribution
    }

    func contributions(spaceId: UUID) throws -> [GoalContribution] {
        try context.fetch(FetchDescriptor<GoalContribution>(
            predicate: #Predicate<GoalContribution> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        ))
    }

    func deleteGoal(_ goal: SavingsGoal, now: Date = .now) throws {
        goal.deletedAt = now
        goal.touch(now)
        try context.save()
    }

    // MARK: Avisos de límites

    /// Límites que cruzan el 80 o el 100 % por culpa de un gasto recién guardado.
    func budgetCrossings(spaceId: UUID, newEntry: Entry, now: Date = .now, calendar: Calendar = .current) throws -> [BudgetStatus] {
        guard newEntry.kind == .gasto else { return [] }
        let budgets = try budgets(spaceId: spaceId).map(\.record)
        guard !budgets.isEmpty else { return [] }
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        let entries = try LedgerStore(context: context, calendar: calendar).entries(spaceId: spaceId, in: month).map(\.record)
        let before = BudgetMath.statuses(budgets: budgets, entries: entries.filter { $0.id != newEntry.id }, now: now, calendar: calendar)
        let after = BudgetMath.statuses(budgets: budgets, entries: entries, now: now, calendar: calendar)
        return BudgetMath.crossings(before: before, after: after)
    }
}
