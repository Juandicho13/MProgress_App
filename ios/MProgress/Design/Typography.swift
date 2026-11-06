import SwiftUI
import UIKit
import CoreText

/// Fuente Archivo (variable, licencia OFL) incluida en Resources/Fonts.
enum AppFont {
    static let postScriptName = "Archivo-SemiBold"
    private static let weightAxis = NSNumber(value: 0x7767_6874) // "wght"
    private static let widthAxis = NSNumber(value: 0x7764_7468) // "wdth"

    /// Se llama una vez al abrir la app.
    static func register() {
        guard let url = Bundle.main.url(forResource: "Archivo-Variable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Archivo con peso (100 a 900) y ancho (62 a 125) exactos.
    static func uiFont(size: CGFloat, weight: CGFloat, width: CGFloat = 100) -> UIFont {
        let variation: [NSNumber: CGFloat] = [weightAxis: weight, widthAxis: width]
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            .name: postScriptName,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ]
        return UIFont(descriptor: UIFontDescriptor(fontAttributes: attributes), size: size)
    }
}

/// Estilos de texto de HANDOFF 10.2.
enum TextStyle: CaseIterable, Sendable {
    case titulo1, titulo2, titulo3, cuerpo, cuerpo2, etiqueta, leyenda, pestana
    case cifraHeroe, cifraGrande, cifra, cifraPequena

    var size: CGFloat {
        switch self {
        case .titulo1: 30
        case .titulo2: 20
        case .titulo3: 17
        case .cuerpo: 16
        case .cuerpo2: 14
        case .etiqueta: 13
        case .leyenda: 12
        case .pestana: 11
        case .cifraHeroe: 46
        case .cifraGrande: 32
        case .cifra: 17
        case .cifraPequena: 15
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .titulo1: 36
        case .titulo2: 26
        case .titulo3: 22
        case .cuerpo: 24
        case .cuerpo2: 20
        case .etiqueta: 16
        case .leyenda: 16
        case .pestana: 14
        case .cifraHeroe: 50
        case .cifraGrande: 38
        case .cifra: 22
        case .cifraPequena: 20
        }
    }

    var weight: CGFloat {
        switch self {
        case .titulo1, .cifraHeroe: 700
        case .titulo2, .titulo3, .cifraGrande, .cifra, .cifraPequena: 600
        case .etiqueta, .leyenda, .pestana: 500
        case .cuerpo, .cuerpo2: 400
        }
    }

    /// Las cifras van a 112,5 % de ancho: los números son el protagonista.
    var width: CGFloat { isNumeric ? 112.5 : 100 }

    var tracking: CGFloat {
        switch self {
        case .titulo1, .cifraHeroe: -0.4
        case .leyenda: 0.5
        default: 0
        }
    }

    var isNumeric: Bool {
        switch self {
        case .cifraHeroe, .cifraGrande, .cifra, .cifraPequena: true
        default: false
        }
    }

    var relativeTo: UIFont.TextStyle {
        switch self {
        case .titulo1: .title1
        case .titulo2: .title3
        case .titulo3: .headline
        case .cuerpo: .body
        case .cuerpo2: .subheadline
        case .etiqueta: .footnote
        case .leyenda, .pestana: .caption1
        case .cifraHeroe, .cifraGrande: .largeTitle
        case .cifra, .cifraPequena: .body
        }
    }
}

private struct AppTextModifier: ViewModifier {
    let style: TextStyle
    @Environment(\.dynamicTypeSize) private var dynamicType

    func body(content: Content) -> some View {
        let base = AppFont.uiFont(size: style.size, weight: style.weight, width: style.width)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicType))
        let metrics = UIFontMetrics(forTextStyle: style.relativeTo)
        let scaled = metrics.scaledFont(for: base, compatibleWith: traits)
        let scaledLine = metrics.scaledValue(for: style.lineHeight, compatibleWith: traits)
        content
            .font(Font(scaled as CTFont))
            .lineSpacing(max(0, scaledLine - scaled.lineHeight))
            .tracking(style.tracking)
            .monospacedDigit()
    }
}

extension View {
    /// Aplica un estilo de texto del sistema de diseño, con Dynamic Type.
    func appFont(_ style: TextStyle) -> some View {
        modifier(AppTextModifier(style: style))
    }
}

extension AppFont {
    /// Fuente de un estilo para lugares que piden `Font` y no un modificador, como los ejes de Swift Charts.
    static func font(_ style: TextStyle) -> Font {
        let base = uiFont(size: style.size, weight: style.weight, width: style.width)
        return Font(UIFontMetrics(forTextStyle: style.relativeTo).scaledFont(for: base) as CTFont)
    }
}
