import SwiftUI
import UIKit

// Tokens del sistema de diseño (HANDOFF sección 10). Ningún color ni medida suelta en las vistas.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Color que cambia con el tema claro u oscuro del sistema.
    init(light: UInt32, dark: UInt32, lightOpacity: CGFloat = 1, darkOpacity: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            let isLight = traits.userInterfaceStyle == .light
            let hex = isLight ? light : dark
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isLight ? lightOpacity : darkOpacity
            )
        })
    }
}

enum Palette {
    static let fondo = Color(light: 0xF3F4F6, dark: 0x0A0B0D)
    static let superficie1 = Color(light: 0xFFFFFF, dark: 0x15171B)
    static let superficie2 = Color(light: 0xFFFFFF, dark: 0x1D2025)
    static let superficie3 = Color(light: 0xE8EAEE, dark: 0x262A30)
    static let controlActivo = Color(light: 0xFFFFFF, dark: 0x3A3F47)
    static let linea = Color(light: 0x0E1014, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.08)
    static let lineaControl = Color(light: 0x7F8792, dark: 0x6C727B)
    static let texto1 = Color(light: 0x0E1014, dark: 0xF3F4F6)
    static let texto2 = Color(light: 0x545B66, dark: 0xA5ABB4)
    // Acento (brasa) e ingresos (hielo): salen de Ajustes › Diseño › Colores y cambian en vivo (LiveColors).
    static var brasa: Color { Color(hex: LiveColors.shared.accent.fill) }
    static var brasaPresionada: Color { let t = LiveColors.shared.accent; return Color(light: t.pressedLight, dark: t.pressedDark) }
    static var sobreBrasa: Color { Color(hex: LiveColors.shared.accent.onFill) }
    static var brasaTinta: Color { let t = LiveColors.shared.accent; return Color(light: t.inkLight, dark: t.inkDark) }
    static var brasaVelo: Color { let t = LiveColors.shared.accent; return Color(light: t.veilLight, dark: t.veilDark) }
    static var hielo: Color { let t = LiveColors.shared.income; return Color(light: t.inkLight, dark: t.inkDark) }
    static var hieloVelo: Color { let t = LiveColors.shared.income; return Color(light: t.veilLight, dark: t.veilDark) }
    static let oro = Color(light: 0x7E5A00, dark: 0xF5C451)
    static let oroRelleno = Color(hex: 0xF5C451)
    static let sobreOro = Color(hex: 0x2A1F00)
    static let oroVelo = Color(light: 0xFDF2D9, dark: 0x393324)
    static let peligro = Color(light: 0xC8243E, dark: 0xFF5A6E)
    static let peligroVelo = Color(light: 0xFDE7EA, dark: 0x3A1A20)
    static let exito = Color(light: 0x15803D, dark: 0x4ADE80)
    static let vidrioTinte = Color(light: 0xFFFFFF, dark: 0x1A1C21)
    static let vidrioBorde = Color(light: 0x0E1014, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.12)
    static let vidrioSeleccion = Color(light: 0x0E1014, dark: 0xFFFFFF, lightOpacity: 0.07, darkOpacity: 0.12)
    static let veloModal = Color(light: 0x0E1014, dark: 0x000000, lightOpacity: 0.4, darkOpacity: 0.64)
}

enum Spacing {
    static let s0_5: CGFloat = 2
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 28
    static let s8: CGFloat = 32
    static let margen: CGFloat = 20
}

enum Radius {
    static let campo: CGFloat = 14
    static let boton: CGFloat = 20
    static let tarjeta: CGFloat = 28
    static let hoja: CGFloat = 36
}

enum Size {
    static let toqueMinimo: CGFloat = 48
    static let botonPrincipal: CGFloat = 56
    static let botonSecundario: CGFloat = 48
    static let barra: CGFloat = 64
    static let icono: CGFloat = 24
    static let iconoLinea: CGFloat = 20
    static let baldosa: CGFloat = 44
}
