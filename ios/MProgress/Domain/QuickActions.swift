import Foundation

/// Acciones del menú Más. El usuario las ordena y fija 3 como accesos rápidos en Inicio.
enum QuickActionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case gasto, ingreso, fijos, rapido, recibo

    var id: String { rawValue }

    /// Nombre en el menú Más.
    var title: String {
        switch self {
        case .gasto: "Gasto"
        case .ingreso: "Ingreso extra"
        case .fijos: "Pagos fijos"
        case .rapido: "Registro rápido"
        case .recibo: "Escanear recibo"
        }
    }

    /// Nombre corto para el botón de Inicio, que es angosto.
    var shortTitle: String {
        switch self {
        case .gasto: "Gasto"
        case .ingreso: "Ingreso"
        case .fijos: "Fijos"
        case .rapido: "Rápido"
        case .recibo: "Recibo"
        }
    }

    var symbol: String {
        switch self {
        case .gasto: "plus"
        case .ingreso: "arrow.down"
        case .fijos: "list.bullet.rectangle"
        case .rapido: "hand.tap"
        case .recibo: "doc.text.viewfinder"
        }
    }
}

/// Orden del menú Más y las 3 acciones fijadas en Inicio. Se guarda como texto en AppStorage.
struct QuickActionLayout: Equatable, Sendable {
    static let storageKey = "inicio.acciones"
    static let pinnedLimit = 3
    static let standard = QuickActionLayout(order: QuickActionKind.allCases, pinned: [.gasto, .ingreso, .fijos])
    /// Acciones que existieron y se quitaron (Gasto fijo, Sueldo o fijo y Pago anual repetían Pagos fijos; Historial
    /// ya está en Inicio › Movimientos › Ver todo; Registro automático vive en Ajustes; Límites y Ahorro, en Dinero). Si alguien las tenía fijadas, su lugar se llena con las de por
    /// defecto para que Inicio siga mostrando 3.
    static let retired: Set<String> = ["fijo", "sueldo", "anual", "historial", "automatico", "limites", "ahorro"]

    private(set) var order: [QuickActionKind]
    private(set) var pinned: [QuickActionKind]

    init(order: [QuickActionKind], pinned: [QuickActionKind]) {
        self.order = order
        self.pinned = pinned
        normalize()
    }

    /// Texto "orden|fijadas", por ejemplo "gasto,ingreso,...|gasto,ingreso,fijos".
    init(stored: String) {
        let parts = stored.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        func kinds(_ text: String) -> [QuickActionKind] {
            text.split(separator: ",").compactMap { QuickActionKind(rawValue: String($0)) }
        }
        guard parts.count == 2 else {
            self = .standard
            return
        }
        let storedPins = parts[1].split(separator: ",").map(String.init)
        var pinned = kinds(parts[1])
        if storedPins.contains(where: Self.retired.contains) {
            pinned = Self.filled(pinned)
        }
        self.init(order: kinds(parts[0]), pinned: pinned)
    }

    /// Completa las fijadas con las de por defecto, sin repetir, hasta llegar a 3.
    static func filled(_ pinned: [QuickActionKind]) -> [QuickActionKind] {
        var result: [QuickActionKind] = []
        for kind in pinned where !result.contains(kind) { result.append(kind) }
        for kind in standard.pinned + QuickActionKind.allCases where result.count < pinnedLimit && !result.contains(kind) {
            result.append(kind)
        }
        return result
    }

    var stored: String {
        order.map(\.rawValue).joined(separator: ",") + "|" + pinned.map(\.rawValue).joined(separator: ",")
    }

    /// Las que no están fijadas, en el orden del usuario.
    var unpinned: [QuickActionKind] { order.filter { !pinned.contains($0) } }

    func isPinned(_ kind: QuickActionKind) -> Bool { pinned.contains(kind) }

    /// Fija o suelta una acción. Si ya hay 3, la nueva reemplaza la última fijada.
    mutating func togglePin(_ kind: QuickActionKind) {
        if let index = pinned.firstIndex(of: kind) {
            pinned.remove(at: index)
        } else {
            if pinned.count >= Self.pinnedLimit { pinned.removeLast() }
            pinned.append(kind)
        }
    }

    /// Mueve dentro de las fijadas (para elegir cuál va primero en Inicio).
    mutating func movePinned(from source: IndexSet, to destination: Int) {
        pinned = Self.moved(pinned, from: source, to: destination)
    }

    /// Mueve dentro de las no fijadas, conservando su lugar relativo en el orden completo.
    mutating func moveUnpinned(from source: IndexSet, to destination: Int) {
        let rest = Self.moved(unpinned, from: source, to: destination)
        order = pinned + rest
        normalize()
    }

    private mutating func normalize() {
        var seen = Set<QuickActionKind>()
        order = order.filter { seen.insert($0).inserted }
        for kind in QuickActionKind.allCases where !seen.contains(kind) { order.append(kind) }
        var pinSeen = Set<QuickActionKind>()
        pinned = Array(pinned.filter { pinSeen.insert($0).inserted }.prefix(Self.pinnedLimit))
    }

    private static func moved(_ list: [QuickActionKind], from source: IndexSet, to destination: Int) -> [QuickActionKind] {
        var result = list
        let items = source.sorted().map { list[$0] }
        for index in source.sorted(by: >) { result.remove(at: index) }
        let shift = source.filter { $0 < destination }.count
        let target = max(0, min(result.count, destination - shift))
        result.insert(contentsOf: items, at: target)
        return result
    }
}
