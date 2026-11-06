import SwiftUI

/// Tarjeta: superficie 1 con esquinas de 28.
struct Card<Content: View>: View {
    var padding: CGFloat = Spacing.s4
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous).fill(Palette.superficie1))
    }
}

/// Sobretítulo de sección en mayúsculas.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .appFont(.leyenda)
            .foregroundStyle(Palette.texto2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Baldosa con símbolo o iniciales.
struct IconTile: View {
    enum Content: Hashable {
        case symbol(String)
        case initials(String)
    }

    let content: Content
    var tint: Color = Palette.superficie3
    var foreground: Color = Palette.texto1
    var size: CGFloat = Size.baldosa
    var circle: Bool = false

    var body: some View {
        ZStack {
            if circle {
                Circle().fill(tint)
            } else {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).fill(tint)
            }
            switch content {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.42, weight: .medium))
            case .initials(let text):
                Text(String(text.prefix(2)).uppercased())
                    .font(.system(size: size * 0.32, weight: .bold))
            }
        }
        .foregroundStyle(foreground)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Avatar redondo con iniciales de una persona.
struct Avatar: View {
    let name: String
    var tint: Color = Palette.brasa
    var foreground: Color = Palette.sobreBrasa
    var size: CGFloat = 32

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters
    }

    var body: some View {
        IconTile(content: .initials(initials), tint: tint, foreground: foreground, size: size, circle: true)
            .accessibilityLabel(name)
    }
}

/// Insignia pequeña: HOY, PRONTO, PREMIUM.
struct Badge: View {
    enum Tone { case brasa, oro, hielo, neutral, peligro }

    let text: String
    var tone: Tone = .neutral

    private var colors: (Color, Color) {
        switch tone {
        case .brasa: (Palette.brasa, Palette.sobreBrasa)
        case .oro: (Palette.oroRelleno, Palette.sobreOro)
        case .hielo: (Palette.hieloVelo, Palette.hielo)
        case .neutral: (Palette.superficie3, Palette.texto1)
        case .peligro: (Palette.peligroVelo, Palette.peligro)
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(colors.1)
            .padding(.horizontal, Spacing.s2)
            .padding(.vertical, 3)
            .background(Capsule().fill(colors.0))
    }
}

/// Firma de Juan al pie de Ajustes y Acerca de.
struct SignatureFooter: View {
    var body: some View {
        HStack(spacing: Spacing.s2) {
            Text("juan-olarte-dev")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.texto2)
            Rectangle()
                .fill(Palette.lineaControl)
                .frame(width: 1, height: 14)
            Text("JO")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Palette.brasaTinta)
                .frame(width: 24, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Palette.brasaTinta, lineWidth: 1.5))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hecho por juan-olarte-dev")
    }
}
