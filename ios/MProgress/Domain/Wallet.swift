import Foundation

/// Forma de pago de un gasto con tarjeta (pantalla 34).
enum PayMethod: String, Codable, Sendable, CaseIterable {
    case applePay, fisica, enLinea

    var title: String {
        switch self {
        case .applePay: "Apple Pay"
        case .fisica: "Física"
        case .enLinea: "En línea"
        }
    }
}

/// Pago de tarjeta de crédito que se acerca.
struct CardDue: Hashable, Sendable {
    var productId: UUID
    var name: String
    var date: Date
    var debtMinor: Int64
    var urgency: Urgency
}

/// Resumen de un banco o billetera para la lista de Mi dinero (pantalla 31).
struct InstitutionTotals: Hashable, Sendable {
    /// Lo que hay en cuentas, bolsillos, cajitas y efectivo.
    var haveMinor: Int64
    /// Lo que se debe en tarjetas de crédito.
    var oweMinor: Int64
    /// Rendimiento aproximado del mes de los bolsillos y cajitas.
    var monthlyYieldMinor: Int64
    var netMinor: Int64 { haveMinor - oweMinor }
}

enum WalletMath {
    /// Totales de un banco con los saldos actuales de sus productos. Lo oculto no suma.
    static func totals(of institutionProducts: [ProductRecord], allProducts: [ProductRecord],
                       entries: [EntryRecord], transfers: [TransferRecord]) -> InstitutionTotals {
        var result = InstitutionTotals(haveMinor: 0, oweMinor: 0, monthlyYieldMinor: 0)
        for product in institutionProducts where !product.hidden && product.kind != .debito {
            let balance = MoneyCalculator.currentBalance(of: product, products: allProducts, entries: entries, transfers: transfers)
            if product.kind.isDebt {
                result.oweMinor += balance
            } else {
                result.haveMinor += balance
                if product.kind.earnsYield {
                    result.monthlyYieldMinor += MoneyCalculator.monthlyYield(balanceMinor: balance, rateEA: product.rateEA)
                }
            }
        }
        return result
    }

    /// "Ahorros · débito · 2 tarjetas de crédito", "Cuenta · 3 cajitas · tarjeta".
    static func subtitle(kinds: [ProductKind]) -> String {
        if kinds.isEmpty { return "Sin productos" }
        let count = { (kind: ProductKind) in kinds.filter { $0 == kind }.count }
        var parts: [String] = []
        let accounts = count(.cuenta)
        if accounts == 1 { parts.append("Cuenta") } else if accounts > 1 { parts.append("\(accounts) cuentas") }
        let pockets = count(.bolsillo)
        if pockets == 1 { parts.append("1 bolsillo") } else if pockets > 1 { parts.append("\(pockets) bolsillos") }
        let boxes = count(.cajita)
        if boxes == 1 { parts.append("1 cajita") } else if boxes > 1 { parts.append("\(boxes) cajitas") }
        let debit = count(.debito)
        if debit == 1 { parts.append("débito") } else if debit > 1 { parts.append("\(debit) débito") }
        let credit = count(.credito)
        if credit == 1 { parts.append("tarjeta de crédito") } else if credit > 1 { parts.append("\(credit) tarjetas de crédito") }
        let cash = count(.efectivo)
        if cash == 1 { parts.append("Billetera física") } else if cash > 1 { parts.append("Efectivo en \(cash) lugares") }
        return parts.joined(separator: " · ")
    }

    /// Nombres sugeridos para un efectivo nuevo (varios efectivos con nombre propio).
    static let cashSuggestions = ["Billetera", "Casa", "Alcancía", "Sobre", "Caja menor"]

    /// Nombre para un efectivo nuevo: la primera sugerencia que no se usa, o "Efectivo 2", "Efectivo 3"…
    static func nextCashName(existing: [String]) -> String {
        let used = Set(existing.map { $0.lowercased() })
        if let free = cashSuggestions.first(where: { !used.contains($0.lowercased()) }) { return free }
        var number = 2
        while used.contains("efectivo \(number)") { number += 1 }
        return "Efectivo \(number)"
    }

    /// Próximo día de pago de una tarjeta: hoy si cae hoy, si no el siguiente; el 31 cae el último día en meses cortos.
    static func nextDueDate(day: Int, now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        for offset in 0...1 {
            let month = calendar.date(byAdding: .month, value: offset, to: CycleMath.startOfMonth(today, calendar)) ?? today
            var parts = calendar.dateComponents([.year, .month], from: month)
            parts.day = min(max(1, day), CycleMath.daysInMonth(month, calendar))
            if let date = calendar.date(from: parts), date >= today { return date }
        }
        return today
    }

    /// Tarjetas de crédito con deuda cuyo pago cae en los próximos `within` días (F06-07).
    static func cardDues(products: [ProductRecord], entries: [EntryRecord], transfers: [TransferRecord],
                         now: Date, calendar: Calendar, within: Int = 7) -> [CardDue] {
        products.compactMap { product in
            guard product.kind == .credito, let day = product.dueDay else { return nil }
            let debt = MoneyCalculator.currentBalance(of: product, products: products, entries: entries, transfers: transfers)
            guard debt > 0 else { return nil }
            let date = nextDueDate(day: day, now: now, calendar: calendar)
            let days = Urgency.dayDifference(from: now, to: date, calendar: calendar)
            guard days <= within else { return nil }
            return CardDue(productId: product.id, name: product.name, date: date, debtMinor: debt,
                           urgency: Urgency.of(due: date, now: now, calendar: calendar))
        }
        .sorted { ($0.date, $0.name) < ($1.date, $1.name) }
    }

    /// Producto más usado en el mes de `now`: cuántos pagos y cuántos con Apple Pay.
    static func mostUsed(entries: [EntryRecord], methods: [UUID: PayMethod], now: Date, calendar: Calendar)
        -> (productId: UUID, count: Int, applePay: Int, totalMinor: Int64)? {
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        let used = entries.filter { $0.kind == .gasto && $0.productId != nil && month.contains($0.occurredAt) }
        let grouped = Dictionary(grouping: used) { $0.productId! }
        guard let best = grouped.max(by: { ($0.value.count, $0.value.reduce(0) { $0 + $1.amountMinor }) < ($1.value.count, $1.value.reduce(0) { $0 + $1.amountMinor }) }) else {
            return nil
        }
        let applePay = best.value.filter { methods[$0.id] == .applePay }.count
        return (best.key, best.value.count, applePay, best.value.reduce(0) { $0 + $1.amountMinor })
    }

    /// Productos que se pueden elegir en "¿Con qué pagaste?" según la pestaña.
    enum PayTab: String, CaseIterable, Sendable {
        case tarjeta, cuenta, efectivo

        var title: String {
            switch self {
            case .tarjeta: "Tarjeta"
            case .cuenta: "Cuenta"
            case .efectivo: "Efectivo"
            }
        }

        var kinds: Set<ProductKind> {
            switch self {
            case .tarjeta: [.credito, .debito]
            case .cuenta: [.cuenta, .bolsillo, .cajita]
            case .efectivo: [.efectivo]
            }
        }

        static func of(_ kind: ProductKind) -> PayTab {
            allCases.first { $0.kinds.contains(kind) } ?? .tarjeta
        }
    }

    /// Productos origen y destino válidos para transferir: todo menos las tarjetas débito (mueven la plata de su cuenta).
    static func transferable(_ products: [ProductRecord]) -> [ProductRecord] {
        products.filter { $0.kind != .debito }
    }
}
