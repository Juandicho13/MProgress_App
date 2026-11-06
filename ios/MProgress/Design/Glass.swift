import SwiftUI

/// Niveles de transparencia del vidrio (HANDOFF 10.4). Se guarda en Ajustes › Apariencia.
enum GlassLevel: String, CaseIterable, Identifiable, Sendable {
    case mucha, normal, poca, ninguna

    static let storageKey = "apariencia.vidrio"
    /// Si está activo, Reducir transparencia de iOS vuelve sólido el vidrio.
    static let followSystemKey = "apariencia.seguirIOS"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mucha: "Mucha"
        case .normal: "Normal"
        case .poca: "Poca"
        case .ninguna: "Ninguna"
        }
    }

    var tintOpacity: Double {
        switch self {
        case .mucha: 0.12
        case .normal: 0.55
        case .poca: 0.85
        case .ninguna: 1.0
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .mucha: 32
        case .normal: 24
        case .poca: 12
        case .ninguna: 0
        }
    }
}

extension EnvironmentValues {
    @Entry var glassLevel: GlassLevel = .normal
}

/// Fondo de vidrio para barra, pastillas y hojas. Con Reducir transparencia es sólido siempre.
struct GlassBackground<S: Shape>: View {
    let shape: S
    var shadow: Bool = true
    @Environment(\.glassLevel) private var level
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(GlassLevel.followSystemKey) private var followSystem = true

    var isSolid: Bool { (followSystem && reduceTransparency) || level == .ninguna }

    var body: some View {
        ZStack {
            if !isSolid {
                switch level {
                case .mucha: shape.fill(.ultraThinMaterial)
                case .normal: shape.fill(.thinMaterial)
                default: shape.fill(.thickMaterial)
                }
            }
            shape.fill(Palette.vidrioTinte.opacity(isSolid ? 1 : level.tintOpacity))
            shape.stroke(Palette.vidrioBorde, lineWidth: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(shadow ? 0.45 : 0), radius: 16, y: 12)
    }
}

extension View {
    /// Pone un fondo de vidrio con la forma dada.
    func glassBackground<S: Shape>(_ shape: S, shadow: Bool = true) -> some View {
        background(GlassBackground(shape: shape, shadow: shadow))
    }
}
