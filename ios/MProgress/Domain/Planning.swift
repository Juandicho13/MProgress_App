import Foundation

// MARK: Avisos (F07-02)

/// Ajustes de un aviso de pago fijo, ya sin SwiftData.
struct ReminderRule: Hashable, Sendable {
    var recurringId: UUID
    /// 0 a 14 días antes.
    var daysBefore: Int
    /// Minutos desde la medianoche: 540 son las 9:00.
    var atMinutes: Int
    /// Además, avisar el mismo día del cobro.
    var sameDay: Bool
}

/// Una notificación local lista para programar.
struct PlannedNotification: Hashable, Sendable {
    /// Identificador estable: si se reprograma, reemplaza la anterior.
    var id: String
    var fireDate: Date
    var title: String
    var body: String
}

enum ReminderPlanner {
    /// iOS guarda hasta 64 notificaciones pendientes por app; dejamos espacio para las de límites.
    static let maxPending = 60

    /// Notificaciones de los pagos fijos con aviso y de las tarjetas con día de pago, desde `now` hasta `horizonDays`.
    static func plan(recurring: [RecurringRecord], rules: [ReminderRule], cards: [ProductRecord] = [],
                     cardRule: (daysBefore: Int, atMinutes: Int)? = nil, currency: Currency,
                     now: Date, calendar: Calendar, horizonDays: Int = 60) -> [PlannedNotification] {
        let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
        var result: [PlannedNotification] = []
        let rulesById = Dictionary(rules.map { ($0.recurringId, $0) }, uniquingKeysWith: { first, _ in first })

        for item in recurring where item.active {
            guard let rule = rulesById[item.id] else { continue }
            let last = calendar.date(byAdding: .day, value: max(0, rule.daysBefore), to: horizon) ?? horizon
            for due in CycleMath.occurrences(from: item.nextDate, through: last, cycle: item.cycle, anchor: item.anchor, calendar: calendar, limit: 30) {
                let amount = Money(minor: item.amountMinor, currency: currency).formatted()
                var offsets = [max(0, min(14, rule.daysBefore))]
                if rule.sameDay && !offsets.contains(0) { offsets.append(0) }
                for days in offsets {
                    guard let fire = fireDate(due: due, daysBefore: days, atMinutes: rule.atMinutes, calendar: calendar),
                          fire > now, fire <= horizon else { continue }
                    result.append(PlannedNotification(
                        id: "mp.fijo.\(item.id.uuidString).\(dayKey(due, calendar)).\(days)",
                        fireDate: fire,
                        title: item.name,
                        body: body(name: item.name, kind: item.kind, amount: amount, days: days)
                    ))
                }
            }
        }

        if let cardRule {
            for card in cards where card.kind == .credito {
                guard let day = card.dueDay else { continue }
                var cursor = now
                for _ in 0..<3 {
                    let due = WalletMath.nextDueDate(day: day, now: cursor, calendar: calendar)
                    if let fire = fireDate(due: due, daysBefore: cardRule.daysBefore, atMinutes: cardRule.atMinutes, calendar: calendar),
                       fire > now, fire <= horizon {
                        result.append(PlannedNotification(
                            id: "mp.tarjeta.\(card.id.uuidString).\(dayKey(due, calendar))",
                            fireDate: fire,
                            title: "Pago de \(card.name)",
                            body: cardRule.daysBefore == 0 ? "Hoy es el día de pago de tu tarjeta." : "Tu tarjeta se paga \(inDays(cardRule.daysBefore))."
                        ))
                    }
                    cursor = calendar.date(byAdding: .day, value: 1, to: due) ?? horizon
                }
            }
        }

        return Array(result.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(maxPending))
    }

    /// Fecha y hora del aviso: el día del cobro menos `daysBefore`, a la hora pedida.
    static func fireDate(due: Date, daysBefore: Int, atMinutes: Int, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: due)) else { return nil }
        return calendar.date(byAdding: .minute, value: min(1439, max(0, atMinutes)), to: day)
    }

    /// "Renta vence en 3 días · $ 2.275.000", "Sueldo llega hoy · $ 3.000.000".
    static func body(name: String, kind: EntryKind, amount: String, days: Int) -> String {
        let verb = kind == .ingreso ? "llega" : "vence"
        return "\(name) \(verb) \(inDays(days)) · \(amount)"
    }

    static func inDays(_ days: Int) -> String {
        switch days {
        case 0: "hoy"
        case 1: "mañana"
        default: "en \(days) días"
        }
    }

    /// "9:00 a. m." a partir de minutos desde la medianoche.
    static func timeText(_ minutes: Int) -> String {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelve, minute, hour < 12 ? "a. m." : "p. m.")
    }

    private static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: Límites (F07-04)

