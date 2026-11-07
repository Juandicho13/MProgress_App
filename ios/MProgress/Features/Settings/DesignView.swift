import SwiftUI

/// Diseño (Ajustes): une Tema y vidrio, Colores e Ícono de la app en una sola pantalla.
struct DesignView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                Text("Diseño").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                header("Tema y vidrio")
                AppearanceSection()
                header("Colores")
                ColorsSection()
                header("Ícono de la app")
                AppIconSection()
                SignatureFooter()
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ text: String) -> some View {
        Text(text).appFont(.titulo2).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader).padding(.top, Spacing.s2)
    }
}

/// Colores: acento (la brasa) y color de ingresos (el hielo), con vista previa y Restablecer. Cambia toda la app al instante.
struct ColorsSection: View {
    private let live = LiveColors.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            preview
            SectionLabel(text: "Acento")
            swatches(AccentPresets.accents, selected: live.accentId) { live.setAccent($0) }
            SectionLabel(text: "Ingresos")
            swatches(AccentPresets.incomes, selected: live.incomeId) { live.setIncome($0) }
            if live.accentId != "original" || live.incomeId != "original" {
                Button("Restablecer") { withAnimation(.easeOut(duration: 0.2)) { live.reset() } }
                    .buttonStyle(.secondary)
            }
            Text("El texto sobre el acento cambia a blanco u oscuro para que siempre se lea. Los widgets usan los colores originales.")
                .appFont(.leyenda)
                .foregroundStyle(Palette.texto2)
        }
    }

    /// Un botón, una pastilla elegida y un ingreso, para ver los colores antes de salir.
    private var preview: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack(spacing: Spacing.s3) {
                    Chip(title: "Mercado", systemImage: "cart", selected: true) {}
                    Chip(title: "Salidas", systemImage: "fork.knife") {}
                    Spacer(minLength: 0)
                }
                HStack {
                    Text("Sueldo").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    Spacer()
                    Text(Money(units: 2_500_000).formatted(sign: true)).appFont(.titulo3).foregroundStyle(Palette.hielo)
                }
                Button("Guardar") {}.buttonStyle(.primary)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vista previa: botón, pastilla elegida e ingreso con los colores elegidos")
    }

    private func swatches(_ presets: [ColorPreset], selected: String, pick: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s3), count: 4), spacing: Spacing.s4) {
            ForEach(presets) { preset in
                let on = preset.id == selected
                Button { withAnimation(.easeOut(duration: 0.2)) { pick(preset.id) } } label: {
                    VStack(spacing: Spacing.s1) {
                        ZStack {
                            Circle().fill(Color(hex: preset.swatch)).frame(width: 44, height: 44)
                            if on {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(hex: ColorMath.onAccent(preset.swatch)))
                            }
                        }
                        .overlay(Circle().stroke(on ? Palette.texto1 : .clear, lineWidth: 2).padding(-4))
                        .frame(width: 52, height: 52)
                        Text(preset.name).appFont(.etiqueta).foregroundStyle(Palette.texto1).lineLimit(1)
                        Text(preset.isOriginal ? "Original" : " ").appFont(.leyenda).foregroundStyle(Palette.texto2)
                    }
                    .frame(maxWidth: .infinity, minHeight: Size.toqueMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.isOriginal ? "\(preset.name), original" : preset.name)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}
