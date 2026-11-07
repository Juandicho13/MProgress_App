import Foundation

/// El mes de `now` con datos reales, sin predicciones inventadas (PLAN_F12B Paso 4).
struct MonthFacts: Hashable, Sendable {
    /// Ingresos ya registrados este mes.
    var enteredMinor: Int64
    /// Pagos fijos de ingreso que todavía faltan este mes.
    var pendingIncomeMinor: Int64
    /// Lo que ya salió este mes.
    var spentMinor: Int64
    /// Pagos fijos de gasto que todavía faltan este mes.
    var pendingFixedMinor: Int64
    /// Te quedan = ingresos (registrados y por entrar) − gastado − fijos que faltan. El mismo número de Inicio.
    var remainingMinor: Int64
    var isOver: Bool { remainingMinor < 0 }
}

/// Un mes que viene, para "Los próximos 3 meses": solo pagos fijos.
struct MonthForecast: Hashable, Sendable, Identifiable {
    var month: Date
    /// Pagos fijos de ingreso que caen en el mes.
    var fixedIncomeMinor: Int64
    /// Pagos fijos de gasto que caen en el mes (respetando fecha final y cuotas).
    var fixedExpenseMinor: Int64

    var id: Date { month }
    /// Lo que quedaría: ingresos fijos menos gastos fijos.
    var netMinor: Int64 { fixedIncomeMinor - fixedExpenseMinor }
}

/// Cuentas del mes y de los meses que vienen (PLAN_F12B Paso 4). Solo datos reales y pagos fijos programados:
/// nada de ritmos de gasto ni estimados. Funciones puras.
enum Forecast {
    /// "Este mes" de Resumen. Sale de `monthSummary`, así Te quedan es igual al de Inicio.
    static func monthFacts(entries: [EntryRecord], recurring: [RecurringRecord], now: Date, calendar: Calendar) -> MonthFacts {
        let summary = BalanceCalculator.monthSummary(entries: entries, recurring: recurring, now: now, calendar: calendar)
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        let entered = entries
            .filter { $0.kind == .ingreso && month.contains($0.occurredAt) }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        return MonthFacts(enteredMinor: entered,
                          pendingIncomeMinor: summary.expectedIncomeMinor - entered,
                          spentMinor: summary.spentMinor,
                          pendingFixedMinor: summary.pendingFixedMinor,
                          remainingMinor: summary.remainingMinor)
    }

    /// Los `count` meses siguientes al de `now`: ingresos fijos y gastos fijos (con fecha final y cuotas).
    static func nextMonths(_ count: Int = 3, recurring: [RecurringRecord], now: Date, calendar: Calendar) -> [MonthForecast] {
        let current = CycleMath.startOfMonth(now, calendar)
        return (1...max(1, count)).compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: offset, to: current) else { return nil }
            let month = BalanceCalculator.monthInterval(containing: start, calendar: calendar)
            var income: Int64 = 0
            var expense: Int64 = 0
            for item in recurring {
                let times = Int64(BalanceCalculator.pendingOccurrences(of: item, in: month, calendar: calendar).count)
                if item.kind == .ingreso { income += times * item.amountMinor } else { expense += times * item.amountMinor }
            }
            return MonthForecast(month: start, fixedIncomeMinor: income, fixedExpenseMinor: expense)
        }
    }

    /// "Te pasaste $ X de lo que entra este mes", solo si Te quedan ya es negativo.
    static func overText(remainingMinor: Int64, currency: Currency) -> String? {
        guard remainingMinor < 0 else { return nil }
        return "Te pasaste \(Money(minor: -remainingMinor, currency: currency).formatted()) de lo que entra este mes"
    }

    /// "Quedan $ X" de un mes que viene (con signo si es negativo).
    static func netText(_ month: MonthForecast, currency: Currency) -> String {
        "Quedan \(Money(minor: month.netMinor, currency: currency).formatted())"
    }

    /// Nota bajo "Los próximos 3 meses".
    static let nextMonthsNote = "Solo cuenta tus pagos fijos"
}
