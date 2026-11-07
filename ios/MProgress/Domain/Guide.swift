import Foundation

/// Primeros pasos de Inicio ("Saca todo el provecho a MProgress"): ocho pasos que se marcan solos con los datos
/// reales, para que cada función se descubra sin tener que buscarla. Funciones puras; la tarjeta solo lee esto.
/// Igual que domain/Guide.kt de Android.
enum GuideStepId: String, CaseIterable, Hashable, Sendable {
    case primerosDatos, bancos, automatico, limites, ahorro, avisos, bloqueo, cuenta
}

/// Lo que hay en la app y en el teléfono, leído por la tarjeta cada vez que cambia algo.
struct GuideSnapshot: Hashable, Sendable {
    /// Un ingreso fijo activo o un ingreso anotado.
    var hasIncome = false
    /// Un gasto fijo activo.
    var hasFixedExpense = false
    /// Un gasto anotado.
    var hasExpense = false
    /// Un banco o billetera en Dinero.
    var hasInstitution = false
    /// Lo mismo que Ajustes muestra como "Configurado" en el registro automático.
    var autoCaptureConfigured = false
    var hasBudget = false
    var hasGoal = false
    /// Permiso de notificaciones del sistema.
    var notificationsAllowed = false
    /// Al menos un pago fijo que avisa (aviso general prendido o uno personalizado).
    var hasReminder = false
    var lockEnabled = false
    var signedIn = false
}

/// Las tres partes del primer paso.
struct GuidePart: Hashable, Sendable, Identifiable {
    enum Kind: String, CaseIterable, Sendable { case ingreso, fijo, gasto }
    var kind: Kind
    var title: String
    var done: Bool
    var id: Kind { kind }
}

struct GuideStep: Hashable, Sendable, Identifiable {
    var id: GuideStepId
    var title: String
    /// Cómo se nombra en la línea "Y 2 más: …".
    var shortTitle: String
    /// SF Symbol de la baldosa.
    var symbol: String
    var done: Bool
}

enum GuideVisibility: Hashable, Sendable {
    case hidden, checklist, celebration
}

enum Guide {
    /// En este dispositivo: la persona ocultó la tarjeta con la X.
    static let dismissedKey = "guia.oculta"
    /// En este dispositivo: ya se vio "Listo, ya usas todo MProgress".
    static let celebratedKey = "guia.celebrada"
    /// En este dispositivo: la tarjeta está plegada.
    static let collapsedKey = "guia.plegada"
    /// En este dispositivo: el primer paso hecho se ve abierto con sus tres partes.
    static let firstStepOpenKey = "guia.primerPasoAbierto"

    static let title = "Saca todo el provecho a MProgress"
    static let celebrationTitle = "Listo, ya usas todo MProgress"
    static let celebrationText = "Ya tienes todo a la mano. Si algo cambia, lo encuentras en Ajustes."
    static let hideQuestion = "¿Ocultar los primeros pasos?"
    static let hideMessage = "Los encuentras en Ajustes"
    static let settingsTitle = "Primeros pasos"
    static let settingsValue = "Mostrar en Inicio"
    /// Cuántos pasos pendientes se ven; el resto va en "Y 2 más: …".
    static let visiblePending = 3
    /// Segundos que se ve la celebración antes de irse sola.
    static let celebrationSeconds = 4

    static func parts(_ s: GuideSnapshot) -> [GuidePart] {
        [
            GuidePart(kind: .ingreso, title: "Tu ingreso", done: s.hasIncome),
            GuidePart(kind: .fijo, title: "Tus fijos", done: s.hasFixedExpense),
            GuidePart(kind: .gasto, title: "Tu primer gasto", done: s.hasExpense),
        ]
    }

    /// La primera parte que falta del primer paso: a dónde lleva tocarlo.
    static func nextPart(_ s: GuideSnapshot) -> GuidePart.Kind? {
        parts(s).first { !$0.done }?.kind
    }

