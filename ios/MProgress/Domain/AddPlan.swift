import Foundation

/// Qué se guarda al tocar Guardar en Agregar (F03-03).
/// - Puntual con fecha de hoy o pasada: un movimiento.
/// - Puntual con fecha futura: un pago fijo puntual pendiente.
/// - Repetido con fecha de hoy o pasada: el movimiento de esa fecha y el pago fijo desde la siguiente.
/// - Repetido con fecha futura: solo el pago fijo.
struct AddPlan: Equatable, Sendable {
    var entryDate: Date?
    var recurringNext: Date?
    /// Repetido con fecha de hoy o pasada: cuántos cobros quedaron atrás (la fecha elegida y los que se saltaron
    /// hasta hoy). Con cuotas, son las cuotas que ya cuentan como pagadas.
    var elapsed: Int = 0

    /// `anchor`: el día original si no es el de `date` (un mensual del 31 elegido en noviembre cae el 30 pero sigue siendo del 31).
    static func decide(cycle: Cycle, date: Date, now: Date, calendar: Calendar, anchor: CycleAnchor? = nil) -> AddPlan {
        let isDue = calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
        guard cycle.repeats else {
            return isDue ? AddPlan(entryDate: date, recurringNext: nil) : AddPlan(entryDate: nil, recurringNext: date)
        }
        guard isDue else { return AddPlan(entryDate: nil, recurringNext: date) }

        let anchor = anchor ?? CycleAnchor(date: date, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        var next = CycleMath.next(after: date, cycle: cycle, anchor: anchor, calendar: calendar) ?? date
        var guardCount = 0
        while calendar.startOfDay(for: next) <= today, guardCount < 500 {
            next = CycleMath.next(after: next, cycle: cycle, anchor: anchor, calendar: calendar) ?? next
            guardCount += 1
        }
        return AddPlan(entryDate: date, recurringNext: next, elapsed: guardCount + 1)
    }
}

/// Texto corto de cuándo vence: "Hoy", "Mañana", "En 6 días", "Hace 2 días", "1 dic".
enum DueText {
    static func describe(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = Urgency.dayDifference(from: now, to: date, calendar: calendar)
        switch days {
        case 0: return "Hoy"
        case 1: return "Mañana"
        case 2...14: return "En \(days) días"
        case -1: return "Ayer"
        case -14 ... -2: return "Hace \(-days) días"
        default: return shortDate(date, calendar: calendar)
        }
    }

    static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    /// "1 dic" o "1 dic 2027" si es de otro año.
    static func shortDate(_ date: Date, calendar: Calendar, now: Date = Date()) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        let month = months[max(0, min(11, (parts.month ?? 1) - 1))]
        let base = "\(parts.day ?? 1) \(month)"
        if parts.year != calendar.component(.year, from: now) { return "\(base) \(parts.year ?? 0)" }
        return base
    }

    static let monthNames = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    static func monthName(_ date: Date, calendar: Calendar) -> String {
        monthNames[max(0, min(11, calendar.component(.month, from: date) - 1))]
    }
}
