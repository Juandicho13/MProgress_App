import Foundation

/// Cuánto puede estar la app en segundo plano antes de pedir Face ID otra vez (como WhatsApp). Se guarda por dispositivo.
enum LockDelay: Int, Codable, Sendable, CaseIterable {
    case inmediatamente = 0
    case treintaSegundos = 30
    case unMinuto = 60

    static let storageKey = "seguridad.bloquearTras"

    var seconds: Int { rawValue }

    var title: String {
        switch self {
        case .inmediatamente: "Inmediatamente"
        case .treintaSegundos: "Después de 30 segundos"
        case .unMinuto: "Después de 1 minuto"
        }
    }

    /// Lo guardado, o Inmediatamente si no hay nada (o un valor que no se conoce).
    static func from(seconds: Int?) -> LockDelay {
        seconds.flatMap(LockDelay.init(rawValue:)) ?? .inmediatamente
    }
}

enum LockTimeout {
    /// Decide si al volver se pide desbloquear. `backgroundedAt` y `now` son segundos de un reloj que solo avanza
    /// (tiempo desde que prendió el teléfono). Sin hora de salida (arranque en frío) siempre se bloquea; si el reloj
    /// retrocedió (el teléfono se reinició) también.
    static func requiresAuth(backgroundedAt: Double?, now: Double, delay: LockDelay) -> Bool {
        guard let backgroundedAt else { return true }
        guard now >= backgroundedAt else { return true }
        return now - backgroundedAt >= Double(delay.seconds)
    }
}

extension LockTimeout {
    /// Igual, con el tiempo que pasó fuera ya medido. Nil: no se sabe cuándo salió (arranque en frío).
    static func requiresAuth(elapsedSeconds: Double?, delay: LockDelay) -> Bool {
        guard let elapsedSeconds else { return true }
        return requiresAuth(backgroundedAt: 0, now: elapsedSeconds, delay: delay)
    }
}
