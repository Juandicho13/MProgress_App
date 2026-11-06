import Foundation
import SwiftData
import WidgetKit

/// Escribe el resumen para los widgets y les pide que se redibujen. Se llama al volver a la app,
/// al salir y después de guardar algo.
@MainActor
enum WidgetPublisher {
    static func publish(context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard WidgetSnapshot.canShare, let snapshot = try? build(context: context, now: now, calendar: calendar) else { return }
        try? snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func build(context: ModelContext, now: Date, calendar: Calendar) throws -> WidgetSnapshot? {
        let spaces = try context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil }, sortBy: [SortDescriptor(\.createdAt)]))
        guard let space = spaces.first(where: { $0.kindRaw == "personal" }) ?? spaces.first else { return nil }
        let ledger = LedgerStore(context: context, calendar: calendar)
        let entries = try ledger.entries(spaceId: space.id).map(\.record)
        let recurring = try ledger.recurring(spaceId: space.id).map(\.record)
        let currency = space.currency
        let summary = BalanceCalculator.monthSummary(entries: entries, recurring: recurring, now: now, calendar: calendar)
        let upcoming = BalanceCalculator.upcoming(recurring: recurring, now: now, calendar: calendar, kind: nil, limit: 6)
        let month = CalendarMath.days(month: now, entries: [], recurring: recurring, now: now, calendar: calendar)
        let start = CycleMath.startOfMonth(now, calendar)
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7

        var chargeDays: [String: Int] = [:]
        for (date, day) in month where day.hasCharge || day.hasIncome {
            let urgency = day.charges.map(\.urgency).min { $0.rank < $1.rank } ?? .proximas
            chargeDays[String(calendar.component(.day, from: date))] = urgency.rank
        }

        return WidgetSnapshot(
            updatedAt: now,
            remainingText: Money(minor: summary.remainingMinor, currency: currency).formatted(),
            remainingIsNegative: summary.remainingMinor < 0,
            monthName: DueText.monthName(now, calendar: calendar),
            spentRatio: summary.spentRatio,
            charges: upcoming.map {
                .init(name: $0.name, amountText: Money(minor: $0.amountMinor, currency: currency).formatted(),
                      daysLeft: $0.daysLeft, isIncome: $0.kind == .ingreso)
            },
            monthTitle: DueText.monthName(now, calendar: calendar).capitalized,
            weekdaySymbols: CalendarMath.weekdaySymbols(calendar: calendar),
            leadingBlanks: leading,
            daysInMonth: CycleMath.daysInMonth(now, calendar),
            today: calendar.component(.day, from: now),
            chargeDays: chargeDays,
            chargesThisMonth: month.values.reduce(0) { $0 + $1.charges.filter { $0.kind == .gasto }.count },
            isEmpty: entries.isEmpty && recurring.isEmpty
        )
    }
}

private extension Urgency {
    var rank: Int {
        switch self {
        case .hoy: 0
        case .pronto: 1
        case .proximas: 2
        }
    }
}
