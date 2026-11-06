import Foundation
import ActivityKit
import AppIntents

/// Live Activity corta del registro rápido (PLAN_F12B Paso 3): "− $ 84.300 · te quedan $ 1.901.100" con Deshacer.
/// Vive en Shared porque la usan la app (la inicia y la cierra) y la extensión de widgets (la dibuja).
struct QuickAddAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// Movimiento recién guardado: es el que deshace el botón.
        var entryId: String
        /// "− $ 84.300" o "+ $ 50.000".
        var amountText: String
        /// "te quedan $ 1.901.100".
        var remainingText: String
        /// Nombre del movimiento: "Gasto rápido", "Almuerzo".
        var name: String
        var isIncome: Bool
        var remainingIsNegative: Bool
        /// Ya se deshizo: se muestra "Deshecho" mientras se cierra.
        var undone: Bool = false
    }
}

/// "Deshacer" de la Live Activity. Al tocarlo, el sistema corre este intent en el proceso de la app
/// (por ser LiveActivityIntent), que borra el movimiento y cierra la actividad.
struct UndoQuickAddIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Deshacer registro rápido"
    static let description = IntentDescription("Borra el último movimiento anotado con el registro rápido.")
    static let isDiscoverable = false

    @Parameter(title: "Movimiento")
    var entryId: String

    init() {}

    init(entryId: String) {
        self.entryId = entryId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await QuickAddUndo.run(entryId)
        return .result()
    }
}

/// Puente entre el intent (compilado también en la extensión) y la base de la app.
/// La app pone `handler` al arrancar; en la extensión queda vacío y no hace nada.
@MainActor
enum QuickAddUndo {
    static var handler: (@MainActor (UUID) async -> Void)?

    static func run(_ entryId: String) async {
        guard let id = UUID(uuidString: entryId) else { return }
        await handler?(id)
    }
}
