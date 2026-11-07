import Foundation

/// Reglas y textos del registro rápido sin abrir la app (PLAN_F12B Paso 3, iPhone).
enum QuickAddMath {
    /// Cuánto dura la Live Activity en la isla dinámica antes de cerrarse sola.
    static let liveSeconds: Double = 8

    /// Monto que dicta Siri o escribe la persona ("20 mil" llega como 20000) en unidades mínimas.
    /// Nil si no es un monto válido (cero, negativo o absurdo).
    static func minor(fromUnits value: Double, currency: Currency) -> Int64? {
        guard value.isFinite, value > 0, value < 1_000_000_000_000 else { return nil }
        let minor = Int64((value * Double(currency.minorPerUnit)).rounded())
        return minor > 0 ? minor : nil
    }

    /// "− $ 84.300" para un gasto, "+ $ 50.000" para un ingreso.
    static func amountText(kind: EntryKind, amountMinor: Int64, currency: Currency) -> String {
        Money(minor: kind == .ingreso ? amountMinor : -amountMinor, currency: currency).formatted(sign: true)
    }

    /// "te quedan $ 1.901.100" o, si ya no queda, "te pasaste $ 20.000".
    static func remainingText(_ remainingMinor: Int64, currency: Currency) -> String {
        if remainingMinor < 0 { return "te pasaste \(Money(minor: -remainingMinor, currency: currency).formatted())" }
        return "te quedan \(Money(minor: remainingMinor, currency: currency).formatted())"
    }

    /// La línea de la isla dinámica: "− $ 84.300 · te quedan $ 1.901.100".
    static func liveLine(amountText: String, remainingText: String) -> String {
        "\(amountText) · \(remainingText)"
    }

    /// Nombre del movimiento: lo que dijo la persona ("almuerzo" pasa a "Almuerzo") o "Gasto rápido".
    static func name(kind: EntryKind, concept: String?) -> String {
        let clean = concept?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clean.isEmpty else { return kind == .ingreso ? "Ingreso rápido" : "Gasto rápido" }
        return String(clean.prefix(60)).capitalizedFirstLetter
    }

    /// Productos que se ofrecen: un gasto sale de tarjetas, cuentas y efectivo; un ingreso entra a cuentas,
    /// bolsillos, cajitas y efectivo. Lo oculto también se ofrece (ocultar es solo para los saldos).
    static func offers(_ kind: ProductKind, for entry: EntryKind) -> Bool {
        entry == .gasto ? kind != .bolsillo && kind != .cajita : kind != .credito && kind != .debito
    }
}

private extension String {
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}
