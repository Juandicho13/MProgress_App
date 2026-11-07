import SwiftUI
import SwiftData

/// Ajustes › Nombres de comercios: lo que la app aprendió al cambiar el nombre de un pago que llegó solo
/// (SMS, Apple Pay o recibo). Cada regla se puede cambiar o borrar.
struct MerchantAliasesView: View {
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<MerchantAlias> { $0.deletedAt == nil }, sort: \MerchantAlias.name) private var allAliases: [MerchantAlias]
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var categories: [SpendCategory]

    @State private var editing: MerchantAlias?

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var aliases: [MerchantAlias] { allAliases.filter { $0.spaceId == space?.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Nombres de comercios").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                if aliases.isEmpty {
                    emptyCard
                } else {
                    Card(padding: Spacing.s3) {
                        VStack(spacing: Spacing.s2) {
                            ForEach(aliases) { alias in
                                Button { editing = alias } label: { row(alias) }
                                    .buttonStyle(.plain)
                                if alias.id != aliases.last?.id { Divider().overlay(Palette.linea) }
                            }
                        }
                    }
                    Text("Cuando llega un pago de uno de estos comercios, la app le pone el nombre y la categoría que elegiste. Toca uno para cambiarlo o borrarlo.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { alias in
            MerchantAliasFormView(alias: alias, categories: available) { deleted in
                undo?.show("Borraste \(deleted.name)") {
                    try? MerchantAliasStore(context: context).restore(deleted)
                }
            }
        }
    }

    private var available: [SpendCategory] {
        categories.filter { $0.ownerSpaceId == nil || $0.ownerSpaceId == space?.id }
    }

    private var emptyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                IconTile(content: .symbol("storefront"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta)
                Text("Aún no hay nombres de comercios").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text("Cuando cambies el nombre o la categoría de un pago que llegó solo (SMS, Apple Pay o recibo), la app lo recuerda y lo usa la próxima vez que pagues ahí.")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }

    private func row(_ alias: MerchantAlias) -> some View {
        let category = alias.categoryId.flatMap { id in categories.first { $0.id == id }?.name } ?? "Sin categoría"
        return ListRow(tile: IconTile(content: .initials(alias.name.isEmpty ? "?" : alias.name)),
                       title: alias.name,
                       subtitle: "\(alias.merchantKey) · \(category)",
                       showsChevron: true) { EmptyView() }
            .accessibilityHint("Toca para cambiarlo o borrarlo")
    }
}

/// Cambiar el nombre o la categoría de un comercio, o borrarlo.
private struct MerchantAliasFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let alias: MerchantAlias
    let categories: [SpendCategory]
    let onDelete: (MerchantAlias) -> Void

    @State private var name: String
    @State private var categoryId: UUID?
    @State private var confirmsDelete = false

    init(alias: MerchantAlias, categories: [SpendCategory], onDelete: @escaping (MerchantAlias) -> Void) {
        self.alias = alias
        self.categories = categories
        self.onDelete = onDelete
        _name = State(initialValue: alias.name)
        _categoryId = State(initialValue: alias.categoryId)
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Llega del banco como", value: alias.merchantKey)
                    TextField("Nombre", text: $name)
                    Picker("Categoría", selection: $categoryId) {
                        Text("Sin categoría").tag(UUID?.none)
                        ForEach(categories) { category in Text(category.name).tag(UUID?.some(category.id)) }
                    }
                } footer: {
                    Text("Así se anota la próxima vez que pagues en este comercio.")
                }
                Section {
                    Button("Borrar", role: .destructive) { confirmsDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Comercio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        try? MerchantAliasStore(context: context).update(alias, name: name, categoryId: categoryId)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("¿Borrar \(alias.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    try? MerchantAliasStore(context: context).delete(alias)
                    onDelete(alias)
                    dismiss()
                }
            } message: {
                Text("Los pagos que ya registraste no cambian.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
