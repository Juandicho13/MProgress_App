import SwiftUI
import SwiftData

/// Nuevo pago fijo (desde Pagos fijos, Inicio o un atajo): nombre, gasto o ingreso, monto y "¿Cada cuánto?" (Semanal, Quincenal,
/// Mensual u Otra). Lo demás va en filas plegadas que se abren una a la vez: Cada cuánto (Otra), Días (Quincenal), Día del mes
/// (mensuales), Próximo cobro (los demás) y Termina. Guarda con AddPlan como antes lo hacía Agregar: si la fecha ya pasó, anota el
/// movimiento y deja el pago fijo desde la siguiente.
struct NewFixedView: View {
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
    /// El número de Otra se escribe con el teclado del sistema.
    @FocusState private var countFocused: Bool
    /// Fila plegable abierta (una a la vez). Todas cerradas al abrir, para que lo esencial y el teclado quepan.
    @State private var open: AddSection?
    /// El teclado del monto. Se esconde al abrir una fila y vuelve al tocar el monto.
    @State private var keypadShown = true

    private enum Field { case name, notes }

    /// Filas plegables del pago fijo.
    enum AddSection { case cadaCuanto, dias, diaDelMes, fecha, termina }

    private let startsWithMonth: Bool

    /// `cycle` es el ciclo con que abre (Mensual si llega Una vez). `startSection` y `startsWithMonth` abren una fila o el mes
    /// completo de entrada (vistas previas).
    init(spaceId: UUID, kind: EntryKind = .gasto, cycle: Cycle = .mensual, currency: Currency = .cop,
         startSection: AddSection? = nil, startsWithMonth: Bool = false) {
        self.spaceId = spaceId
        self.startsWithMonth = startsWithMonth
        _model = State(initialValue: AddEntryModel(kind: kind, cycle: cycle.repeats ? cycle : .mensual, currency: currency))
        _open = State(initialValue: startSection)
        _keypadShown = State(initialValue: startSection == nil)
    }

