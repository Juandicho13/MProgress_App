import Foundation

/// Cuentas del calendario de semana de Agregar: una fila de 7 días que empieza el lunes (como en Colombia), el mes
/// completo con los días del mes anterior y del siguiente para llenar las semanas, y el título "noviembre 2026".
/// No depende del primer día de la semana del teléfono.
enum DateStrip {
    static let weekdayInitials = ["L", "M", "M", "J", "V", "S", "D"]
    static let weekdayNames = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
    /// Lo más lejos que puede quedar la fecha de un movimiento, hacia atrás o hacia adelante.
    static let maxYears = 2

    /// Un día de la cuadrícula del mes. `inMonth` es falso en los días del mes anterior o siguiente.
    struct Day: Hashable, Sendable {
        var date: Date
        var day: Int
        var inMonth: Bool
    }

    /// 0 el lunes, 6 el domingo.
    static func mondayIndex(_ date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// El lunes de la semana de `date`, al empezar el día.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -mondayIndex(day, calendar: calendar), to: day) ?? day
    }

    /// Los 7 días (de lunes a domingo) de la semana de `date`.
    static func week(of date: Date, calendar: Calendar) -> [Date] {
        let start = weekStart(of: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Semanas completas del mes de `date`, de lunes a domingo, con los días de los meses vecinos al principio y al final.
    static func monthGrid(of date: Date, calendar: Calendar) -> [Day] {
        let first = CycleMath.startOfMonth(date, calendar)
        let count = CycleMath.daysInMonth(first, calendar)
        let lead = mondayIndex(first, calendar: calendar)
        let cells = Int((Double(lead + count) / 7).rounded(.up)) * 7
        let start = calendar.date(byAdding: .day, value: -lead, to: first) ?? first
        let month = calendar.component(.month, from: first)
        return (0..<cells).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return Day(date: day, day: calendar.component(.day, from: day), inMonth: calendar.component(.month, from: day) == month)
        }
    }

    /// "noviembre 2026".
    static func monthLabel(_ date: Date, calendar: Calendar) -> String {
        "\(DueText.monthName(date, calendar: calendar)) \(calendar.component(.year, from: date))"
    }

    /// "viernes 7 de noviembre de 2026", para VoiceOver y TalkBack.
    static func spokenDate(_ date: Date, calendar: Calendar) -> String {
        let weekday = weekdayNames[mondayIndex(date, calendar: calendar)]
        let parts = calendar.dateComponents([.day, .year], from: date)
        return "\(weekday) \(parts.day ?? 1) de \(DueText.monthName(date, calendar: calendar)) de \(parts.year ?? 0)"
    }

    /// Primer y último día que se pueden elegir: dos años antes y dos años después de hoy.
    static func bounds(now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let low = calendar.date(byAdding: .year, value: -maxYears, to: today) ?? today
        let high = calendar.date(byAdding: .year, value: maxYears, to: today) ?? today
        return low...high
    }

    static func isSelectable(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        bounds(now: now, calendar: calendar).contains(calendar.startOfDay(for: date))
    }

    /// La misma fecha N semanas antes o después.
    static func shiftWeek(_ date: Date, by weeks: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 7 * weeks, to: calendar.startOfDay(for: date)) ?? date
    }

    /// El primer día del mes N meses antes o después.
    static func shiftMonth(_ date: Date, by months: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: CycleMath.startOfMonth(date, calendar)) ?? date
    }

    /// Se puede ir a la semana de al lado si tiene por lo menos un día elegible.
    static func canShiftWeek(from visible: Date, by weeks: Int, now: Date, calendar: Calendar) -> Bool {
        week(of: shiftWeek(visible, by: weeks, calendar: calendar), calendar: calendar).contains { isSelectable($0, now: now, calendar: calendar) }
    }

    /// Se puede ir al mes de al lado si tiene por lo menos un día elegible.
    static func canShiftMonth(from visible: Date, by months: Int, now: Date, calendar: Calendar) -> Bool {
        let month = shiftMonth(visible, by: months, calendar: calendar)
        let range = bounds(now: now, calendar: calendar)
        return CycleMath.startOfMonth(month, calendar) <= range.upperBound && CycleMath.endOfMonth(month, calendar) >= range.lowerBound
    }

    /// El mismo día que `date` si está dentro de los dos años; si no, el borde más cercano. Conserva la hora.
    static func clamp(_ date: Date, now: Date, calendar: Calendar) -> Date {
        let range = bounds(now: now, calendar: calendar)
        let day = calendar.startOfDay(for: date)
        if day < range.lowerBound { return DayShortcut.combine(day: range.lowerBound, time: date, calendar: calendar) }
        if day > range.upperBound { return DayShortcut.combine(day: range.upperBound, time: date, calendar: calendar) }
        return date
    }
}
