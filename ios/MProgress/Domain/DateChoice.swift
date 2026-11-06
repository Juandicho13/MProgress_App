import Foundation

/// Atajos de fecha en Agregar y editar (PLAN_F12B "Fecha y hora más fáciles"): Hoy, Ayer, Mañana u Otra fecha.
enum DayShortcut: String, CaseIterable, Identifiable, Sendable {
    case hoy, ayer, manana

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hoy: "Hoy"
        case .ayer: "Ayer"
        case .manana: "Mañana"
        }
    }

    var offset: Int {
        switch self {
        case .hoy: 0
        case .ayer: -1
        case .manana: 1
        }
    }

    /// Cambia el día y conserva la hora de `date`: la hora es opcional y queda como estaba.
    func apply(to date: Date, now: Date, calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
        return DayShortcut.combine(day: day, time: date, calendar: calendar)
    }

    /// El atajo que corresponde a una fecha, o nil si es otra fecha.
    static func matching(_ date: Date, now: Date, calendar: Calendar) -> DayShortcut? {
        let days = Urgency.dayDifference(from: now, to: date, calendar: calendar)
        return allCases.first { $0.offset == days }
    }

    /// El día de `day` con la hora, minutos y segundos de `time`.
    static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        let clock = calendar.dateComponents([.hour, .minute, .second], from: time)
        parts.hour = clock.hour
        parts.minute = clock.minute
        parts.second = clock.second
        return calendar.date(from: parts) ?? day
    }
}

/// "Día del mes" de los pagos fijos mensuales: una cuadrícula de 1 a 31.
enum DayOfMonth {
    /// Fecha del cobro con ese día. Si el día ya pasó este mes, cae este mes cuando ya se pagó
    /// (así se anota) y el mes que viene cuando no. Si el mes no tiene ese día, usa el último.
    /// Conserva la hora de `time`.
    static func date(day: Int, now: Date, alreadyPaidIfPassed: Bool, time: Date? = nil, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let thisMonth = clamped(day: day, inMonthOf: today, calendar: calendar)
        var chosen = thisMonth
        if thisMonth < today && !alreadyPaidIfPassed {
            let next = calendar.date(byAdding: .month, value: 1, to: CycleMath.startOfMonth(today, calendar)) ?? today
            chosen = clamped(day: day, inMonthOf: next, calendar: calendar)
        }
        return DayShortcut.combine(day: chosen, time: time ?? now, calendar: calendar)
    }

    /// El día ya pasó en el mes de `now` (hoy no cuenta como pasado).
    static func hasPassed(day: Int, now: Date, calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: now)
        return clamped(day: day, inMonthOf: today, calendar: calendar) < today
    }

    private static func clamped(day: Int, inMonthOf month: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month], from: month)
        parts.day = min(max(1, day), CycleMath.daysInMonth(month, calendar))
        return calendar.date(from: parts) ?? month
    }
}