    private var category: SpendCategory? { categories.first { $0.id == model.categoryId } }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: Spacing.s4) {
                    nameRow
                    SegmentedPill(options: [(value: EntryKind.gasto, title: "Gasto"), (value: EntryKind.ingreso, title: "Ingreso")],
                                  selection: $model.kind)
                    EditableAmountField(input: model.amount, editing: showsKeypad, showsCaption: false) { showKeypad() }
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        SectionLabel(text: "¿Cada cuánto?")
                        SegmentedPill(options: RepeatChoice.allCases.filter { $0 != .unaVez }.map { (value: $0, title: $0.title) },
                                      selection: Binding(get: { model.repeatDraft.choice }, set: { choose($0) }))
                    }
                    repeatCard
                    details
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s3)
            }
            .scrollDismissesKeyboard(.interactively)
            if showsKeypad {
                NumericKeypad(input: $model.amount)
                    .padding(.horizontal, Spacing.margen)
                    .padding(.bottom, Spacing.s2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: focus)
        .animation(.snappy, value: countFocused)
        .animation(.snappy, value: keypadShown)
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
            Text("Pago fijo").appFont(.titulo3).foregroundStyle(Palette.texto1)
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

    /// El teclado del monto se ve si no se escribe en otro campo y ninguna fila está abierta.
    private var showsKeypad: Bool { keypadShown && focus == nil && !countFocused }

    private func showKeypad() {
        focus = nil
        countFocused = false
        withAnimation(.snappy) {
            open = nil
            keypadShown = true
        }
    }

    /// Abre una fila y cierra la que estaba abierta (o la cierra si era esa).
    private func toggle(_ section: AddSection) {
        focus = nil
        countFocused = false
        withAnimation(.snappy) {
            open = open == section ? nil : section
            if open != nil { keypadShown = false }
        }
    }

    /// "¿Cada cuánto?". Otra abre de una su fila "Cada cuánto"; lo demás deja las filas cerradas.
    private func choose(_ choice: RepeatChoice) {
        model.selectRepeat(choice, calendar: calendar)
        withAnimation(.snappy) {
            if choice == .otra {
                open = .cadaCuanto
                keypadShown = false
            } else if open == .cadaCuanto || (open == .dias && choice != .quincenal) || (open == .diaDelMes && !model.usesDayOfMonth)
                        || (open == .fecha && (model.usesDayOfMonth || choice == .quincenal)) {
                open = nil
            }
        }
    }

    /// Filas plegadas: Cada cuánto (Otra), Días (Quincenal), Día del mes (mensuales), Próximo cobro (los demás) y Termina.
    private var repeatCard: some View {
        Card(padding: Spacing.s2) {
            VStack(spacing: 0) {
                if model.repeatDraft.choice == .otra {
                    DisclosureRow(title: "Cada cuánto", value: model.repeatDraft.title, expanded: open == .cadaCuanto) {
                        toggle(.cadaCuanto)
                    } content: {
                        RepeatOtherEditor(draft: $model.repeatDraft, summary: model.otherSummary(calendar: calendar), focused: $countFocused)
                    }
                    Divider().overlay(Palette.linea)
                }
                if model.repeatDraft.choice == .quincenal {
                    DisclosureRow(title: "Días", value: model.repeatDraft.quincena.title, expanded: open == .dias) {
                        toggle(.dias)
                    } content: {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            QuincenaDaysEditor(days: Binding(get: { model.repeatDraft.quincena },
                                                             set: { model.setQuincena($0, calendar: calendar) }))
                            Text(model.planSummary(calendar: calendar)).appFont(.leyenda).foregroundStyle(Palette.texto2)
                        }
                    }
                    Divider().overlay(Palette.linea)
                }
                if model.usesDayOfMonth {
                    DisclosureRow(title: "Día del mes", value: "el \(model.dayOfMonth(calendar: calendar))", expanded: open == .diaDelMes) {
                        toggle(.diaDelMes)
                    } content: {
                        dayOfMonthEditor
                    }
                    Divider().overlay(Palette.linea)
                }
                if !model.usesDayOfMonth && model.repeatDraft.choice != .quincenal {
                    DisclosureRow(title: model.kind == .ingreso ? "Próximo pago" : "Próximo cobro",
                                  value: DueText.shortDate(model.date, calendar: calendar), expanded: open == .fecha) {
                        toggle(.fecha)
                    } content: {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            EasyDatePicker(title: "Fecha de pago", date: Binding(get: { model.date }, set: { model.setDate($0) }),
                                           startsExpanded: startsWithMonth)
                            Text(model.planSummary(calendar: calendar)).appFont(.leyenda).foregroundStyle(Palette.texto2)
                        }
                    }
                    Divider().overlay(Palette.linea)
                }
                DisclosureRow(title: "Termina", value: model.endSummary(calendar: calendar), expanded: open == .termina) {
                    toggle(.termina)
                } content: {
                    EndRuleEditor(choice: $model.endChoice, endDate: $model.endDate, count: $model.totalCount, showsTitle: false)
                }
            }
        }
    }

    /// Cuadrícula de 1 a 31, "Ya lo pagué este mes" si el día ya pasó y lo que se va a guardar.
    private var dayOfMonthEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            DayOfMonthGrid(day: Binding(get: { model.dayOfMonth(calendar: calendar) },
                                        set: { model.pickDay($0, calendar: calendar) }))
            if DayOfMonth.hasPassed(day: model.dayOfMonth(calendar: calendar), now: .now, calendar: calendar) {
                Toggle(isOn: Binding(get: { model.paidThisMonth },
                                     set: { model.setPaidThisMonth($0, calendar: calendar) })) {
                    Text(model.kind == .ingreso ? "Ya me llegó este mes" : "Ya lo pagué este mes")
                        .appFont(.cuerpo)
                        .foregroundStyle(Palette.texto1)
                }
                .tint(Palette.brasa)
                .frame(minHeight: Size.toqueMinimo)
            }
            Text(model.planSummary(calendar: calendar)).appFont(.leyenda).foregroundStyle(Palette.texto2)
        }
    }

    private var details: some View {
        Card(padding: Spacing.s2) {
            VStack(spacing: 0) {
                Button {
                    focus = nil
                    countFocused = false
                    showsCategories = true
                } label: {
                    detailRow(title: "Categoría", value: category?.name ?? "Sin categoría")
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.linea)
                Button {
                    focus = nil
                    countFocused = false
                    showsPayWith = true
                } label: {
                    detailRow(title: model.kind == .ingreso ? "¿A dónde llega?" : "¿Con qué se paga?", value: payWithText)
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
            if budgetAlerts, let entry,
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
    return NewFixedView(spaceId: space.id, cycle: .quincenal(.standard), startSection: .dias)
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}
