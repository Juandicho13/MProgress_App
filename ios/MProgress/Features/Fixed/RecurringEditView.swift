import SwiftUI
import SwiftData

/// Editar un pago fijo: nombre, monto, ciclo, fecha, con qué se paga, pausar, aviso y borrar.
struct RecurringEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }) private var products: [Product]

    let item: Recurring
    var currency: Currency = .cop

    @State private var kind: EntryKind
    @State private var name: String
    @State private var amount: Int64
    @State private var cycle: AddEntryModel.CycleChoice
    @State private var everyDays: Int
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var productId: UUID?
    @State private var method: PayMethod?
    @State private var active: Bool
    @State private var showsPayWith = false
    @State private var showsReminder = false
    @State private var confirmsDelete = false
    @State private var errorText: String?

    init(item: Recurring, currency: Currency = .cop) {
        self.item = item
        self.currency = currency
        _kind = State(initialValue: item.kind)
        _name = State(initialValue: item.name)
        _amount = State(initialValue: item.amountMinor)
        let choice: AddEntryModel.CycleChoice = switch item.cycle {
        case .anual: .anual
        case .cadaDias: .otra
        case .puntual: .puntual
        default: .mensual
        }
        _cycle = State(initialValue: choice)
        _everyDays = State(initialValue: item.cycle.intervalDays ?? 15)
        _hasDate = State(initialValue: !item.dateUnset)
        _date = State(initialValue: item.nextDate)
        _productId = State(initialValue: item.productId)
        _active = State(initialValue: item.active)
    }

    private var resolvedCycle: Cycle {
        switch cycle {
        case .puntual: .puntual
        case .mensual: .mensual
        case .anual: .anual
        case .otra: .cadaDias(max(1, everyDays))
        }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    private var payWithText: String {
        guard let product = products.first(where: { $0.id == productId }) else { return "Sin elegir" }
        return product.last4.map { "\(product.name) ·· \($0)" } ?? product.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        Text("Gasto").tag(EntryKind.gasto)
                        Text("Ingreso").tag(EntryKind.ingreso)
                    }
                    .pickerStyle(.segmented)
                    TextField("Nombre", text: $name)
                    MoneyField(title: "Monto", minor: $amount, currency: currency)
                        .listRowBackground(Color.clear)
                }
                Section("Cuándo") {
                    Picker("Ciclo", selection: $cycle) {
                        ForEach(AddEntryModel.CycleChoice.allCases) { choice in Text(choice.title).tag(choice) }
                    }
                    if cycle == .otra {
                        Stepper("Cada \(everyDays) días", value: $everyDays, in: 1...365)
                    }
                    Toggle("Ya sé la fecha", isOn: $hasDate).tint(Palette.brasa)
                    if hasDate {
                        DatePicker("Próximo cobro", selection: $date, displayedComponents: .date).tint(Palette.brasa)
                    }
                }
                Section {
                    Button { showsPayWith = true } label: {
                        HStack {
                            Text(kind == .ingreso ? "¿A dónde llega?" : "¿Con qué se paga?").foregroundStyle(Palette.texto1)
                            Spacer()
                            Text(payWithText).foregroundStyle(Palette.texto2)
                        }
                    }
                    Toggle("Activo", isOn: $active).tint(Palette.brasa)
                    Button("Configurar aviso") { showsReminder = true }
                        .disabled(!hasDate || !active)
                }
                Section {
                    Button("Borrar pago fijo", role: .destructive) { confirmsDelete = true }
                } footer: {
                    Text("Borrarlo no borra los pagos que ya registraste.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Pago fijo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.disabled(!canSave) }
            }
            .sheet(isPresented: $showsPayWith) {
                PayWithSheet(productId: $productId, method: $method, kind: kind)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsReminder) {
                ReminderEditView(recurring: item, currency: currency)
            }
            .confirmationDialog("¿Borrar \(item.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { delete() }
            }
            .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func save() {
        do {
            try LedgerStore(context: context, calendar: calendar).updateRecurring(
                item, kind: kind, name: name, amountMinor: amount, cycle: resolvedCycle,
                nextDate: hasDate ? date : nil, productId: productId, categoryId: item.categoryId, active: active)
            Task { await NotificationScheduler.reschedule(context: context) }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        let ledger = LedgerStore(context: context, calendar: calendar)
        do {
            try ledger.softDelete(item)
            Task { await NotificationScheduler.reschedule(context: context) }
            dismiss()
            undo?.show("Borraste \(item.name)") {
                try? ledger.restore(item)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
