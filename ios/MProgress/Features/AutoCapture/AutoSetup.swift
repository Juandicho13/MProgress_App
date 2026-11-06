import Foundation

/// Recuerda qué atajos ya funcionan en este iPhone. iOS no deja leer la configuración de Tocar atrás
/// ni las automatizaciones, así que se marca cuando el atajo llega a la app o cuando el usuario lo confirma.
enum AutoSetup: String, CaseIterable {
    case dobleToque, applePay, sms

    private var key: String { "auto.configurado.\(rawValue)" }

    /// Clave para leerla con @AppStorage (fecha como Double desde 2001).
    var storageKey: String { key }

    var isConfigured: Bool { UserDefaults.standard.double(forKey: key) > 0 }

    func mark(_ date: Date = .now) {
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: key)
    }

    func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
