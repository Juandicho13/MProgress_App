import Foundation

/// Ciclo de un pago fijo (HANDOFF 8.2).
enum Cycle: Hashable, Codable, Sendable {
    case puntual
    case semanal
    case mensual
    case anual
    case cadaDias(Int)

    var rawValue: String {
        switch self {
        case .puntual: "puntual"
        case .semanal: "semanal"
        case .mensual: "mensual"
        case .anual: "anual"
        case .cadaDias: "otra"
        }
    }

    init(rawValue: String, intervalDays: Int? = nil) {
        switch rawValue {
        case "semanal": self = .semanal
        case "mensual": self = .mensual
        case "anual": self = .anual
        case "otra": self = .cadaDias(max(1, intervalDays ?? 30))
        default: self = .puntual
        }
    }

    var intervalDays: Int? {
        if case .cadaDias(let days) = self { return days }
        return nil
    }

    var title: String {
        switch self {
        case .puntual: "Puntual"
        case .semanal: "Semanal"
        case .mensual: "Mensual"
        case .anual: "Anual"
        case .cadaDias(let days): "Cada \(days) días"
        }
    }

    var repeats: Bool { self != .puntual }
}

/// Ancla de un pago fijo: el día (y mes) original. Con ella, un mensual del 31
/// cae el 30 en abril pero vuelve al 31 en mayo.
struct CycleAnchor: Hashable, Codable, Sendable {
    var day: Int
    var month: Int

    init(day: Int, month: Int) {
        self.day = day
        self.month = month
    }

    init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.day, .month], from: date)
        self.day = parts.day ?? 1
        self.month = parts.month ?? 1
    }
}

enum CycleMath {
    /// Próxima fecha después de `date`. Puntual devuelve nil.
    static func next(after date: Date, cycle: Cycle, anchor: CycleAnchor, calendar: Calendar) -> Date? {
        switch cycle {
        case .puntual:
            return nil
        case .semanal:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .cadaDias(let days):
            return calendar.date(byAdding: .day, value: days, to: date)
        case .mensual:
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth(date, calendar)) else { return nil }
            return clamp(day: anchor.day, inMonthOf: nextMonth, matching: date, calendar: calendar)
        case .anual:
            let year = calendar.component(.year, from: date) + 1
            var parts = DateComponents()
            parts.year = year
            parts.month = anchor.month
            parts.day = 1
            guard let firstOfMonth = calendar.date(from: parts) else { return nil }
            return clamp(day: anchor.day, inMonthOf: firstOfMonth, matching: date, calendar: calendar)
        }
    }

    /// Todas las fechas desde `start` (incluida) hasta `end` (incluida).
    static func occurrences(from start: Date, through end: Date, cycle: Cycle, anchor: CycleAnchor, calendar: Calendar, limit: Int = 400) -> [Date] {
        var result: [Date] = []
        var current: Date? = start
        while let date = current, date <= end, result.count < limit {
            result.append(date)
            current = next(after: date, cycle: cycle, anchor: anchor, calendar: calendar)
        }
        return result
    }

    static func startOfMonth(_ date: Date, _ calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }

    static func endOfMonth(_ date: Date, _ calendar: Calendar) -> Date {
        let start = startOfMonth(date, calendar)
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return next.addingTimeInterval(-1)
    }

    static func daysInMonth(_ date: Date, _ calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// Pone el día ancla en el mes dado, sin pasarse del último día, y conserva la hora de `matching`.
    private static func clamp(day: Int, inMonthOf month: Date, matching time: Date, calendar: Calendar) -> Date? {
        let lastDay = daysInMonth(month, calendar)
        var parts = calendar.dateComponents([.year, .month], from: month)
        let clock = calendar.dateComponents([.hour, .minute, .second], from: time)
        parts.day = min(day, lastDay)
        parts.hour = clock.hour
        parts.minute = clock.minute
        parts.second = clock.second
        return calendar.date(from: parts)
    }
}

/// Urgencia de un cargo (HANDOFF 8.2).
enum Urgency: String, Sendable, CaseIterable {
    case hoy, pronto, proximas

    var title: String {
        switch self {
        case .hoy: "Hoy"
        case .pronto: "Pronto"
        case .proximas: "Próximas"
        }
    }

    /// Hoy: vence hoy o ya venció. Pronto: 1 a 3 días. Próximas: más de 3 días.
    static func of(due: Date, now: Date, calendar: Calendar) -> Urgency {
        let days = dayDifference(from: now, to: due, calendar: calendar)
        if days <= 0 { return .hoy }
        if days <= 3 { return .pronto }
        return .proximas
    }

    static func dayDifference(from: Date, to: Date, calendar: Calendar) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }
}
