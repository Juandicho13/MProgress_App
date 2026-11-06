import Foundation

/// Un mes que viene, para "Los próximos 3 meses" (PLAN_F12B Paso 4).
struct MonthForecast: Hashable, Sendable, Identifiable {
    var month: Date
    /// Pagos fijos de ingreso que caen en el mes.
    var fixedIncomeMinor: Int64
    /// Pagos fijos de gasto que caen en el mes (respetando fecha final y cuotas).
    var fixedExpenseMinor: Int64
    /// Gasto variable estimado.
    var variableMinor: Int64
    /// True si el variable sale del promedio de meses anteriores; false si sale del ritmo de este mes.
    var variableFromHistory: Bool

    var id: Date { month }
    /// Lo que quedaría: ingresos menos fijos menos variable.
    var netMinor: Int64 { fixedIncomeMinor - fixedExpenseMinor - variableMinor }
}

/// Cómo vas a terminar el mes de `now`.
struct EndOfMonthForecast: Hashable, Sendable {
    var summary: MonthSummary
    /// Gasto variable por día de este mes.
    var paceMinor: Int64
    /// Te quedan − ritmo × días que faltan.
    var projectedMinor: Int64
    var isNegative: Bool { projectedMinor < 0 }
}

/// Predicciones (PLAN_F12B Paso 4). Funciones puras.
enum Forecast {
    /// Lo que se gastó en un intervalo sin contar los pagos fijos (movimientos sin `recurringId`).
    static func variableSpent(_ entries: [EntryRecord], in interval: DateInterval) -> Int64 {
        entries
            .filter { $0.kind == .gasto && $0.recurringId == nil && interval.contains($0.occurredAt) }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
    }

    /// Ritmo del gasto variable: lo gastado este mes sin pagos fijos dividido por el día del mes (mínimo 1).
    static func variablePace(entries: [EntryRecord], now: Date, calendar: Calendar) -> Int64 {
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        let day = max(1, calendar.component(.day, from: now))
        return variableSpent(entries, in: month) / Int64(day)
    }

    /// Te quedan − ritmo × días que faltan (los dos salen de `monthSummary`).
    static func endOfMonth(entries: [EntryRecord], recurring: [RecurringRecord], now: Date, calendar: Calendar) -> EndOfMonthForecast {
        let summary = BalanceCalculator.monthSummary(entries: entries, recurring: recurring, now: now, calendar: calendar)
        let pace = variablePace(entries: entries, now: now, calendar: calendar)
        return EndOfMonthForecast(summary: summary, paceMinor: pace,
                                  projectedMinor: summary.remainingMinor - pace * Int64(summary.daysLeft))
    }

    static func projectedEndOfMonth(entries: [EntryRecord], recurring: [RecurringRecord], now: Date, calendar: Calendar) -> Int64 {
        endOfMonth(entries: entries, recurring: recurring, now: now, calendar: calendar).projectedMinor
    }

    /// Promedio del gasto variable de los últimos `months` meses completos que tienen datos (busca hasta 12 atrás).
    /// Nil si ninguno tiene.
    static func variableAverage(entries: [EntryRecord], now: Date, calendar: Calendar, months: Int = 3, lookBack: Int = 12) -> Int64? {
        let current = CycleMath.startOfMonth(now, calendar)
        var totals: [Int64] = []
        for offset in 1...max(1, lookBack) {
            guard totals.count < months, let start = calendar.date(byAdding: .month, value: -offset, to: current) else { break }
            let total = variableSpent(entries, in: BalanceCalculator.monthInterval(containing: start, calendar: calendar))
            if total > 0 { totals.append(total) }
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(0, +) / Int64(totals.count)
    }

    /// Los `count` meses siguientes al de `now`: ingresos fijos, gastos fijos (con fecha final y cuotas) y gasto
    /// variable estimado (promedio de los últimos 3 meses con datos; si no hay, ritmo de este mes × días del mes).
    static func nextMonths(_ count: Int = 3, entries: [EntryRecord], recurring: [RecurringRecord], now: Date, calendar: Calendar) -> [MonthForecast] {
        let current = CycleMath.startOfMonth(now, calendar)
        let history = variableAverage(entries: entries, now: now, calendar: calendar)
        let pace = variablePace(entries: entries, now: now, calendar: calendar)
        return (1...max(1, count)).compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: offset, to: current) else { return nil }
            let month = BalanceCalculator.monthInterval(containing: start, calendar: calendar)
            var income: Int64 = 0
            var expense: Int64 = 0
            for item in recurring {
                let times = Int64(BalanceCalculator.pendingOccurrences(of: item, in: month, calendar: calendar).count)
                if item.kind == .ingreso { income += times * item.amountMinor } else { expense += times * item.amountMinor }
            }
            let variable = history ?? pace * Int64(CycleMath.daysInMonth(start, calendar))
            return MonthForecast(month: start, fixedIncomeMinor: income, fixedExpenseMinor: expense,
                                 variableMinor: variable, variableFromHistory: history != nil)
        }
    }

    /// "A este ritmo terminas el mes en − $ X", solo si la proyección es negativa.
    static func alertText(projectedMinor: Int64, currency: Currency) -> String? {
        guard projectedMinor < 0 else { return nil }
        return "A este ritmo terminas el mes en \(Money(minor: projectedMinor, currency: currency).formatted())"
    }

    /// Texto de la tarjeta "Así vas a terminar": la alerta si es negativa, o "Te sobrarían $ X".
    static func projectionText(projectedMinor: Int64, currency: Currency) -> String {
        alertText(projectedMinor: projectedMinor, currency: currency)
            ?? "A este ritmo te sobran \(Money(minor: projectedMinor, currency: currency).formatted()) al final del mes"
    }

    /// "Gastas unos $ 50.000 al día sin contar los fijos".
    static func paceText(paceMinor: Int64, currency: Currency) -> String {
        paceMinor > 0
            ? "Gastas unos \(Money(minor: paceMinor, currency: currency).formatted()) al día sin contar los fijos"
            : "Aún no tienes gastos variables este mes"
    }
}
