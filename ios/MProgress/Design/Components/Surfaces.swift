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

/// Firma de Juan (skill firma-juan-olarte-dev): texto, línea de 1 x 22 y monograma JO de 30 x 20.
/// Va al final de las pantallas de ajustes, centrada y con aire debajo para que la barra no la tape.
struct SignatureFooter: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("juan-olarte-dev")
                .font(.system(size: 14, weight: .regular))
                .tracking(0.7)
                .foregroundStyle(Palette.texto1.opacity(0.75))
            Rectangle()
                .fill(Palette.texto1.opacity(0.2))
                .frame(width: 1, height: 22)
            ZStack {
                MonogramJ()
                    .stroke(Palette.texto1, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
                MonogramRing(radius: 7)
                    .stroke(Palette.texto1, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
                MonogramRing(radius: 2.1)
                    .stroke(Palette.brasaTinta, style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
            .frame(width: 30, height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Spacing.s8)
        // Espacio extra para poder bajar más: la barra de abajo nunca la tapa.
        .padding(.bottom, Size.barra + Spacing.s8 + Spacing.s6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desarrollado por juan-olarte-dev")
    }
}

/// La J del monograma, dibujada en una caja de 30 x 20.
private struct MonogramJ: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30, sy = rect.height / 20
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(11.3, 2.3))
        path.addLine(to: p(11.3, 13.6))
        path.addCurve(to: p(6.9, 18.2), control1: p(11.3, 16.5), control2: p(9.3, 18.2))
        path.addCurve(to: p(2.7, 16.1), control1: p(5.1, 18.2), control2: p(3.6, 17.4))
        return path
    }
}

/// Anillo de la O del monograma, centrado en (21, 10.8) de la caja de 30 x 20.
private struct MonogramRing: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30, sy = rect.height / 20
        let c = CGPoint(x: rect.minX + 21 * sx, y: rect.minY + 10.8 * sy)
        return Path(ellipseIn: CGRect(x: c.x - radius * sx, y: c.y - radius * sy, width: 2 * radius * sx, height: 2 * radius * sy))
    }
}
