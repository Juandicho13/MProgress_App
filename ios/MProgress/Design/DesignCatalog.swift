import SwiftUI

/// Catálogo del sistema de diseño para revisar tokens y componentes en `#Preview`.
struct DesignCatalog: View {
    @State private var kind = "gasto"
    @State private var chip = true

    private let swatches: [(String, Color)] = [
        ("fondo", Palette.fondo), ("superficie1", Palette.superficie1), ("superficie2", Palette.superficie2),
        ("superficie3", Palette.superficie3), ("brasa", Palette.brasa), ("hielo", Palette.hielo),
        ("oro", Palette.oro), ("peligro", Palette.peligro), ("exito", Palette.exito),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Catálogo").appFont(.titulo1).foregroundStyle(Palette.texto1)

                SectionLabel(text: "Colores")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Spacing.s3) {
                    ForEach(swatches, id: \.0) { swatch in
                        VStack(spacing: Spacing.s1) {
                            RoundedRectangle(cornerRadius: Radius.campo).fill(swatch.1).frame(height: 48)
                                .overlay(RoundedRectangle(cornerRadius: Radius.campo).stroke(Palette.linea))
                            Text(swatch.0).appFont(.leyenda).foregroundStyle(Palette.texto2)
                        }
                    }
                }

                SectionLabel(text: "Texto")
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Título 1").appFont(.titulo1)
                    Text("Título 2").appFont(.titulo2)
                    Text("Título 3").appFont(.titulo3)
                    Text("Cuerpo para leer").appFont(.cuerpo)
                    Text("Cuerpo 2 secundario").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    Text(Money(units: 1_901_100).formatted()).appFont(.cifraHeroe)
                    Text(Money(units: 119_900).formatted()).appFont(.cifra)
                }
                .foregroundStyle(Palette.texto1)

                SectionLabel(text: "Controles")
                SegmentedPill(options: [("gasto", "Gasto"), ("ingreso", "Ingreso")], selection: $kind)
                HStack {
                    Chip(title: "Todas", systemImage: "infinity", selected: chip) { chip.toggle() }
                    Chip(title: "Música", systemImage: "music.note", selected: !chip) { chip.toggle() }
                }
                HStack {
                    Badge(text: "Hoy", tone: .peligro)
                    Badge(text: "Pronto", tone: .oro)
                    Badge(text: "Premium", tone: .brasa)
                    Badge(text: "Hogar", tone: .hielo)
                }
                Button("Guardar") {}.buttonStyle(.primary)
                Button("Cancelar") {}.buttonStyle(.secondary)
                Button("Borrar") {}.buttonStyle(.destructive)

                SectionLabel(text: "Tarjeta y filas")
                Card {
                    ListRow(tile: IconTile(content: .symbol("dumbbell")), title: "Gimnasio", subtitle: "Mañana · solo tú") {
                        Text(Money(units: 119_900).formatted()).appFont(.cifra).foregroundStyle(Palette.texto1)
                    }
                    ListRow(tile: IconTile(content: .initials("RN"), tint: Palette.hielo, foreground: Palette.sobreBrasa), title: "Renta", subtitle: "1 dic · Hogar", showsChevron: true)
                }

                SignatureFooter()
            }
            .padding(Spacing.margen)
        }
        .background(Palette.fondo)
    }
}

#Preview("Catálogo oscuro") {
    DesignCatalog().preferredColorScheme(.dark)
}

#Preview("Catálogo claro") {
    DesignCatalog().preferredColorScheme(.light)
}
