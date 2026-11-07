import SwiftUI

/// Pastilla de la barra de filtros (Resumen): 44 de alto, cápsula, ícono de 18.
/// Elegida: rellena con texto1 y letra oscura; sin elegir: superficie1 con letra clara. Igual que FilterPill de Android.
struct FilterPillLabel: View {
    let title: String
    var systemImage: String?
    var selected = false
    var showsChevron = false

    var body: some View {
        HStack(spacing: Spacing.s2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.medium)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            Text(title).appFont(.etiqueta).lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(selected ? Palette.fondo : Palette.texto1)
        .padding(.horizontal, Spacing.s4)
        .frame(height: 44)
        .background(Capsule().fill(selected ? Palette.texto1 : Palette.superficie1))
        .contentShape(Capsule())
    }
}

struct FilterPill: View {
    let title: String
    var systemImage: String?
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FilterPillLabel(title: title, systemImage: systemImage, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        FilterPillLabel(title: "12 meses", showsChevron: true)
        FilterPill(title: "Todas", selected: true) {}
        FilterPill(title: "Mercado", systemImage: "cart") {}
    }
    .padding()
    .background(Palette.fondo)
    .preferredColorScheme(.dark)
}
