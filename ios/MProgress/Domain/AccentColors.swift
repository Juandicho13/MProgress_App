import Foundation

/// Cuentas de color en hexadecimal (0xRRGGBB), sin SwiftUI, para poder probarlas en cualquier máquina.
enum ColorMath {
    static let white: UInt32 = 0xFFFFFF
    static let black: UInt32 = 0x000000
    /// Texto oscuro de la app (texto1 del tema claro), el que va sobre acentos claros.
    static let ink: UInt32 = 0x0E1014
    /// Fondos de la app: claro (superficie1) y oscuro (fondo y superficie1).
    static let lightBackground: UInt32 = 0xFFFFFF
    static let darkBackground: UInt32 = 0x0A0B0D
    static let darkSurface: UInt32 = 0x15171B

    static func channels(_ hex: UInt32) -> (Double, Double, Double) {
        (Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF))
    }

    /// Mezcla `a` sobre `b`: `amount` es cuánto de `a` queda (1 es solo `a`, 0 es solo `b`).
    static func mix(_ a: UInt32, over b: UInt32, amount: Double) -> UInt32 {
        let t = min(max(amount, 0), 1)
        let (ar, ag, ab) = channels(a)
        let (br, bg, bb) = channels(b)
        func c(_ x: Double, _ y: Double) -> UInt32 { UInt32((x * t + y * (1 - t)).rounded()) }
        return (c(ar, br) << 16) | (c(ag, bg) << 8) | c(ab, bb)
    }

    /// Luminancia relativa de WCAG 2.
    static func luminance(_ hex: UInt32) -> Double {
        func lin(_ v: Double) -> Double {
            let s = v / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = channels(hex)
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Contraste de WCAG 2 entre dos colores, de 1 a 21.
    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Texto que va encima del acento (botones, insignias). Blanco mientras tenga contraste de 3 (texto en negrilla de
    /// 17 o más, como los botones); si no, el texto oscuro de la app. La brasa original da blanco (pedido de Juan).
    static func onAccent(_ fill: UInt32) -> UInt32 {
        contrast(white, fill) >= 3 ? white : ink
    }

    /// Mezcla `color` con `toward` de a 5 % hasta que tenga al menos `minimum` de contraste con `background`.
    static func ensureContrast(_ color: UInt32, toward: UInt32, background: UInt32, minimum: Double = 4.5) -> UInt32 {
        var amount = 1.0
        var result = color
        while contrast(result, background) < minimum && amount > 0 {
            amount -= 0.05
            result = mix(color, over: toward, amount: amount)
        }
        return result
    }
}

/// Los tonos que salen de un color: relleno, presionado, texto (tinta) y velo, en claro y en oscuro.
struct AccentTokens: Equatable, Sendable {
    var fill: UInt32
    var onFill: UInt32
    var pressedLight: UInt32
    var pressedDark: UInt32
    var inkLight: UInt32
    var inkDark: UInt32
    var veilLight: UInt32
    var veilDark: UInt32

    /// Los de la app hasta hoy (HANDOFF 10): brasa y hielo se ven exactamente igual con "Original".
    static let brasaOriginal = AccentTokens(fill: 0xF55F1F, onFill: 0xFFFFFF, pressedLight: 0xDE5014, pressedDark: 0xE04F12,
                                            inkLight: 0xB83D0B, inkDark: 0xFF6B2C, veilLight: 0xFFEAE1, veilDark: 0x3A241E)
    static let hieloOriginal = AccentTokens(fill: 0x6CC4F2, onFill: ColorMath.ink, pressedLight: 0x166AA0, pressedDark: 0x6CC4F2,
                                            inkLight: 0x166AA0, inkDark: 0x6CC4F2, veilLight: 0xE6F2F9, veilDark: 0x23333D)

    /// Reglas para un acento nuevo, sacadas de la brasa original: presionado 10 % hacia negro; tinta 25 % hacia negro
    /// en claro y 8 % hacia blanco en oscuro, y se sigue mezclando hasta leerse (4,5) sobre su fondo; velo 13 % del
    /// color sobre blanco en claro y 16 % sobre la superficie oscura.
    static func accent(_ fill: UInt32) -> AccentTokens {
        AccentTokens(
            fill: fill,
            onFill: ColorMath.onAccent(fill),
            pressedLight: ColorMath.mix(fill, over: ColorMath.black, amount: 0.9),
            pressedDark: ColorMath.mix(fill, over: ColorMath.black, amount: 0.9),
            inkLight: ColorMath.ensureContrast(ColorMath.mix(fill, over: ColorMath.black, amount: 0.75), toward: ColorMath.black, background: ColorMath.lightBackground),
            inkDark: ColorMath.ensureContrast(ColorMath.mix(fill, over: ColorMath.white, amount: 0.92), toward: ColorMath.white, background: ColorMath.darkBackground),
            veilLight: ColorMath.mix(fill, over: ColorMath.white, amount: 0.13),
            veilDark: ColorMath.mix(fill, over: ColorMath.darkSurface, amount: 0.16)
        )
    }

    /// Reglas para el azul de ingresos: el texto es el color de cada tema, asegurado a 4,5 sobre su fondo; el velo
    /// es 10 % del color claro sobre blanco y 16 % del oscuro sobre la superficie oscura (las del hielo original).
    static func income(light: UInt32, dark: UInt32) -> AccentTokens {
        let inkLight = ColorMath.ensureContrast(light, toward: ColorMath.black, background: ColorMath.lightBackground)
        let inkDark = ColorMath.ensureContrast(dark, toward: ColorMath.white, background: ColorMath.darkBackground)
        return AccentTokens(fill: dark, onFill: ColorMath.onAccent(dark), pressedLight: inkLight, pressedDark: inkDark,
                            inkLight: inkLight, inkDark: inkDark,
                            veilLight: ColorMath.mix(light, over: ColorMath.white, amount: 0.1),
                            veilDark: ColorMath.mix(dark, over: ColorMath.darkSurface, amount: 0.16))
    }
}

/// Un color para elegir en Ajustes › Diseño › Colores.
struct ColorPreset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// Color de muestra (el círculo de la lista).
    let swatch: UInt32
    let tokens: AccentTokens
    var isOriginal: Bool { id == "original" }
}

enum AccentPresets {
    static let accentKey = "diseno.acento"
    static let incomeKey = "diseno.ingreso"

    static let accents: [ColorPreset] = [
        ColorPreset(id: "original", name: "Brasa", swatch: 0xF55F1F, tokens: .brasaOriginal),
        accent("rubi", "Rubí", 0xE5384F),
        accent("rosa", "Rosa", 0xE8457F),
        accent("violeta", "Violeta", 0x8B5CF6),
        accent("azul", "Azul", 0x2F7FE0),
        accent("menta", "Menta", 0x14A88A),
        accent("lima", "Lima", 0x7CB518),
        accent("ambar", "Ámbar", 0xF2A516),
    ]

    static let incomes: [ColorPreset] = [
        ColorPreset(id: "original", name: "Hielo", swatch: 0x6CC4F2, tokens: .hieloOriginal),
        income("azulRey", "Azul rey", light: 0x1D4ED8, dark: 0x93B4FD),
        income("indigo", "Índigo", light: 0x4338CA, dark: 0xA5B4FC),
        income("violeta", "Violeta", light: 0x7E3FBF, dark: 0xC4A1F5),
        income("turquesa", "Turquesa", light: 0x0E7C86, dark: 0x4FD1DB),
        income("verde", "Verde", light: 0x15803D, dark: 0x4ADE80),
        income("oliva", "Oliva", light: 0x4D7C0F, dark: 0xA3E635),
        income("pizarra", "Pizarra", light: 0x475569, dark: 0xCBD5E1),
    ]

    /// Lo guardado, o el original si no hay nada o el id ya no existe.
    static func accent(id: String?) -> ColorPreset { accents.first { $0.id == id } ?? accents[0] }
    static func income(id: String?) -> ColorPreset { incomes.first { $0.id == id } ?? incomes[0] }

    /// Texto de la fila Diseño en Ajustes: "Oscuro · vidrio normal · Trazo", y los colores si no son los originales.
    static func summary(theme: String, glass: String, icon: String, accentId: String?, incomeId: String?) -> String {
        var parts = [theme, "vidrio \(glass.lowercased())", icon]
        let a = accent(id: accentId), i = income(id: incomeId)
        let custom = [a, i].filter { !$0.isOriginal }.map(\.name)
        if !custom.isEmpty { parts.append(custom.joined(separator: " y ")) }
        return parts.joined(separator: " · ")
    }

    private static func accent(_ id: String, _ name: String, _ hex: UInt32) -> ColorPreset {
        ColorPreset(id: id, name: name, swatch: hex, tokens: .accent(hex))
    }

    private static func income(_ id: String, _ name: String, light: UInt32, dark: UInt32) -> ColorPreset {
        ColorPreset(id: id, name: name, swatch: dark, tokens: .income(light: light, dark: dark))
    }
}
