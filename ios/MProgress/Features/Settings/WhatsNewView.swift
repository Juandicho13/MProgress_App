import SwiftUI

/// Novedades (pantalla 30): tarjetas por versión.
struct WhatsNewView: View {
    private let versions: [(version: String, date: String, items: [String])] = [
        ("1.0", "Nov 2026", [
            "Te quedan, pagos fijos y calendario de cobros",
            "Bancos con tarjetas débito y crédito y cajitas con rendimiento",
            "Resumen con gráficas, límites con aviso y metas de ahorro",
            "Apple Pay y SMS del banco con Atajos, y escanear recibos",
            "Vidrio con transparencia ajustable y respaldo cifrado",
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Novedades").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                ForEach(versions, id: \.version) { item in
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            HStack {
                                Text("Versión \(item.version)").appFont(.titulo3).foregroundStyle(Palette.texto1)
                                Spacer()
                                Text(item.date).appFont(.leyenda).foregroundStyle(Palette.texto2)
                            }
                            ForEach(item.items, id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                                    Circle().fill(Palette.brasa).frame(width: 5, height: 5)
                                    Text(line).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}
