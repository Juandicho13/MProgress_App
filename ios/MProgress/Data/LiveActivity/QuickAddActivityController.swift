import Foundation
import ActivityKit
import UIKit

/// Inicia, cambia y cierra la Live Activity del registro rápido. Solo hay una a la vez: si ya hay una,
/// se actualiza (iniciar otra desde el fondo puede fallar con "Target is not foreground").
/// Funciones sin actor a propósito: ActivityKit no necesita el hilo principal.
enum QuickAddActivityController {
    /// Muestra el movimiento recién anotado. Devuelve false si no se pudo (Live Activities apagadas).
    @discardableResult
    static func show(_ state: QuickAddAttributes.ContentState) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(QuickAddMath.liveSeconds))
        let current = Activity<QuickAddAttributes>.activities
        if let first = current.first {
            await first.update(content)
            for extra in current.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            return true
        }
        do {
            _ = try Activity.request(attributes: QuickAddAttributes(), content: content, pushType: nil)
            return true
        } catch {
            return false
        }
    }

    /// Cierra la actividad si todavía muestra ese movimiento (si llegó otro después, sigue).
    static func end(ifShowing entryId: String) async {
        for activity in Activity<QuickAddAttributes>.activities where activity.content.state.entryId == entryId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Deshacer: muestra "Deshecho" y la cierra.
    static func markUndone(_ entryId: String) async {
        for activity in Activity<QuickAddAttributes>.activities where activity.content.state.entryId == entryId {
            var state = activity.content.state
            state.undone = true
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    /// Cierra las que ya pasaron sus 8 segundos (por si la app se suspendió antes de cerrarlas).
    static func endStale(now: Date = .now) async {
        for activity in Activity<QuickAddAttributes>.activities {
            if let stale = activity.content.staleDate, stale <= now {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

/// Pide a iOS unos segundos más en segundo plano para cerrar la actividad a los 8 segundos,
/// aunque el intent ya haya terminado.
@MainActor
final class QuickAddBackgroundHold {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    /// Espera los segundos de la Live Activity y la cierra si sigue mostrando ese movimiento.
    static func closeLater(entryId: String) {
        let hold = QuickAddBackgroundHold()
        hold.identifier = UIApplication.shared.beginBackgroundTask(withName: "registro-rapido") {
            // iOS llama esto en el hilo principal cuando se acaba el tiempo.
            MainActor.assumeIsolated { hold.finish() }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(QuickAddMath.liveSeconds))
            await QuickAddActivityController.end(ifShowing: entryId)
            hold.finish()
        }
    }

    private func finish() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