struct BudgetRecord: Hashable, Sendable {
    var id: UUID = UUID()
    /// Nil es el límite total del mes.
    var categoryId: UUID?
    var limitMinor: Int64
}

struct BudgetStatus: Hashable, Sendable {
    enum Level: Int, Comparable, Sendable {
        case bien, cerca, superado
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    var budget: BudgetRecord
    var spentMinor: Int64
    var ratio: Double { budget.limitMinor > 0 ? Double(spentMinor) / Double(budget.limitMinor) : 0 }
    var remainingMinor: Int64 { budget.limitMinor - spentMinor }
    var level: Level { BudgetMath.level(ratio: ratio) }
}

enum BudgetMath {
    /// Avisos al 80 % y al 100 % (HANDOFF 8.2).
    static let nearRatio = 0.8

    static func level(ratio: Double) -> BudgetStatus.Level {
        if ratio >= 1 { return .superado }
        if ratio >= nearRatio { return .cerca }
        return .bien
    }

    /// Estado de cada límite en el mes de `now`. El total va primero; luego las categorías de más a menos usadas.
    static func statuses(budgets: [BudgetRecord], entries: [EntryRecord], now: Date, calendar: Calendar) -> [BudgetStatus] {
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        let spent = entries.filter { $0.kind == .gasto && month.contains($0.occurredAt) }
        return budgets.map { budget in
            let total = spent.filter { budget.categoryId == nil || $0.categoryId == budget.categoryId }.reduce(Int64(0)) { $0 + $1.amountMinor }
            return BudgetStatus(budget: budget, spentMinor: total)
        }
        .sorted { a, b in
            if (a.budget.categoryId == nil) != (b.budget.categoryId == nil) { return a.budget.categoryId == nil }
            return a.ratio > b.ratio
        }
    }

    /// Cuánto se puede gastar por día lo que queda del mes, contando hoy.
    static func dailyAllowance(remainingMinor: Int64, now: Date, calendar: Calendar) -> Int64 {
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        let days = max(1, Urgency.dayDifference(from: now, to: month.end.addingTimeInterval(-1), calendar: calendar) + 1)
        return max(0, remainingMinor) / Int64(days)
    }

    /// Límites que un gasto nuevo hace cruzar al 80 % o al 100 %: son los que se avisan.
    static func crossings(before: [BudgetStatus], after: [BudgetStatus]) -> [BudgetStatus] {
        let previous = Dictionary(before.map { ($0.budget.id, $0.level) }, uniquingKeysWith: { first, _ in first })
        return after.filter { status in
            status.level > .bien && status.level > (previous[status.budget.id] ?? .bien)
        }
    }
}

// MARK: Ahorro (F07-05)

struct GoalRecord: Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var targetMinor: Int64
    var targetDate: Date?
    /// Si la meta está ligada a una cajita, lo ahorrado es el saldo de la cajita.
    var productId: UUID?
}

struct GoalProgress: Hashable, Sendable {
    var goal: GoalRecord
    var savedMinor: Int64
    var ratio: Double { goal.targetMinor > 0 ? min(1, Double(savedMinor) / Double(goal.targetMinor)) : 0 }
    var missingMinor: Int64 { max(0, goal.targetMinor - savedMinor) }
    /// Aporte mensual para llegar a la fecha, si hay fecha y falta plata.
    var monthlyNeededMinor: Int64?
}

enum SavingsMath {
    static func progress(goal: GoalRecord, contributions: [(goalId: UUID, amountMinor: Int64)],
                         productBalance: Int64?, now: Date, calendar: Calendar) -> GoalProgress {
        let saved = productBalance ?? contributions.filter { $0.goalId == goal.id }.reduce(Int64(0)) { $0 + $1.amountMinor }
        var result = GoalProgress(goal: goal, savedMinor: saved)
        if let date = goal.targetDate, result.missingMinor > 0 {
            let months = monthsBetween(now, date, calendar: calendar)
            result.monthlyNeededMinor = months > 0 ? (result.missingMinor + Int64(months) - 1) / Int64(months) : result.missingMinor
        }
        return result
    }

    /// Meses que quedan contando el actual: de noviembre a junio son 8.
    static func monthsBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        let a = calendar.dateComponents([.year, .month], from: from)
        let b = calendar.dateComponents([.year, .month], from: to)
        let diff = ((b.year ?? 0) - (a.year ?? 0)) * 12 + ((b.month ?? 0) - (a.month ?? 0))
        return max(0, diff + 1)
    }

    /// Aportes del mes de `now`.
    static func savedThisMonth(_ contributions: [(occurredAt: Date, amountMinor: Int64)], now: Date, calendar: Calendar) -> Int64 {
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        return contributions.filter { month.contains($0.occurredAt) }.reduce(Int64(0)) { $0 + $1.amountMinor }
    }
}
