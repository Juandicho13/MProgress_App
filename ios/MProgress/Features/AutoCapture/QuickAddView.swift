import SwiftUI
import SwiftData
import Observation

/// Abre el registro rápido cuando lo pide el atajo (doble toque atrás) o un widget.
@MainActor
@Observable
final class QuickAddRouter {
    static let shared = QuickAddRouter()
    var pending = false
}

/// Registro rápido: 1) monto y si es gasto o ingreso, 2) de dónde sale o a dónde entra, y guardar.
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }, sort: \Product.createdAt) private var allProducts: [Product]
    @Query(filter: #Predicate<Institution> { $0.deletedAt == nil }) private var institutions: [Institution]
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var categories: [SpendCategory]

    @State private var kind: EntryKind = .gasto
    @State private var amount = AmountInput()
    @State private var step = 0
    @State private var productId: UUID?
    @State private var categoryId: UUID?
    @State private var errorText: String?

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    /// De dónde sale un gasto: tarjetas, cuentas y efectivo. A dónde entra un ingreso: cuentas, cajitas y efectivo.
    private var products: [Product] {
        allProducts.filter { $0.spaceId == space?.id && (kind == .gasto ? $0.kind != .bolsillo : $0.kind != .credito && $0.kind != .debito) }
    }
    private var recentCategories: [SpendCategory] {
        Array(categories.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }.prefix(8))
    }

    var body: some View {
        VStack(spacing: Spacing.s4) {
            HStack {
                CircleIconButton(systemImage: step == 0 ? "xmark" : "chevron.left", label: step == 0 ? "Cerrar" : "Atrás") {
                    if step == 0 { dismiss() } else { withAnimation(.snappy) { step = 0 } }
                }
                Spacer()
                Text("Registro rápido").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Spacer()
                Color.clear.frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
            }
            .padding(.top, Spacing.s4)

            if step == 0 {
                amountStep
            } else {
                sourceStep
            }
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s2)
        .background(Palette.superficie2.ignoresSafeArea())
        .onAppear { amount = AmountInput(currency: currency) }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var amountStep: some View {
        VStack(spacing: Spacing.s4) {
            SegmentedPill(options: [(value: EntryKind.gasto, title: "Gasto"), (value: EntryKind.ingreso, title: "Ingreso")], selection: $kind)
            AmountDisplay(input: amount, active: true)
            Spacer(minLength: 0)
            Button(kind == .gasto ? "¿De dónde sale?" : "¿A dónde entra?") {
                withAnimation(.snappy) { step = 1 }
            }
            .buttonStyle(.primary)
            .disabled(amount.money.isZero)
            NumericKeypad(input: $amount)
        }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(alignment: .firstTextBaseline) {
                Text(kind == .gasto ? "¿De dónde sale?" : "¿A dónde entra?").appFont(.titulo2).foregroundStyle(Palette.texto1)
                Spacer()
                Text(signedAmount(amount.money.minor, kind, currency)).appFont(.cifra).foregroundStyle(kind == .ingreso ? Palette.hielo : Palette.texto1)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Card(padding: Spacing.s3) {
                        VStack(spacing: Spacing.s2) {
                            ForEach(products) { product in
                                Button { productId = product.id } label: { productRow(product) }
                                    .buttonStyle(.plain)
                            }
                            Button { productId = nil } label: {
                                ListRow(tile: IconTile(content: .symbol("questionmark")), title: "Sin elegir", subtitle: "Lo decides después") {
                                    if productId == nil { check }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if kind == .gasto {
                        SectionLabel(text: "Categoría (opcional)")
                        FlowLayout(spacing: Spacing.s2) {
                            ForEach(recentCategories) { category in
                                Chip(title: category.name, systemImage: category.icon, selected: categoryId == category.id) {
                                    categoryId = categoryId == category.id ? nil : category.id
                                }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            Button("Guardar") { save() }.buttonStyle(.primary)
        }
    }

    private func productRow(_ product: Product) -> some View {
        let bank = institutions.first { $0.id == product.institutionId }
        return ListRow(tile: InstitutionStyle.tile(name: bank?.name ?? product.name, hex: bank?.colorHex),
                       title: product.last4.map { "\(product.name) ·· \($0)" } ?? product.name,
                       subtitle: bank?.name ?? "") {
            if productId == product.id { check }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(productId == product.id ? [.isSelected] : [])
    }

    private var check: some View {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.brasa)
    }

    private func save() {
        guard let space else { return }
        let product = products.first { $0.id == productId }
        let category = categories.first { $0.id == categoryId }
        let name = category?.name ?? (kind == .gasto ? "Gasto rápido" : "Ingreso rápido")
        do {
            let entry = try LedgerStore(context: context, calendar: calendar).addEntry(
                spaceId: space.id, kind: kind, amountMinor: amount.money.minor, name: name, categoryId: category?.id,
                productId: product?.id, createdBy: LocalIdentity.userId)
            dismiss()
            undo?.show("Anotado: \(signedAmount(entry.amountMinor, kind, currency))") {
                try? LedgerStore(context: context).softDelete(entry)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Guía del doble toque atrás: Atajos + Accesibilidad.
struct BackTapGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("Crea el atajo", "Abre Atajos, toca +, busca la acción \"Registro rápido\" de MProgress y guárdalo con ese nombre."),
        ("Abre Tocar atrás", "En Ajustes del iPhone: Accesibilidad › Tocar › Tocar atrás."),
        ("Elige Doble toque", "Baja hasta Atajos y elige \"Registro rápido\"."),
        ("Pruébalo", "Toca dos veces la parte de atrás del iPhone: se abre MProgress listo para escribir el monto."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("Anota un gasto o un ingreso tocando dos veces la parte de atrás de tu iPhone. Escribes el monto, eliges si entra o sale y de dónde, y listo.")
                        .appFont(.cuerpo)
                        .foregroundStyle(Palette.texto2)
                    ForEach(Array(steps.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: Spacing.s3) {
                            Text("\(item.offset + 1)")
                                .appFont(.titulo3)
                                .foregroundStyle(Palette.sobreBrasa)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Palette.brasa))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.element.0).appFont(.titulo3).foregroundStyle(Palette.texto1)
                                Text(item.element.1).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if let url = URL(string: "shortcuts://") {
                        Link("Abrir Atajos", destination: url).buttonStyle(.primary)
                    }
                    Button("Probar ahora") {
                        dismiss()
                        QuickAddRouter.shared.pending = true
                    }
                    .buttonStyle(.secondary)
                    Text("Apple no deja que una app active el doble toque por sí sola; con estos pasos queda listo en un minuto.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Doble toque atrás")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}
