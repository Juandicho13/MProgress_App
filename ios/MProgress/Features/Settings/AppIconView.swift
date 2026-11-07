import SwiftUI
import UIKit

/// Ícono de la app (pantalla 29): 4 símbolos naranja (Trazo es el principal), cada uno con fondo negro o blanco.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case trazo, trazoBlanco, anillo, anilloBlanco, progreso, progresoBlanco, barras, barrasBlanco
    static let storageKey = "apariencia.icono"
    var id: String { rawValue }

    enum Symbol: String, CaseIterable { case trazo, anillo, progreso, barras }
    var symbol: Symbol { Symbol(rawValue: rawValue.replacingOccurrences(of: "Blanco", with: "")) ?? .trazo }
    var isWhite: Bool { rawValue.hasSuffix("Blanco") }

    static func choice(_ symbol: Symbol, white: Bool) -> AppIconChoice {
        AppIconChoice(rawValue: symbol.rawValue + (white ? "Blanco" : "")) ?? .trazo
    }

    var symbolTitle: String {
        switch symbol {
        case .trazo: "Trazo"
        case .anillo: "Anillo"
        case .progreso: "Progreso"
        case .barras: "Barras"
        }
    }

    var title: String { "\(symbolTitle) · \(isWhite ? "blanco" : "negro")" }

    private var assetSuffix: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    /// Nil es el ícono principal (Trazo sobre negro).
    var alternateName: String? { self == .trazo ? nil : "AppIcon-\(assetSuffix)" }
    var previewName: String { "Vista\(assetSuffix)" }
}

/// Ícono de la app (pantalla 29, ahora sección de Diseño).
struct AppIconSection: View {
    @AppStorage(AppIconChoice.storageKey) private var iconRaw = AppIconChoice.trazo.rawValue
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            SectionLabel(text: "Símbolo")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s4), count: 4), spacing: Spacing.s5) {
                ForEach(AppIconChoice.Symbol.allCases, id: \.self) { symbol in
                    let choice = AppIconChoice.choice(symbol, white: current.isWhite)
                    Button { pick(choice) } label: { tile(choice) }.buttonStyle(.plain)
                }
            }
            SectionLabel(text: "Fondo")
            SegmentedPill(options: [(value: "negro", title: "Negro"), (value: "blanco", title: "Blanco")],
                          selection: Binding(get: { current.isWhite ? "blanco" : "negro" },
                                             set: { pick(AppIconChoice.choice(current.symbol, white: $0 == "blanco")) }))
            if let errorText {
                Text(errorText).appFont(.cuerpo2).foregroundStyle(Palette.peligro)
            }
            Text("Qué entra en Premium se decide más adelante; por ahora todos están disponibles.")
                .appFont(.leyenda)
                .foregroundStyle(Palette.texto2)
        }
    }

    private var current: AppIconChoice { AppIconChoice(rawValue: iconRaw) ?? .trazo }

    private func tile(_ choice: AppIconChoice) -> some View {
        let selected = iconRaw == choice.rawValue
        return VStack(spacing: Spacing.s2) {
            Image(choice.previewName)
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(selected ? Palette.brasa : .clear, lineWidth: 3).padding(-4))
            Text(choice.symbolTitle).appFont(.etiqueta).foregroundStyle(Palette.texto1)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : [.isButton])
    }

    private func pick(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons else {
            errorText = "Este dispositivo no permite cambiar el ícono."
            return
        }
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(choice.alternateName)
                iconRaw = choice.rawValue
                errorText = nil
            } catch {
                errorText = "No se pudo cambiar el ícono."
            }
        }
    }
}
