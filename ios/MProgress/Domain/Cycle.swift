import Foundation

/// Ciclo de un pago fijo (HANDOFF 8.2).
enum Cycle: Hashable, Codable, Sendable {
    case puntual
    case semanal
    case mensual
    case anual
    case cadaDias(Int)
    /// Cada N meses (2 a 24, sin 12, que es anual). Se guarda como "mensual" con `intervalMonths`.
    case cadaMeses(Int)
    /// Dos veces al mes en dos días fijos (la quincena de Colombia: 15 y último día). Se guarda como
    /// "quincenal" con `firstDay` y `secondDay`.
    case quincenal(QuincenaDays)

    var rawValue: String {
        switch self {
        case .puntual: "puntual"
        case .semanal: "semanal"
        case .mensual, .cadaMeses: "mensual"
        case .anual: "anual"
        case .cadaDias: "otra"
        case .quincenal: "quincenal"
        }
    }

    /// `intervalMonths` solo cuenta para "mensual": 1 (o nil, los datos de antes) es mensual.
    /// `firstDay` y `secondDay` solo cuentan para "quincenal": sin ellos es 15 y último día.
    init(rawValue: String, intervalDays: Int? = nil, intervalMonths: Int? = nil, firstDay: Int? = nil, secondDay: Int? = nil) {
        switch rawValue {
        case "semanal": self = .semanal
        case "mensual": self = Cycle.months(intervalMonths ?? 1)
        case "anual": self = .anual
        case "otra": self = .cadaDias(max(1, intervalDays ?? 30))
        case "quincenal":
            self = .quincenal(QuincenaDays(first: firstDay ?? QuincenaDays.standard.first, second: secondDay ?? QuincenaDays.standard.second))
        default: self = .puntual
        }
    }

    /// El ciclo de cada N meses, de 1 a 24: 1 es mensual y 12 es anual, así cada ciclo tiene una sola forma.
    static func months(_ count: Int) -> Cycle {
        let months = min(MonthInterval.range.upperBound, max(MonthInterval.range.lowerBound, count))
        switch months {
        case 1: return .mensual
        case 12: return .anual
        default: return .cadaMeses(months)
        }
    }

    var intervalDays: Int? {
        if case .cadaDias(let days) = self { return days }
        return nil
    }

    /// Meses entre cobros que se guardan (`interval_months`): N en cada N meses, 1 en todo lo demás.
    var intervalMonths: Int {
        if case .cadaMeses(let months) = self { return months }
        return 1
    }

    /// Primer día de la quincena que se guarda (`first_day`). Nil si no es quincenal.
    var firstDay: Int? {
        if case .quincenal(let days) = self { return days.first }
        return nil
    }

    /// Segundo día de la quincena que se guarda (`second_day`, 31 es el último día). Nil si no es quincenal.
    var secondDay: Int? {
        if case .quincenal(let days) = self { return days.second }
        return nil
    }

    /// Mensual o cada N meses: los que usan "Día del mes".
    var isMonthly: Bool {
        switch self {
        case .mensual, .cadaMeses: true
        default: false
        }
    }

    var title: String {
        switch self {
        case .puntual: "Una vez"
        case .semanal: "Semanal"
        case .mensual: "Mensual"
        case .anual: "Anual"
        case .cadaDias(let days): days % 7 == 0 && days >= 14 ? "Cada \(days / 7) semanas" : "Cada \(days) días"
        case .cadaMeses(let months): months == 24 ? "Cada 2 años" : MonthInterval.title(months: months)
        case .quincenal: "Quincenal"
        }
    }

    var repeats: Bool { self != .puntual }
}

/// Cada cuánto se repite un pago mensual (opciones de la pantalla): mensual, cada 2 meses, trimestral,
/// semestral, anual o cada N meses con un contador de 1 a 24.
enum MonthInterval: String, CaseIterable, Identifiable, Sendable {
    case mensual, bimestral, trimestral, semestral, anual, otro

    static let range = 1...24

    var id: String { rawValue }

    /// Meses de la opción. Nil en "Cada N meses": los pone el contador.
    var months: Int? {
        switch self {
        case .mensual: 1
        case .bimestral: 2
        case .trimestral: 3
        case .semestral: 6
        case .anual: 12
        case .otro: nil
        }
    }

    var title: String {
        switch self {
        case .mensual: "Mensual"
        case .bimestral: "Cada 2 meses"
        case .trimestral: "Trimestral"
        case .semestral: "Semestral"
        case .anual: "Anual"
        case .otro: "Cada N meses"
        }
    }

    /// La opción que corresponde a N meses; lo que no es una opción fija queda en "Cada N meses".
    static func of(months: Int) -> MonthInterval {
        allCases.first { $0.months == months } ?? .otro
    }

    /// "Mensual", "Cada 2 meses", "Trimestral", "Semestral", "Anual" o "Cada 4 meses".
    static func title(months: Int) -> String {
        let choice = of(months: months)
        return choice == .otro ? "Cada \(months) meses" : choice.title
    }

    /// El ciclo que resulta de la opción y del contador.
    static func cycle(_ choice: MonthInterval, months: Int) -> Cycle {
        Cycle.months(choice.months ?? months)
    }
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
            return addMonths(1, to: date, anchor: anchor, calendar: calendar)
        case .cadaMeses(let months):
            return addMonths(max(1, months), to: date, anchor: anchor, calendar: calendar)
        case .quincenal(let days):
            return nextQuincena(after: date, days: days, calendar: calendar)
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

    /// Suma meses desde el mes de `date` y pone el día ancla: el 31 de enero más un mes es el 28 (o 29) de febrero
    /// y el siguiente vuelve al 31 de marzo, porque el ancla es el día original y no el último usado.
    static func addMonths(_ months: Int, to date: Date, anchor: CycleAnchor, calendar: Calendar) -> Date? {
        guard let month = calendar.date(byAdding: .month, value: months, to: startOfMonth(date, calendar)) else { return nil }
        return clamp(day: anchor.day, inMonthOf: month, matching: date, calendar: calendar)
    }

    /// Siguiente día de quincena después de `date`: el primero del mes si no ha llegado, luego el segundo y luego el
    /// primero del mes que viene. Los días que el mes no tiene caen en su último día (el 30 es el 28 en febrero).
    /// No usa el ancla: los dos días van en el ciclo.
    static func nextQuincena(after date: Date, days: QuincenaDays, calendar: Calendar) -> Date? {
        let month = startOfMonth(date, calendar)
        let today = calendar.component(.day, from: date)
        let last = daysInMonth(month, calendar)
        if today < min(days.low, last) { return clamp(day: days.low, inMonthOf: month, matching: date, calendar: calendar) }
        if today < min(days.high, last) { return clamp(day: days.high, inMonthOf: month, matching: date, calendar: calendar) }
        guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return nil }
        return clamp(day: days.low, inMonthOf: next, matching: date, calendar: calendar)
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
