import SwiftUI
import SwiftData

/// Agregar movimiento (pantalla 7): un gasto o un ingreso de una vez, con teclado propio. Nombre, gasto o ingreso, monto, la fecha
/// en el calendario de semana (con el mes completo y "Agregar hora") y una tarjeta con Categoría, con qué se pagó y Notas.
/// Los pagos que se repiten se crean en NewFixedView: si alguien abre Agregar con un ciclo que se repite (Inicio, Pagos fijos o un
/// atajo), esta hoja muestra el pago fijo nuevo.
struct AddEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @AppStorage(AlertSettings.budgetsKey) private var budgetAlerts = true
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var categories: [SpendCategory]

    let spaceId: UUID
    @State private var model: AddEntryModel
    @State private var showsIcons = false
    @State private var showsCategories = false
    @State private var showsPayWith = false
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }) private var products: [Product]
    @State private var errorText: String?
    @FocusState private var focus: Field?

    private enum Field { case name, notes }

    private let startsWithMonth: Bool
    /// Pedido con un ciclo que se repite: se muestra el pago fijo nuevo.
    private let fixedCycle: Cycle?
    private let currency: Currency

    /// `cycle` distinto de Una vez abre el pago fijo nuevo. `startsWithMonth` abre el mes completo de entrada (vistas previas).
    init(spaceId: UUID, kind: EntryKind = .gasto, cycle: AddEntryModel.CycleChoice = .puntual, currency: Currency = .cop,
         startsWithMonth: Bool = false) {
        self.spaceId = spaceId
        self.startsWithMonth = startsWithMonth
        self.fixedCycle = cycle.repeats ? cycle : nil
        self.currency = currency
        _model = State(initialValue: AddEntryModel(kind: kind, cycle: .puntual, currency: currency))
    }

    /// Borrador con nombre y monto (recibo escaneado). `merchant` es el comercio leído y `categoryId` la categoría aprendida.
    init(spaceId: UUID, prefillName: String, amountMinor: Int64, source: EntrySource, currency: Currency = .cop,
         merchant: String? = nil, categoryId: UUID? = nil) {
        self.spaceId = spaceId
        self.startsWithMonth = false
        self.fixedCycle = nil
        self.currency = currency
        _model = State(initialValue: AddEntryModel(prefillName: prefillName, amountMinor: amountMinor, source: source, currency: currency,
                                                   merchant: merchant, categoryId: categoryId))
    }

    /// Editar un movimiento ya guardado (F04-02).
    init(editing entry: Entry, currency: Currency = .cop) {
        self.spaceId = entry.spaceId
        self.startsWithMonth = false
        self.fixedCycle = nil
        self.currency = currency
        _model = State(initialValue: AddEntryModel(editing: entry, currency: currency))
    }

    private var category: SpendCategory? { categories.first { $0.id == model.categoryId } }

    var body: some View {
        if let fixedCycle {
            NewFixedView(spaceId: spaceId, kind: model.kind, cycle: fixedCycle, currency: currency)
        } else {
            oneOff
        }
    }

    private var oneOff: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: Spacing.s4) {
                    nameRow
                    SegmentedPill(options: [(value: EntryKind.gasto, title: "Gasto"), (value: EntryKind.ingreso, title: "Ingreso")],
                                  selection: $model.kind)
                    EditableAmountField(input: model.amount, editing: focus == nil, showsCaption: false) { focus = nil }
                    Card(padding: Spacing.s3) {
                        EasyDatePicker(title: "Fecha", date: $model.date, startsExpanded: startsWithMonth)
                    }
                    details
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s3)
            }
            .scrollDismissesKeyboard(.interactively)
            if focus == nil {
                NumericKeypad(input: $model.amount)
                    .padding(.horizontal, Spacing.margen)
                    .padding(.bottom, Spacing.s2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: focus)
        .background(Palette.superficie2.ignoresSafeArea())
        .sheet(isPresented: $showsIcons) {
            IconPickerView(selection: $model.icon, name: model.name)
        }
        .sheet(isPresented: $showsPayWith) {
            PayWithSheet(productId: $model.productId, method: $model.method, kind: model.kind)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Radius.hoja)
        }
        .sheet(isPresented: $showsCategories) {
            CategoryPickerView(selection: $model.categoryId, spaceId: spaceId)
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
            Spacer()
            Text(model.isEditing ? "Editar" : "Agregar").appFont(.titulo3).foregroundStyle(Palette.texto1)
            Spacer()
            CircleIconButton(systemImage: "checkmark", label: "Guardar", filled: true) { save() }
                .disabled(!model.canSave)
                .opacity(model.canSave ? 1 : 0.4)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.top, Spacing.s4)
    }

    private var nameRow: some View {
        HStack(spacing: Spacing.s3) {
            Button {
                showsIcons = true
            } label: {
                IconTile(content: model.icon.map { IconTile.Content.symbol($0) } ?? .initials(model.name.isEmpty ? "?" : model.name), size: 60)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Elegir ícono")
            VStack(alignment: .leading, spacing: 2) {
                Text("Nombre").appFont(.leyenda).foregroundStyle(Palette.texto2)
                TextField("Netflix, mercado, sueldo", text: $model.name)
                    .appFont(.titulo2)
                    .foregroundStyle(Palette.texto1)
                    .focused($focus, equals: .name)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    private var details: some View {
        Card(padding: Spacing.s2) {
            VStack(spacing: 0) {
                Button {
                    focus = nil
                    showsCategories = true
                } label: {
                    detailRow(title: "Categoría", value: category?.name ?? "Sin categoría")
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.linea)
                Button {
                    focus = nil
                    showsPayWith = true
                } label: {
                    detailRow(title: model.kind == .ingreso ? "¿A dónde llegó?" : "¿Con qué pagaste?", value: payWithText)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.linea)
                HStack {
                    Text("Notas").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    TextField("Opcional", text: $model.notes, axis: .vertical)
                        .appFont(.cuerpo)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Palette.texto2)
                        .focused($focus, equals: .notes)
                }
                .padding(.horizontal, Spacing.s2)
                .frame(minHeight: 56)
            }
        }
    }

    private var payWithText: String {
        guard let product = products.first(where: { $0.id == model.productId }) else { return "Sin elegir" }
        let name = product.last4.map { "\(product.name) ·· \($0)" } ?? product.name
        return [name, model.method?.title].compactMap { $0 }.joined(separator: " · ")
    }

    private func detailRow(title: String, value: String, chevron: Bool = true) -> some View {
        HStack {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer()
            Text(value).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.texto2)
            }
        }
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func save() {
        do {
            let entry = try model.save(context: context, spaceId: spaceId, calendar: calendar)
            if budgetAlerts, !model.isEditing, let entry,
               let crossing = try? PlanningStore(context: context).budgetCrossings(spaceId: spaceId, newEntry: entry, calendar: calendar).first {
                let name = crossing.budget.categoryId.flatMap { id in categories.first { $0.id == id }?.name } ?? "el total del mes"
                let percent = Int((crossing.ratio * 100).rounded())
                undo?.show(crossing.level == .superado ? "Te pasaste del límite de \(name) (\(percent) %)" : "Vas en \(percent) % del límite de \(name)")
            }
            let offerAlerts = model.createdRecurring
            Task {
                await NotificationScheduler.reschedule(context: context)
                // Momento justo para pedir el permiso: se acaba de crear un pago fijo.
                if offerAlerts { await NotificationAsk.shared.offerIfNeeded() }
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    return AddEntryView(spaceId: space.id)
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}
