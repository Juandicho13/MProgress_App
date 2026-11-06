import SwiftUI

/// Fila de lista: baldosa, título, detalle y valor a la derecha.
struct ListRow<Trailing: View>: View {
    var tile: IconTile?
    let title: String
    var subtitle: String?
    var showsChevron: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.s3) {
            if let tile { tile }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.titulo3)
                    .foregroundStyle(Palette.texto1)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.s2)
            trailing
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.texto2)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension ListRow where Trailing == EmptyView {
    init(tile: IconTile? = nil, title: String, subtitle: String? = nil, showsChevron: Bool = false) {
        self.init(tile: tile, title: title, subtitle: subtitle, showsChevron: showsChevron) { EmptyView() }
    }
}

/// Control segmentado en píldora (Gasto o Ingreso, ciclos, transparencia).
struct SegmentedPill<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: Spacing.s1) {
            ForEach(options, id: \.value) { option in
                let active = option.value == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .appFont(.etiqueta)
                        .fontWeight(active ? .semibold : .medium)
                        .foregroundStyle(Palette.texto1)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if active {
                                Capsule()
                                    .fill(Palette.controlActivo)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(Spacing.s1)
        .background(Capsule().fill(Palette.superficie3))
    }
}

/// Chip de filtro (categorías en Resumen).
struct Chip: View {
    let title: String
    var systemImage: String?
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s1) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                }
                Text(title).appFont(.etiqueta)
            }
            .foregroundStyle(selected ? Palette.brasaTinta : Palette.texto1)
            .padding(.horizontal, Spacing.s4)
            .frame(minHeight: 40)
            .background(Capsule().fill(selected ? Palette.brasaVelo : Palette.superficie1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Estado vacío con dibujo, título, texto y acciones.
struct EmptyStateView<Art: View, Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var art: Art
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: Spacing.s4) {
            art
            Text(title)
                .appFont(.titulo2)
                .foregroundStyle(Palette.texto1)
                .multilineTextAlignment(.center)
            Text(message)
                .appFont(.cuerpo)
                .foregroundStyle(Palette.texto2)
                .multilineTextAlignment(.center)
            actions
        }
        .padding(Spacing.s6)
        .frame(maxWidth: .infinity)
    }
}
