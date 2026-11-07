import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct AccentColorsTests {
    @Test("Contraste de WCAG: blanco y negro dan 21, un color consigo mismo da 1")
    func contraste() {
        #expect(abs(ColorMath.contrast(0xFFFFFF, 0x000000) - 21) < 0.01)
        #expect(abs(ColorMath.contrast(0xF55F1F, 0xF55F1F) - 1) < 0.0001)
    }

    @Test("Sobre la brasa, el rubí, el azul, el violeta y la menta va blanco; sobre el ámbar y la lima, oscuro")
    func textoSobreAcento() {
        #expect(ColorMath.onAccent(0xF55F1F) == ColorMath.white)
        #expect(ColorMath.onAccent(0xE5384F) == ColorMath.white)
        #expect(ColorMath.onAccent(0x2F7FE0) == ColorMath.white)
        #expect(ColorMath.onAccent(0x8B5CF6) == ColorMath.white)
        #expect(ColorMath.onAccent(0xF2A516) == ColorMath.ink)
        #expect(ColorMath.onAccent(0x7CB518) == ColorMath.ink)
        #expect(ColorMath.onAccent(0x14A88A) == ColorMath.white)
        #expect(ColorMath.onAccent(0xFFFFFF) == ColorMath.ink)
    }

    @Test("Mezclar: 1 deja el color, 0 deja el fondo, 0,5 queda en la mitad")
    func mezcla() {
        #expect(ColorMath.mix(0xF55F1F, over: 0x000000, amount: 1) == 0xF55F1F)
        #expect(ColorMath.mix(0xF55F1F, over: 0x000000, amount: 0) == 0x000000)
        #expect(ColorMath.mix(0xFFFFFF, over: 0x000000, amount: 0.5) == 0x808080)
    }

    @Test("Las reglas aplicadas a la brasa quedan cerca de los tonos originales")
    func reglasDeLaBrasa() {
        let derived = AccentTokens.accent(0xF55F1F)
        let original = AccentTokens.brasaOriginal
        for (a, b) in [(derived.pressedLight, original.pressedLight), (derived.inkLight, original.inkLight),
                       (derived.inkDark, original.inkDark), (derived.veilLight, original.veilLight), (derived.veilDark, original.veilDark)] {
            #expect(ColorMath.contrast(a, b) < 1.25, "\(String(a, radix: 16)) lejos de \(String(b, radix: 16))")
        }
        #expect(derived.onFill == original.onFill)
    }

    @Test("Cada color se lee: tinta a 4,5 sobre su fondo y texto encima del relleno a 3 o más")
    func todosSeLeen() {
        for preset in AccentPresets.accents + AccentPresets.incomes {
            let t = preset.tokens
            #expect(ColorMath.contrast(t.inkLight, ColorMath.lightBackground) >= 4.5, "\(preset.name) claro")
            #expect(ColorMath.contrast(t.inkDark, ColorMath.darkBackground) >= 4.5, "\(preset.name) oscuro")
            #expect(ColorMath.contrast(t.onFill, t.fill) >= 3, "\(preset.name) relleno")
        }
    }

    @Test("Ocho de cada uno, con ids únicos y el original primero")
    func presets() {
        #expect(AccentPresets.accents.count == 8)
        #expect(AccentPresets.incomes.count == 8)
        #expect(Set(AccentPresets.accents.map(\.id)).count == 8)
        #expect(Set(AccentPresets.incomes.map(\.id)).count == 8)
        #expect(AccentPresets.accents[0].isOriginal && AccentPresets.incomes[0].isOriginal)
        #expect(AccentPresets.accent(id: nil).tokens == .brasaOriginal)
        #expect(AccentPresets.income(id: "no-existe").tokens == .hieloOriginal)
        #expect(AccentPresets.accent(id: "rubi").name == "Rubí")
    }

    @Test("Resumen de la fila Diseño")
    func resumen() {
        #expect(AccentPresets.summary(theme: "Oscuro", glass: "Normal", icon: "Trazo", accentId: nil, incomeId: nil) == "Oscuro · vidrio normal · Trazo")
        #expect(AccentPresets.summary(theme: "Claro", glass: "Poca", icon: "Anillo", accentId: "rubi", incomeId: "original") == "Claro · vidrio poca · Anillo · Rubí")
        #expect(AccentPresets.summary(theme: "Oscuro", glass: "Normal", icon: "Trazo", accentId: "rubi", incomeId: "verde") == "Oscuro · vidrio normal · Trazo · Rubí y Verde")
    }
}
