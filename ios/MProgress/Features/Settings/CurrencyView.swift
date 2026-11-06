import SwiftUI
import SwiftData

/// Moneda (pantalla 28): buscador y lista. Cada cuenta (espacio) tiene su moneda.
struct CurrencyView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @State private var query = ""

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }

    private var items: [Currency] {
        let key = HistoryMath.normalize(query)
        guard !key.isEmpty else { return Currency.all }
        return Currency.all.filter { HistoryMath.normalize("\($0.code) \($0.name)").contains(key) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Moneda").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                SearchField(text: $query, prompt: "Buscar moneda")
                Card(padding: Spacing.s2) {
                    VStack(spacing: 0) {
                        ForEach(items, id: \.code) { currency in
                            Button { pick(currency) } label: { row(currency) }.buttonStyle(.plain)
                            if currency.code != items.last?.code { Divider().overlay(Palette.linea) }
                        }
                    }
                }
                Text("Cada cuenta puede tener su moneda. Un viaje en euros no cambia tu cuenta personal. Cambiar la moneda no convierte los montos ya guardados.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
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

    private func row(_ currency: Currency) -> some View {
        let selected = space?.currencyCode == currency.code
        return HStack(spacing: Spacing.s3) {
            Text(currency.code).appFont(.titulo3).foregroundStyle(Palette.texto1).frame(width: 52, alignment: .leading)
            Text(currency.symbol).appFont(.cuerpo2).foregroundStyle(Palette.texto2).frame(width: 40, alignment: .leading)
            Text(currency.name).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? Palette.brasa : Palette.lineaControl)
        }
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func pick(_ currency: Currency) {
        guard let space else { return }
        space.currencyCode = currency.code
        space.touch()
        try? context.save()
    }
}