    /// Los ocho pasos, siempre en el mismo orden.
    static func steps(_ s: GuideSnapshot) -> [GuideStep] {
        GuideStepId.allCases.map { id in
            switch id {
            case .primerosDatos:
                GuideStep(id: id, title: "Anota tu ingreso, tus fijos y tu primer gasto", shortTitle: "tus primeros movimientos",
                          symbol: "plus", done: s.hasIncome && s.hasFixedExpense && s.hasExpense)
            case .bancos:
                GuideStep(id: id, title: "Agrega tus bancos y tarjetas", shortTitle: "bancos y tarjetas",
                          symbol: "building.columns", done: s.hasInstitution)
            case .automatico:
                GuideStep(id: id, title: "Activa el registro automático", shortTitle: "registro automático",
                          symbol: "wand.and.stars", done: s.autoCaptureConfigured)
            case .limites:
                GuideStep(id: id, title: "Ponle un límite a una categoría", shortTitle: "límites",
                          symbol: "gauge.with.dots.needle.33percent", done: s.hasBudget)
            case .ahorro:
                GuideStep(id: id, title: "Crea una meta de ahorro", shortTitle: "meta de ahorro",
                          symbol: "target", done: s.hasGoal)
            case .avisos:
                GuideStep(id: id, title: "Activa los avisos de tus cobros", shortTitle: "avisos",
                          symbol: "bell", done: s.notificationsAllowed && s.hasReminder)
            case .bloqueo:
                GuideStep(id: id, title: "Protege la app con huella o rostro", shortTitle: "bloqueo",
                          symbol: "faceid", done: s.lockEnabled)
            case .cuenta:
                GuideStep(id: id, title: "Crea tu cuenta para tener todo cifrado en la nube", shortTitle: "cuenta en la nube",
                          symbol: "icloud", done: s.signedIn)
            }
        }
    }

    static func doneCount(_ steps: [GuideStep]) -> Int { steps.filter(\.done).count }

    /// "3 de 8"
    static func progressText(_ steps: [GuideStep]) -> String { "\(doneCount(steps)) de \(steps.count)" }

    /// De 0 a 1, para la barra.
    static func progress(_ steps: [GuideStep]) -> Double {
        steps.isEmpty ? 0 : Double(doneCount(steps)) / Double(steps.count)
    }

    /// Los primeros pasos pendientes que se ven en la tarjeta (3).
    static func visiblePendingSteps(_ steps: [GuideStep], limit: Int = visiblePending) -> [GuideStep] {
        Array(steps.filter { !$0.done }.prefix(max(0, limit)))
    }

    /// "Y 2 más: avisos y cuenta en la nube", o nil si no queda nada escondido.
    static func moreText(_ steps: [GuideStep], limit: Int = visiblePending) -> String? {
        let rest = steps.filter { !$0.done }.dropFirst(max(0, limit)).map(\.shortTitle)
        guard !rest.isEmpty else { return nil }
        return "Y \(rest.count) más: \(joined(Array(rest)))"
    }

    /// Debajo del primer paso: lo que falta ("Te falta: tus fijos y tu primer gasto") o, hecho, las tres partes.
    static func firstStepSubtitle(_ s: GuideSnapshot) -> String {
        let missing = parts(s).filter { !$0.done }.map { $0.title.lowercased() }
        guard !missing.isEmpty else { return "Ingreso, fijos y primer gasto anotados" }
        return "Te falta: \(joined(missing))"
    }

    static func visibility(_ steps: [GuideStep], dismissed: Bool, celebrated: Bool) -> GuideVisibility {
        if dismissed { return .hidden }
        if doneCount(steps) == steps.count { return celebrated ? .hidden : .celebration }
        return .checklist
    }

    /// Hay al menos un pago fijo activo que avisa. `modes` trae el aviso de cada uno (nil si no tiene aviso propio):
    /// sin aviso propio o "Como el general" avisa si el general está prendido; "Sin aviso" nunca.
    static func hasReminder(modes: [ReminderMode?], generalEnabled: Bool) -> Bool {
        modes.contains { mode in
            switch mode ?? .general {
            case .general: generalEnabled
            case .personalizado: true
            case .ninguno: false
            }
        }
    }

    /// "a", "a y b", "a, b y c".
    static func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " y " + items[items.count - 1]
        }
    }
}
