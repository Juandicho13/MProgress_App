import Foundation

/// La pastilla de sincronización de Inicio (F10-04, pantalla 36). Solo sale con cuenta; sin cuenta no hay nada que mostrar.
enum SyncPill: Equatable, Sendable {
    case alDia
    case sincronizando
    case sinConexion(pending: Int)
    case error

    /// El estado a partir de lo que se sabe. Orden: sin conexión, sincronizando, error, pendientes por subir, al día.
    static func state(signedIn: Bool, online: Bool, running: Bool, pending: Int, failed: Int, hasError: Bool) -> SyncPill? {
        guard signedIn else { return nil }
        if !online { return .sinConexion(pending: max(0, pending)) }
        if running { return .sincronizando }
        if failed > 0 || hasError { return .error }
        if pending > 0 { return .sincronizando }
        return .alDia
    }

    /// "Al día", "Sincronizando…", "Sin conexión · 3 pendientes", "Error al sincronizar".
    var text: String {
        switch self {
        case .alDia: "Al día"
        case .sincronizando: "Sincronizando…"
        case .sinConexion(let pending):
            pending == 0 ? "Sin conexión" : "Sin conexión · \(pending) \(pending == 1 ? "pendiente" : "pendientes")"
        case .error: "Error al sincronizar"
        }
    }

    /// SF Symbol de la pastilla.
    var symbol: String {
        switch self {
        case .alDia: "checkmark.icloud"
        case .sincronizando: "arrow.clockwise.icloud"
        case .sinConexion: "icloud.slash"
        case .error: "exclamationmark.icloud"
        }
    }
}

/// Textos de la hoja "Estado de sincronización" (F10-04, pantalla 37). Iguales en Android (`domain/SyncStatusText.kt`).
enum SyncText {
    /// "Hace un momento", "Hace 2 min", "Hace 3 h", "Ayer", "Hace 4 días". Sin fecha: "Todavía no".
    static func relative(_ date: Date?, now: Date) -> String {
        guard let date else { return "Todavía no" }
        let minutes = Int(max(0, now.timeIntervalSince(date)) / 60)
        if minutes < 1 { return "Hace un momento" }
        if minutes < 60 { return "Hace \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "Hace \(hours) h" }
        let days = hours / 24
        return days == 1 ? "Ayer" : "Hace \(days) días"
    }

    static func connection(online: Bool) -> String { online ? "Conectado" : "Sin conexión" }

    /// Orden en que se nombran los pendientes: primero lo que más se ve.
    static let displayOrder = ["entries", "recurring", "transfers", "products", "institutions", "budgets", "savings_goals",
                               "goal_contributions", "reminders", "categories", "merchant_alias", "debts", "debt_payments", "reward_programs", "splits", "spaces"]

    /// "movimiento" o "movimientos", "pago fijo" o "pagos fijos".
    static func noun(_ table: String, count: Int) -> String {
        let one = count == 1
        switch table {
        case "entries": return one ? "movimiento" : "movimientos"
        case "recurring": return one ? "pago fijo" : "pagos fijos"
        case "transfers": return one ? "transferencia" : "transferencias"
        case "products": return one ? "cuenta o tarjeta" : "cuentas o tarjetas"
        case "institutions": return one ? "banco" : "bancos"
        case "budgets": return one ? "límite" : "límites"
        case "savings_goals": return one ? "meta de ahorro" : "metas de ahorro"
        case "goal_contributions": return one ? "aporte" : "aportes"
        case "reminders": return one ? "aviso" : "avisos"
        case "categories": return one ? "categoría" : "categorías"
        case "merchant_alias": return one ? "nombre de comercio" : "nombres de comercios"
        case "debts": return one ? "deuda" : "deudas"
        case "debt_payments": return one ? "abono" : "abonos"
        case "reward_programs": return one ? "programa de puntos" : "programas de puntos"
        case "splits": return one ? "división" : "divisiones"
        case "spaces": return one ? "ajuste de la cuenta" : "ajustes de la cuenta"
        default: return one ? "cambio" : "cambios"
        }
    }

    /// "3 movimientos, 1 pago fijo". Sin nada: "Nada pendiente".
    static func pendingSummary(_ counts: [String: Int]) -> String {
        let known = displayOrder.filter { (counts[$0] ?? 0) > 0 }
        let others = counts.keys.filter { !displayOrder.contains($0) && (counts[$0] ?? 0) > 0 }.sorted()
        let parts = (known + others).map { table -> String in
            let count = counts[table] ?? 0
            return "\(count) \(noun(table, count: count))"
        }
        return parts.isEmpty ? "Nada pendiente" : parts.joined(separator: ", ")
    }

    /// Los que no subieron después de 3 intentos, en palabras.
    static func failedText(_ failed: Int) -> String? {
        guard failed > 0 else { return nil }
        return failed == 1
            ? "1 cambio no subió después de 3 intentos."
            : "\(failed) cambios no subieron después de 3 intentos."
    }

    /// Error que no es de la red ni de la nube (por ejemplo, un fallo al leer una fila).
    static let genericError = "No se pudo sincronizar. Tus cambios siguen guardados en este dispositivo."
    static let missingKeyError = "Este dispositivo no tiene la llave de tu cuenta. Apruébalo desde tu otro dispositivo."
    static let offlineNote = "Todo queda guardado en este dispositivo y se sube solo cuando vuelva el internet."
}

/// Espera antes de reintentar después de un error de la nube (no de conexión: sin internet se espera a que vuelva).
/// Crece y se queda en 5 minutos, así nunca gira en vacío.
enum SyncBackoff {
    static let steps: [TimeInterval] = [5, 15, 30, 60, 120, 300]

    static func delay(failures: Int) -> TimeInterval {
        steps[min(max(failures, 1), steps.count) - 1]
    }
}
