import Foundation
import Observation

/// Colores elegidos en Ajustes › Diseño › Colores. `Palette` los lee en cada acceso; como es @Observable, SwiftUI
/// vuelve a dibujar las vistas que los usan apenas cambian. Se guardan por dispositivo en UserDefaults.
/// Los widgets no lo leen: se quedan con los colores originales.
@Observable
final class LiveColors: @unchecked Sendable {
    static let shared = LiveColors()

    private(set) var accentId: String
    private(set) var incomeId: String
    private(set) var accent: AccentTokens
    private(set) var income: AccentTokens

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let a = AccentPresets.accent(id: defaults.string(forKey: AccentPresets.accentKey))
        let i = AccentPresets.income(id: defaults.string(forKey: AccentPresets.incomeKey))
        accentId = a.id
        incomeId = i.id
        accent = a.tokens
        income = i.tokens
    }

    func setAccent(_ id: String) {
        let preset = AccentPresets.accent(id: id)
        defaults.set(preset.id, forKey: AccentPresets.accentKey)
        accentId = preset.id
        accent = preset.tokens
    }

    func setIncome(_ id: String) {
        let preset = AccentPresets.income(id: id)
        defaults.set(preset.id, forKey: AccentPresets.incomeKey)
        incomeId = preset.id
        income = preset.tokens
    }

    func reset() {
        setAccent("original")
        setIncome("original")
    }
}
