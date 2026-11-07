import SwiftUI
import SwiftData

/// Editar un pago fijo: nombre, monto, ciclo, fecha (día del mes en los mensuales), cómo termina,
/// con qué se paga, pausar, aviso y borrar.
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
    /// "¿Cada cuánto?" igual que en el pago fijo nuevo: Semanal, Quincenal, Mensual u Otra.
    @State private var repeatDraft: RepeatDraft
    @FocusState private var countFocused: Bool
    /// Fila plegable abierta (una a la vez): Cada cuánto, Días, Día del mes o Próximo cobro, y Termina.
    @State private var open: NewFixedView.AddSection?
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var productId: UUID?
    @State private var method: PayMethod?
    @State private var active: Bool
    @State private var dayOfMonth: Int
    @State private var endChoice: RecurringEndChoice
    @State private var endDate: Date
    @State private var totalCount: Int
    @State private var reminderText = ""
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
        _repeatDraft = State(initialValue: RepeatDraft(cycle: item.cycle))
        _hasDate = State(initialValue: !item.dateUnset)
        _date = State(initialValue: item.nextDate)
        _productId = State(initialValue: item.productId)
        _active = State(initialValue: item.active)
        _dayOfMonth = State(initialValue: item.anchorDay)
        _endChoice = State(initialValue: item.endChoice)
        _endDate = State(initialValue: item.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: item.nextDate) ?? item.nextDate)
        _totalCount = State(initialValue: max(item.totalCount ?? 12, max(1, item.paidCount)))
    }

    private var resolvedCycle: Cycle { repeatDraft.cycle }

    private var isQuincenal: Bool { repeatDraft.choice == .quincenal }

    /// "Nunca", "Hasta 15 mar 2027" o "12 cuotas".
    private var endSummary: String {
        switch endChoice {
        case .nunca: "Nunca"
        case .fecha: "Hasta \(RecurringEnd.fullDate(endDate, calendar: calendar))"
        case .cuotas: "\(totalCount) \(totalCount == 1 ? "cuota" : "cuotas")"
        }
    }

    /// Abre una fila y cierra la que estaba abierta (o la cierra si era esa).
    private func toggle(_ section: NewFixedView.AddSection) {
        countFocused = false
        withAnimation(.snappy) { open = open == section ? nil : section }
    }

    /// "¿Cada cuánto?". Otra abre de una su fila; las filas que ya no aplican se cierran.
    private func choose(_ choice: RepeatChoice) {
        repeatDraft.choice = choice
        withAnimation(.snappy) {
            if choice == .otra { open = .cadaCuanto } else if open == .cadaCuanto || open == .dias { open = nil }
        }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 && repeatDraft.isValid }

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
                Section {
                    SegmentedPill(options: RepeatChoice.allCases.filter { $0 != .unaVez }.map { (value: $0, title: $0.title) },
                                  selection: Binding(get: { repeatDraft.choice }, set: { choose($0) }))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    if repeatDraft.choice == .otra {
                        DisclosureRow(title: "Cada cuánto", value: repeatDraft.title, expanded: open == .cadaCuanto) {
                            toggle(.cadaCuanto)
                        } content: {
                            RepeatOtherEditor(draft: $repeatDraft, summary: hasDate ? repeatDraft.summary(next: resolvedDate, calendar: calendar, now: .now) : nil,
                                              focused: $countFocused)
                        }
                    }
                    if isQuincenal {
                        DisclosureRow(title: "Días", value: repeatDraft.quincena.title, expanded: open == .dias) {
                            toggle(.dias)
                        } content: {
                            QuincenaDaysEditor(days: $repeatDraft.quincena)
                        }
                    }
                    Toggle("Ya sé la fecha", isOn: $hasDate).tint(Palette.brasa)
                    if hasDate {
                        if isQuincenal {
                            HStack {
                                Text(kind == .ingreso ? "Próximo pago" : "Próximo cobro").foregroundStyle(Palette.texto1)
                                Spacer()
                                Text(DueText.shortDate(resolvedDate, calendar: calendar)).foregroundStyle(Palette.texto2)
                            }
                        } else if resolvedCycle.isMonthly {
                            DisclosureRow(title: "Día del mes", value: "el \(dayOfMonth)", expanded: open == .diaDelMes) {
                                toggle(.diaDelMes)
                            } content: {
                                VStack(alignment: .leading, spacing: Spacing.s2) {
                                    DayOfMonthGrid(day: $dayOfMonth)
                                    Text("Próximo \(kind == .ingreso ? "pago" : "cobro"): \(DueText.shortDate(resolvedDate, calendar: calendar))")
                                        .appFont(.leyenda)
                                        .foregroundStyle(Palette.texto2)
                                }
                            }
                        } else {
                            DisclosureRow(title: kind == .ingreso ? "Próximo pago" : "Próximo cobro",
                                          value: DueText.shortDate(date, calendar: calendar), expanded: open == .fecha) {
                                toggle(.fecha)
                            } content: {
                                EasyDatePicker(title: "Fecha de pago", date: $date, allowsTime: false)
                            }
                        }
                    }
                    if resolvedCycle.repeats {
                        DisclosureRow(title: "Termina", value: endSummary, expanded: open == .termina) {
                            toggle(.termina)
                        } content: {
                            EndRuleEditor(choice: $endChoice, endDate: $endDate, count: $totalCount, paidCount: item.paidCount, showsTitle: false)
                        }
                    }
                } header: {
                    Text("¿Cada cuánto?")
                } footer: {
                    if let text = item.endText(calendar: calendar) { Text("Ahora: \(text)") }
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
                    Button { showsReminder = true } label: {
                        HStack {
                            Text("Aviso").foregroundStyle(Palette.texto1)
                            Spacer()
                            Text(reminderText).foregroundStyle(Palette.texto2)
                        }
                    }
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
            .sheet(isPresented: $showsReminder, onDismiss: loadReminder) {
                ReminderEditView(recurring: item, currency: currency)
            }
            .onAppear(perform: loadReminder)
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

    /// Mensual: si se cambió el día, el próximo cobro con ese día desde hoy; si no, la fecha que ya tenía
    /// (así un cobro vencido sin pagar no se salta).
    private var resolvedDate: Date {
        if case .quincenal(let days) = resolvedCycle {
            // Quincenal: la fecha que ya tenía si sigue con los mismos días; si no, el próximo día de quincena desde hoy.
            if item.cycle == resolvedCycle && !item.dateUnset { return item.nextDate }
            return QuincenaMath.onOrAfter(.now, days: days, calendar: calendar)
        }
        guard resolvedCycle.isMonthly else { return date }
        if dayOfMonth == item.anchorDay && !item.dateUnset && item.cycle.isMonthly { return item.nextDate }
        return OnboardingPlan.nextDate(day: dayOfMonth, from: .now, calendar: calendar)
    }

    private func loadReminder() {
        let own = try? PlanningStore(context: context).reminder(for: item.id)
        let mode = own?.mode ?? .general
        switch mode {
        case .general:
            reminderText = "Como el general"
        case .personalizado:
            reminderText = AlertSettings.summary(enabled: true, daysBefore: own?.daysBefore ?? 3, atMinutes: own?.atMinutes ?? 540)
        case .ninguno:
            reminderText = "Sin aviso"
        }
    }

    private func save() {
        let repeats = resolvedCycle.repeats
        do {
            try LedgerStore(context: context, calendar: calendar).updateRecurring(
                item, kind: kind, name: name, amountMinor: amount, cycle: resolvedCycle,
                nextDate: hasDate ? resolvedDate : nil, productId: productId, categoryId: item.categoryId, active: active,
                endDate: repeats && endChoice == .fecha ? endDate : nil,
                totalCount: repeats && endChoice == .cuotas ? totalCount : nil,
                anchorDay: resolvedCycle.isMonthly && hasDate ? dayOfMonth : nil)
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
