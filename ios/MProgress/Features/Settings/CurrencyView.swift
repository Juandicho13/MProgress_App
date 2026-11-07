import SwiftUI
import SwiftData

/// Moneda (pantalla 28): buscador, más usadas y todas las de ISO 4217 de la A a la Z. Cada cuenta (espacio) tiene su moneda.
struct CurrencyView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @State private var query = ""

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }

    private var results: [Currency] { Currency.search(query) }
    private var searching: Bool { !HistoryMath.normalize(query).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Moneda").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                SearchField(text: $query, prompt: "Buscar moneda")
                if searching {
                    if results.isEmpty {
                        Text("No hay monedas con ese nombre o código.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    } else {
                        list(results)
                    }
                } else {
                    sectionTitle("Más usadas")
                    list(Currency.popular)
                    sectionTitle("Todas de la A a la Z")
                    list(Currency.all)
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text).appFont(.leyenda).foregroundStyle(Palette.texto2).accessibilityAddTraits(.isHeader)
    }

    private func list(_ items: [Currency]) -> some View {
        Card(padding: Spacing.s2) {
            LazyVStack(spacing: 0) {
                ForEach(items, id: \.code) { currency in
                    Button { pick(currency) } label: { row(currency) }.buttonStyle(.plain)
                    if currency.code != items.last?.code { Divider().overlay(Palette.linea) }
                }
            }
        }
    }

    private func row(_ currency: Currency) -> some View {
        let selected = space?.currencyCode == currency.code
        return HStack(spacing: Spacing.s3) {
            Text(currency.flag ?? "🌐").font(.system(size: 22)).frame(width: 28).accessibilityHidden(true)
            Text(currency.code).appFont(.titulo3).foregroundStyle(Palette.texto1).frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(currency.name).appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Text(currency.symbol).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
            }
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
