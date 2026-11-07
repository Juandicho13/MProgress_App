import Foundation
import Network

/// Si hay internet (F10-04), con `NWPathMonitor`. Le avisa a la cuenta cada vez que cambia: sin conexión la pastilla lo
/// dice y, al volver, se sincroniza de una vez.
@MainActor
final class Connectivity {
    static let shared = Connectivity()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.olarte.mprogress.conectividad")
    private var started = false

    /// Empieza a escuchar una sola vez. `onChange` corre en el hilo principal con true si hay ruta a internet.
    func start(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = Self.handler(onChange)
        monitor.start(queue: queue)
    }

    /// El aviso de NWPathMonitor llega en su propia cola: el cierre se arma fuera del hilo principal para que Swift 6 no
    /// lo marque como del hilo principal (eso haría fallar la app al llamarlo desde la cola).
    nonisolated private static func handler(_ onChange: @escaping @MainActor @Sendable (Bool) -> Void) -> @Sendable (NWPath) -> Void {
        { path in
            let online = path.status == .satisfied
            Task { @MainActor in onChange(online) }
        }
    }
}
