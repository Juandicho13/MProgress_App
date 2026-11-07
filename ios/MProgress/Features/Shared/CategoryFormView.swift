import SwiftUI
import SwiftData

/// Nueva categoría o editar una propia (desde el selector de categoría de Agregar y de editar): nombre y un ícono de
/// una cuadrícula de 30; al editar, Borrar con Deshacer. Mientras no elijas ícono, se sugiere uno por el nombre
/// ("Mascotas" da la huella). Igual que CategoryFormSheet de Android.
struct CategoryFormView: View {
    let spaceId: UUID
    let editing: SpendCategory?
    /// La categoría guardada (nueva o cambiada). Quien abre el formulario decide si la elige.
    let onSaved: (SpendCategory) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var all: [SpendCategory]

    @State private var name: String
    @State private var icon: String
    @State private var iconTouched: Bool
    @State private var errorText: String?

    init(spaceId: UUID, editing: SpendCategory? = nil, onSaved: @escaping (SpendCategory) -> Void) {
        self.spaceId = spaceId
        self.editing = editing
        self.onSaved = onSaved
        _name = State(initialValue: editing?.name ?? "")
        _icon = State(initialValue: editing?.icon ?? CategoryForm.defaultIcon)
        _iconTouched = State(initialValue: editing != nil)
    }

    private var existing: [(id: UUID, name: String)] {
        all.filter { $0.ownerSpaceId == nil || $0.ownerSpaceId == spaceId }.map { (id: $0.id, name: $0.name) }
    }
    private var problem: CategoryForm.Problem? { CategoryForm.problem(name: name, existing: existing, editing: editing?.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    HStack {
                        Spacer()
                        IconTile(content: .symbol(icon), tint: Palette.brasaVelo, foreground: Palette.brasaTinta, size: 72)
                        Spacer()
                    }
                    SectionLabel(text: "Nombre")
                    TextField("Mascotas, viajes, regalos", text: $name)
                        .appFont(.cuerpo)
                        .foregroundStyle(Palette.texto1)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(.horizontal, Spacing.s4)
                        .frame(minHeight: Size.toqueMinimo)
                        .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                        .onChange(of: name) { _, value in
                            if value.count > CategoryForm.maxLength + 5 { name = String(value.prefix(CategoryForm.maxLength + 5)) }
                            if !iconTouched, let suggested = CategoryForm.suggestedIcon(for: value) { icon = suggested }
                        }
                    if problem == .duplicate {
                        Text(CategoryForm.Problem.duplicate.message).appFont(.leyenda).foregroundStyle(Palette.peligro)
                    }
                    SectionLabel(text: "Ícono")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 5), spacing: Spacing.s2) {
                        ForEach(CategoryForm.icons, id: \.symbol) { item in
                            let isSelected = item.symbol == icon
                            Button {
                                icon = item.symbol
                                iconTouched = true
                            } label: {
                                IconTile(content: .symbol(item.symbol), tint: isSelected ? Palette.brasaVelo : Palette.superficie3,
                                         foreground: isSelected ? Palette.brasaTinta : Palette.texto1, size: 56)
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? Palette.brasa : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.words.components(separatedBy: " ").first ?? item.symbol)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    if let editing {
                        Button("Borrar categoría", role: .destructive) { delete(editing) }
                            .buttonStyle(.secondary)
                        Text("Los movimientos que la usan quedan sin categoría.").appFont(.leyenda).foregroundStyle(Palette.texto2)
                    }
                }
                .padding(Spacing.margen)
            }
            .navigationTitle(editing == nil ? "Nueva categoría" : "Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(problem != nil)
                }
            }
            .background(Palette.superficie2)
            .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func save() {
        guard problem == nil else { return }
        let store = CategoryStore(context: context)
        do {
            if let editing {
                try store.update(editing, name: name, icon: icon)
                onSaved(editing)
            } else {
                onSaved(try store.add(name: name, icon: icon, spaceId: spaceId))
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete(_ category: SpendCategory) {
        let title = category.name
        do {
            try CategoryStore(context: context).delete(category)
            dismiss()
            undo?.show("Borraste la categoría \(title)") {
                try? CategoryStore(context: context).restore(category)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
