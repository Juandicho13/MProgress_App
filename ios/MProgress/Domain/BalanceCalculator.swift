import Foundation

/// Cálculos del mes (HANDOFF 8.2). Funciones puras: entran valores, salen valores.
enum BalanceCalculator {
    static func monthInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let start = CycleMath.startOfMonth(date, calendar)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// Fechas de un pago fijo que todavía no se han pagado dentro del mes.
    static func pendingOccurrences(of item: RecurringRecord, in month: DateInterval, calendar: Calendar) -> [Date] {
        guard item.active else { return [] }
        let last = month.end.addingTimeInterval(-1)
        let dates = CycleMath.occurrences(from: item.nextDate, through: last, cycle: item.cycle, anchor: item.anchor, calendar: calendar)
        return dates.filter { $0 >= month.start }
    }

    static func monthSummary(entries: [EntryRecord], recurring: [RecurringRecord], now: Date, calendar: Calendar) -> MonthSummary {
        let month = monthInterval(containing: now, calendar: calendar)
        let inMonth = entries.filter { month.contains($0.occurredAt) }

        let registeredIncome = inMonth.filter { $0.kind == .ingreso }.reduce(Int64(0)) { $0 + $1.amountMinor }
        let spent = inMonth.filter { $0.kind == .gasto }.reduce(Int64(0)) { $0 + $1.amountMinor }

        var pendingIncome: Int64 = 0
        var pendingExpense: Int64 = 0
        for item in recurring {
            let count = Int64(pendingOccurrences(of: item, in: month, calendar: calendar).count)
            if item.kind == .ingreso {
                pendingIncome += count * item.amountMinor
            } else {
                pendingExpense += count * item.amountMinor
            }
        }

        let expectedIncome = registeredIncome + pendingIncome
        let remaining = expectedIncome - spent - pendingExpense
        let ratio = expectedIncome > 0 ? min(1, max(0, Double(spent) / Double(expectedIncome))) : (spent > 0 ? 1 : 0)
        let lastDay = month.end.addingTimeInterval(-1)
        let daysLeft = max(0, Urgency.dayDifference(from: now, to: lastDay, calendar: calendar))

        return MonthSummary(
            expectedIncomeMinor: expectedIncome,
            spentMinor: spent,
            pendingFixedMinor: pendingExpense,
            remainingMinor: remaining,
            spentRatio: ratio,
            daysLeft: daysLeft
        )
    }

    /// Próximos cobros ordenados por fecha, con su urgencia.
    static func upcoming(recurring: [RecurringRecord], now: Date, calendar: Calendar, kind: EntryKind? = .gasto, limit: Int = 20) -> [UpcomingCharge] {
        recurring
            .filter { $0.active && (kind == nil || $0.kind == kind) }
            .map { item in
                UpcomingCharge(
                    recurringId: item.id,
                    name: item.name,
                    kind: item.kind,
                    amountMinor: item.amountMinor,
                    date: item.nextDate,
                    urgency: Urgency.of(due: item.nextDate, now: now, calendar: calendar),
                    daysLeft: Urgency.dayDifference(from: now, to: item.nextDate, calendar: calendar)
                )
            }
            .sorted { ($0.date, $0.name) < ($1.date, $1.name) }
            .prefix(limit)
            .map { $0 }
    }

    /// Gasto por categoría en un intervalo, de mayor a menor. La clave nil son los gastos sin categoría.
    static func spendingByCategory(entries: [EntryRecord], in interval: DateInterval) -> [(categoryId: UUID?, totalMinor: Int64)] {
        var totals: [UUID?: Int64] = [:]
        for entry in entries where entry.kind == .gasto && interval.contains(entry.occurredAt) {
            totals[entry.categoryId, default: 0] += entry.amountMinor
        }
        return totals
            .map { (categoryId: $0.key, totalMinor: $0.value) }
            .sorted { $0.totalMinor > $1.totalMinor }
    }

    /// Gasto total de cada uno de los `months` meses anteriores al mes de `now` (del más viejo al más nuevo).
    static func monthlyExpenses(entries: [EntryRecord], now: Date, months: Int, calendar: Calendar) -> [Int64] {
        let current = CycleMath.startOfMonth(now, calendar)
        return (1...max(1, months)).reversed().map { offset in
            let start = calendar.date(byAdding: .month, value: -offset, to: current) ?? current
            let interval = monthInterval(containing: start, calendar: calendar)
            return entries
                .filter { $0.kind == .gasto && interval.contains($0.occurredAt) }
                .reduce(Int64(0)) { $0 + $1.amountMinor }
        }
    }

    /// "Tu mes normal": mediana del gasto de los últimos 12 meses que tienen datos. Nil si no hay.
    static func normalMonth(entries: [EntryRecord], now: Date, calendar: Calendar) -> Int64? {
        let totals = monthlyExpenses(entries: entries, now: now, months: 12, calendar: calendar).filter { $0 > 0 }.sorted()
        guard !totals.isEmpty else { return nil }
        let middle = totals.count / 2
        if totals.count % 2 == 1 { return totals[middle] }
        return (totals[middle - 1] + totals[middle]) / 2
    }
}

/// Saldos de bancos, tarjetas y bolsillos (HANDOFF 8.2).
enum MoneyCalculator {
    /// Saldo actual. Cuentas, bolsillos y efectivo: lo que hay. Crédito: lo que se debe.
    /// Los gastos con una tarjeta débito salen de su cuenta (parentProductId).
    static func currentBalance(of product: ProductRecord, products: [ProductRecord], entries: [EntryRecord], transfers: [TransferRecord]) -> Int64 {
        let debitCards = Set(products.filter { $0.kind == .debito && $0.parentProductId == product.id }.map(\.id))
        var balance = product.balanceMinor

        for entry in entries where entry.occurredAt > product.balanceAt {
            guard let productId = entry.productId, productId == product.id || debitCards.contains(productId) else { continue }
            if product.kind.isDebt {
                balance -= entry.signedMinor
            } else {
                balance += entry.signedMinor
            }
        }

        for transfer in transfers where transfer.occurredAt > product.balanceAt {
            if transfer.fromProductId == product.id {
                balance += product.kind.isDebt ? transfer.amountMinor : -transfer.amountMinor
            }
            if transfer.toProductId == product.id {
                balance += product.kind.isDebt ? -transfer.amountMinor : transfer.amountMinor
            }
        }
        return balance
    }

    /// Patrimonio neto: lo que tienes menos lo que debes, sin contar lo oculto.
    static func netWorth(products: [ProductRecord], entries: [EntryRecord], transfers: [TransferRecord]) -> (have: Int64, owe: Int64, net: Int64) {
        var have: Int64 = 0
        var owe: Int64 = 0
        for product in products where !product.hidden && product.kind != .debito {
            let balance = currentBalance(of: product, products: products, entries: entries, transfers: transfers)
            if product.kind.isDebt {
                owe += balance
            } else {
                have += balance
            }
        }
        return (have, owe, have - owe)
    }

    /// Rendimiento aproximado de un mes para una cajita con tasa efectiva anual.
    static func monthlyYield(balanceMinor: Int64, rateEA: Decimal?) -> Int64 {
        guard let rateEA, balanceMinor > 0 else { return 0 }
        let rate = NSDecimalNumber(decimal: rateEA).doubleValue / 100
        guard rate > 0 else { return 0 }
        let monthly = pow(1 + rate, 1.0 / 12.0) - 1
        return Int64((Double(balanceMinor) * monthly).rounded())
    }
}
