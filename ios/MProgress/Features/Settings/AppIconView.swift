import SwiftUI
import UIKit

/// Ícono de la app (pantalla 29): 6 variantes con los colores de la app.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case brasa, noche, hielo, oro, claro, grafito
    static let storageKey = "apariencia.icono"
    var id: String { rawValue }

    var title: String { rawValue.capitalizedFirst }
    /// Nil es el ícono principal.
    var alternateName: String? { self == .brasa ? nil : "AppIcon-\(title)" }
    var previewName: String { "Vista\(title)" }
}

struct AppIconView: View {
    @AppStorage(AppIconChoice.storageKey) private var iconRaw = AppIconChoice.brasa.rawValue
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Ícono de la app").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s4), count: 3), spacing: Spacing.s5) {
                    ForEach(AppIconChoice.allCases) { choice in
                        Button { pick(choice) } label: { tile(choice) }.buttonStyle(.plain)
                    }
                }
                if let errorText {
                    Text(errorText).appFont(.cuerpo2).foregroundStyle(Palette.peligro)
                }
                Text("Qué entra en Premium se decide más adelante; por ahora todos están disponibles.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ choice: AppIconChoice) -> some View {
        let selected = iconRaw == choice.rawValue
        return VStack(spacing: Spacing.s2) {
            Image(choice.previewName)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(selected ? Palette.brasa : .clear, lineWidth: 3).padding(-4))
            Text(choice.title).appFont(.etiqueta).foregroundStyle(Palette.texto1)
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
