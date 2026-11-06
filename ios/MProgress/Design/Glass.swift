import SwiftUI

/// Vidrio de la app (HANDOFF 10.4): usa el Liquid Glass de Apple (iOS 26). Se guarda en Ajustes › Apariencia.
/// Los valores guardados se conservan: mucha, normal, poca, ninguna.
enum GlassLevel: String, CaseIterable, Identifiable, Sendable {
    case normal, mucha, poca, ninguna

    static let storageKey = "apariencia.vidrio"
    /// Si está activo, Reducir transparencia de iOS vuelve sólido el vidrio.
    static let followSystemKey = "apariencia.seguirIOS"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Como iOS"
        case .mucha: "Clara"
        case .poca: "Tintada"
        case .ninguna: "Sólida"
        }
    }

    var detail: String {
        switch self {
        case .normal: "El vidrio líquido de Apple, igual que en el sistema."
        case .mucha: "Más transparente: se ve lo que hay detrás."
        case .poca: "Vidrio con un tinte oscuro, más fácil de leer."
        case .ninguna: "Sin transparencia."
        }
    }
}

extension EnvironmentValues {
    @Entry var glassLevel: GlassLevel = .normal
}

/// Fondo de vidrio para barra, pastillas y hojas, con el Liquid Glass del sistema.
/// Con Reducir transparencia (si "Seguir a iOS" está activo) o en Sólida, es un color plano.
struct GlassBackground<S: Shape>: View {
    let shape: S
    var shadow: Bool = true
    @Environment(\.glassLevel) private var level
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(GlassLevel.followSystemKey) private var followSystem = true

    var isSolid: Bool { (followSystem && reduceTransparency) || level == .ninguna }

    var body: some View {
        if isSolid {
            shape.fill(Palette.vidrioTinte)
                .overlay(shape.stroke(Palette.vidrioBorde, lineWidth: 1))
                .shadow(color: .black.opacity(shadow ? 0.35 : 0), radius: 16, y: 10)
        } else {
            Color.clear.glassEffect(glass, in: shape)
        }
    }

    private var glass: Glass {
        switch level {
        case .mucha: .clear
        case .poca: .regular.tint(Palette.vidrioTinte.opacity(0.55))
        default: .regular
        }
    }
}

extension View {
    /// Pone un fondo de vidrio con la forma dada.
    func glassBackground<S: Shape>(_ shape: S, shadow: Bool = true) -> some View {
        background(GlassBackground(shape: shape, shadow: shadow))
    }
}
