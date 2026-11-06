import Foundation

/// Periodo del Resumen (F05-01).
enum SummaryPeriod: Hashable, Sendable {
    case esteMes
    case meses(Int)
    case personalizado(start: Date, end: Date)

    static let presets: [SummaryPeriod] = [.esteMes, .meses(3), .meses(6), .meses(12)]

    var title: String {
        switch self {
        case .esteMes: "Este mes"
        case .meses(let count): "\(count) meses"
        case .personalizado: "Personalizado"
        }
    }

    /// Intervalo [inicio, fin). Los presets terminan al final del mes actual; "3 meses" son este y los 2 anteriores.
    func interval(now: Date, calendar: Calendar) -> DateInterval {
        let current = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        switch self {
        case .esteMes:
            return current
        case .meses(let count):
            let start = calendar.date(byAdding: .month, value: -(max(1, count) - 1), to: current.start) ?? current.start
            return DateInterval(start: start, end: current.end)
        case .personalizado(let start, let end):
            let from = calendar.startOfDay(for: min(start, end))
            let lastDay = calendar.startOfDay(for: max(start, end))
            let to = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return DateInterval(start: from, end: to)
        }
    }
}

/// Entradas y salidas de un mes, para las barras de Ingresos y gastos.
struct MonthFlow: Hashable, Sendable, Identifiable {
    var month: Date
    var incomeMinor: Int64
    var spentMinor: Int64
    var id: Date { month }
}

/// Gasto acumulado de un día del mes, para la línea de Cómo va tu gasto.
struct DailyPoint: Hashable, Sendable, Identifiable {
    var day: Int
    var cumulativeMinor: Int64
    var id: Int { day }
}

/// Lo que ya está programado para el mes que viene.
struct NextMonthPlan: Hashable, Sendable {
    var expenseMinor: Int64
    var incomeMinor: Int64
    var count: Int
}

enum SummaryMath {
    /// Deja solo los movimientos del intervalo y, si hay filtro, solo los gastos de esas categorías.
    /// Con filtro de categorías los ingresos no cuentan: las categorías son de gasto.
    static func filter(_ entries: [EntryRecord], in interval: DateInterval, categories: Set<UUID>? = nil) -> [EntryRecord] {
        entries.filter { entry in
            guard interval.contains(entry.occurredAt) else { return false }
            guard let categories else { return true }
            return entry.kind == .gasto && entry.categoryId.map(categories.contains) == true
        }
    }

    /// Un MonthFlow por cada mes que toca el intervalo, del más viejo al más nuevo, aunque no tenga datos.
    static func monthlyFlows(_ entries: [EntryRecord], in interval: DateInterval, calendar: Calendar) -> [MonthFlow] {
        var months: [Date] = []
        var cursor = CycleMath.startOfMonth(interval.start, calendar)
        while cursor < interval.end, months.count < 120 {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? interval.end
        }
        return months.map { month in
            let inMonth = entries.filter { CycleMath.startOfMonth($0.occurredAt, calendar) == month }
            return MonthFlow(
                month: month,
                incomeMinor: inMonth.filter { $0.kind == .ingreso }.reduce(0) { $0 + $1.amountMinor },
                spentMinor: inMonth.filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amountMinor }
            )
        }
    }

    static func totals(_ flows: [MonthFlow]) -> (income: Int64, spent: Int64, net: Int64) {
        let income = flows.reduce(0) { $0 + $1.incomeMinor }
        let spent = flows.reduce(0) { $0 + $1.spentMinor }
        return (income, spent, income - spent)
    }

    /// Gasto acumulado por día del mes. Si `upTo` cae dentro del mes, la serie se corta ese día.
    static func cumulative(_ entries: [EntryRecord], month: Date, upTo: Date? = nil, calendar: Calendar) -> [DailyPoint] {
        let interval = BalanceCalculator.monthInterval(containing: month, calendar: calendar)
        var lastDay = CycleMath.daysInMonth(month, calendar)
        if let upTo, interval.contains(upTo) { lastDay = calendar.component(.day, from: upTo) }
        var byDay: [Int: Int64] = [:]
        for entry in entries where entry.kind == .gasto && interval.contains(entry.occurredAt) {
            byDay[calendar.component(.day, from: entry.occurredAt), default: 0] += entry.amountMinor
        }
        var running: Int64 = 0
        return (1...lastDay).map { day in
            running += byDay[day] ?? 0
            return DailyPoint(day: day, cumulativeMinor: running)
        }
    }

    /// Cuánto más o menos llevas gastado hoy frente al mismo día del mes pasado. Positivo: vas gastando más.
    static func versusLastMonth(_ entries: [EntryRecord], now: Date, calendar: Calendar) -> (thisMonth: Int64, lastMonth: Int64, difference: Int64) {
        let this = cumulative(entries, month: now, upTo: now, calendar: calendar).last?.cumulativeMinor ?? 0
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: CycleMath.startOfMonth(now, calendar)) ?? now
        let day = calendar.component(.day, from: now)
        let previous = cumulative(entries, month: previousMonth, calendar: calendar)
        let last = previous.isEmpty ? 0 : previous[min(day, previous.count) - 1].cumulativeMinor
        return (this, last, this - last)
    }

    /// De los últimos 12 meses con gasto, cuántos quedaron por encima del mes normal.
    static func monthsAboveNormal(_ entries: [EntryRecord], now: Date, calendar: Calendar) -> (above: Int, counted: Int)? {
        guard let normal = BalanceCalculator.normalMonth(entries: entries, now: now, calendar: calendar) else { return nil }
        let totals = BalanceCalculator.monthlyExpenses(entries: entries, now: now, months: 12, calendar: calendar).filter { $0 > 0 }
        return (totals.filter { $0 > normal }.count, totals.count)
    }

    /// Pagos fijos activos que caen en el mes siguiente al de `now`.
    static func nextMonth(_ recurring: [RecurringRecord], now: Date, calendar: Calendar) -> NextMonthPlan {
        let start = calendar.date(byAdding: .month, value: 1, to: CycleMath.startOfMonth(now, calendar)) ?? now
        let month = BalanceCalculator.monthInterval(containing: start, calendar: calendar)
        var plan = NextMonthPlan(expenseMinor: 0, incomeMinor: 0, count: 0)
        for item in recurring {
            let count = BalanceCalculator.pendingOccurrences(of: item, in: month, calendar: calendar).count
            guard count > 0 else { continue }
            plan.count += count
            if item.kind == .ingreso {
                plan.incomeMinor += Int64(count) * item.amountMinor
            } else {
                plan.expenseMinor += Int64(count) * item.amountMinor
            }
        }
        return plan
    }

    /// Categorías que tienen gasto en el intervalo, de mayor a menor: son los chips del filtro.
    static func activeCategories(_ entries: [EntryRecord], in interval: DateInterval) -> [UUID] {
        BalanceCalculator.spendingByCategory(entries: entries, in: interval).compactMap(\.categoryId)
    }
}
