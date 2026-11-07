import Foundation

/// Revisión del sueldo en Inicio (PLAN_F12B Paso 4): un ingreso fijo de menos de 1.000 unidades de la moneda
/// casi siempre es un error al escribirlo ($ 2 en vez de $ 2.000.000). Funciones puras.
enum IncomeCheck {
    /// Menos de esto, en unidades de la moneda, se pregunta.
    static let thresholdUnits: Int64 = 1_000
    /// Los arreglos que se ofrecen: por mil y por un millón.
    static let factors: [Int64] = [1_000, 1_000_000]
    /// Dónde se guardan, en este dispositivo, los ingresos que la persona dijo que están bien.
    static let storageKey = "inicio.ingresosRevisados"

    /// Ingresos fijos activos con un monto sospechoso que la persona no ha confirmado.
    static func suspicious(_ recurring: [RecurringRecord], currency: Currency, dismissed: Set<UUID>) -> [RecurringRecord] {
        recurring.filter {
            $0.active && $0.kind == .ingreso && $0.amountMinor > 0
                && $0.amountMinor < thresholdUnits * currency.minorPerUnit && !dismissed.contains($0.id)
        }
    }

    /// "¿Tu sueldo es $ 2?"
    static func question(name: String, amountMinor: Int64, currency: Currency) -> String {
        "¿Tu \(phrase(name)) es \(Money(minor: amountMinor, currency: currency).formatted())?"
    }

    /// "Es $ 2.000"
    static func fixTitle(amountMinor: Int64, factor: Int64, currency: Currency) -> String {
        "Es \(Money(minor: amountMinor * factor, currency: currency).formatted())"
    }

    /// El nombre dentro de la frase: con minúscula inicial, salvo siglas ("SENA").
    static func phrase(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "ingreso" }
        let firstWord = String(trimmed.prefix { !$0.isWhitespace })
        if firstWord.count > 1 && firstWord == firstWord.uppercased() && firstWord != firstWord.lowercased() { return trimmed }
        return first.lowercased() + String(trimmed.dropFirst())
    }

    /// Movimientos que nacieron de este ingreso fijo con el monto mal escrito: los enlazados a él, o los que
    /// no tienen enlace pero se llaman igual (el sueldo que se anota al configurar la app). Se arreglan junto
    /// con el pago fijo para que "Te quedan" cambie de una vez.
    static func entriesToFix(_ entries: [EntryRecord], recurring: RecurringRecord, oldAmountMinor: Int64) -> [UUID] {
        entries.filter { entry in
            entry.kind == recurring.kind && entry.amountMinor == oldAmountMinor
                && (entry.recurringId == recurring.id || (entry.recurringId == nil && sameName(entry.name, recurring.name)))
        }.map(\.id)
    }

    /// Un movimiento que quedó con el monto viejo cuando el pago fijo ya se arregló (por mil o por un millón).
    struct StaleEntry: Hashable, Sendable, Identifiable {
        var id: UUID { entryId }
        var entryId: UUID
        var name: String
        var amountMinor: Int64
        var fixedAmountMinor: Int64
    }

    /// Movimientos de ingreso con un monto sospechoso cuyo pago fijo ya tiene ese monto por mil o por un millón.
    static func staleEntries(_ entries: [EntryRecord], recurring: [RecurringRecord], currency: Currency,
                             dismissed: Set<UUID>) -> [StaleEntry] {
        let limit = thresholdUnits * currency.minorPerUnit
        return entries.compactMap { entry in
            guard entry.kind == .ingreso, entry.amountMinor > 0, entry.amountMinor < limit,
                  !dismissed.contains(entry.id) else { return nil }
            let fixed = recurring.first { item in
                item.kind == .ingreso
                    && (entry.recurringId == item.id || (entry.recurringId == nil && sameName(entry.name, item.name)))
                    && factors.contains { entry.amountMinor * $0 == item.amountMinor }
            }
            guard let fixed else { return nil }
            return StaleEntry(entryId: entry.id, name: entry.name, amountMinor: entry.amountMinor,
                              fixedAmountMinor: fixed.amountMinor)
        }
    }

    /// "Sueldo" y " sueldo " son el mismo nombre.
    static func sameName(_ a: String, _ b: String) -> Bool {
        let clean = { (s: String) in s.trimmingCharacters(in: .whitespaces).lowercased() }
        return !clean(a).isEmpty && clean(a) == clean(b)
    }

    /// Lee los ids guardados (separados por coma).
    static func dismissed(from stored: String) -> Set<UUID> {
        Set(stored.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    /// Guarda los ids en orden, separados por coma.
    static func stored(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }
}

/// Próximos cargos de Inicio plegables: 3 cerrados, hasta 20 abiertos.
enum UpcomingFold {
    static let collapsedCount = 3
    static let expandedLimit = 20
    /// Dónde se guarda, en este dispositivo, si la lista quedó abierta.
    static let storageKey = "inicio.proximosAbiertos"

    static func visible<T>(_ items: [T], expanded: Bool) -> [T] {
        Array(items.prefix(expanded ? expandedLimit : collapsedCount))
    }

    /// "Ver todos (5)" o "Ver menos"; nil si caben todos cerrados.
    static func toggleTitle(total: Int, expanded: Bool) -> String? {
        guard total > collapsedCount else { return nil }
        return expanded ? "Ver menos" : "Ver todos (\(total))"
    }
}
