import Foundation

/// Cuentas de la zona de pagos fijos.
enum FixedMath {
    /// Cuánto pesa un pago fijo en un mes: semanal × 52 / 12, anual / 12, cada N días × 365 / (12 × N). Puntual no cuenta.
    static func monthlyEquivalent(amountMinor: Int64, cycle: Cycle) -> Int64 {
        switch cycle {
        case .puntual: 0
        case .mensual: amountMinor
        case .semanal: amountMinor * 52 / 12
        case .anual: amountMinor / 12
        case .cadaDias(let days): amountMinor * 365 / (12 * Int64(max(1, days)))
        }
    }

    struct Totals: Equatable, Sendable {
        var expenseMinor: Int64 = 0
        var incomeMinor: Int64 = 0
        var withoutDate = 0
        var paused = 0
    }

    /// Totales al mes de los pagos fijos activos. Los que no tienen fecha sí suman: el gasto existe aunque falte el día.
    static func totals(_ items: [(kind: EntryKind, amountMinor: Int64, cycle: Cycle, active: Bool, dateUnset: Bool)]) -> Totals {
        var totals = Totals()
        for item in items {
            if !item.active {
                totals.paused += 1
                continue
            }
            if item.dateUnset { totals.withoutDate += 1 }
            let monthly = monthlyEquivalent(amountMinor: item.amountMinor, cycle: item.cycle)
            if item.kind == .ingreso { totals.incomeMinor += monthly } else { totals.expenseMinor += monthly }
        }
        return totals
    }

    /// "Mensual · el 5", "Semanal", "Anual · 12 de mar", "Sin fecha".
    static func scheduleText(cycle: Cycle, nextDate: Date, dateUnset: Bool, calendar: Calendar) -> String {
        if dateUnset { return "\(cycle.title) · sin fecha" }
        let day = calendar.component(.day, from: nextDate)
        switch cycle {
        case .mensual: return "Mensual · el \(day)"
        case .anual: return "Anual · \(DueText.shortDate(nextDate, calendar: calendar))"
        default: return cycle.title
        }
    }
}
