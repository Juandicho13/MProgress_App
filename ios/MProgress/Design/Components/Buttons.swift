import SwiftUI

/// Botón principal: píldora brasa de 56. Uno por pantalla.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.titulo3)
            .foregroundStyle(Palette.sobreBrasa)
            .frame(maxWidth: .infinity, minHeight: Size.botonPrincipal)
            .padding(.horizontal, Spacing.s5)
            .background(Capsule().fill(configuration.isPressed ? Palette.brasaPresionada : Palette.brasa))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Botón secundario: píldora gris de 48.
struct SecondaryButtonStyle: ButtonStyle {
    var tone: Tone = .normal
    @Environment(\.isEnabled) private var isEnabled

    enum Tone { case normal, peligro }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.titulo3)
            .foregroundStyle(tone == .peligro ? Palette.peligro : Palette.texto1)
            .frame(maxWidth: .infinity, minHeight: Size.botonSecundario)
            .padding(.horizontal, Spacing.s4)
            .background(Capsule().fill(tone == .peligro ? Palette.peligroVelo : Palette.superficie3))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

/// Botón redondo de solo ícono, con su etiqueta para VoiceOver.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var filled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(filled ? Palette.sobreBrasa : Palette.texto1)
                .frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
                .background(Circle().fill(filled ? Palette.brasa : Palette.superficie1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var destructive: SecondaryButtonStyle { SecondaryButtonStyle(tone: .peligro) }
}
