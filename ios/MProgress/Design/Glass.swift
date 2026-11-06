import SwiftUI

/// Niveles de transparencia del vidrio (HANDOFF 10.4). Se guarda en Ajustes › Apariencia.
enum GlassLevel: String, CaseIterable, Identifiable, Sendable {
    case mucha, normal, poca, ninguna

    static let storageKey = "apariencia.vidrio"

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
        case .mucha: 0.40
        case .normal: 0.86
        case .poca: 0.95
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

    var isSolid: Bool { reduceTransparency || level == .ninguna }

    var body: some View {
        ZStack {
            if !isSolid {
                shape.fill(level == .poca ? .thickMaterial : .ultraThinMaterial)
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
