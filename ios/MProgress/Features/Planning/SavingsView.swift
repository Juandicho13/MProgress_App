import SwiftUI
import SwiftData

/// Ahorro (pantalla 26): total ahorrado, metas con barra y aportar.
/// Una meta ligada a una cajita toma su saldo; sin cajita, suma los aportes.
struct SavingsView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<SavingsGoal> { $0.deletedAt == nil }, sort: \SavingsGoal.createdAt) private var allGoals: [SavingsGoal]
    @Query(filter: #Predicate<GoalContribution> { $0.deletedAt == nil }) private var allContributions: [GoalContribution]

    @State private var editingGoal: SavingsGoal?
    @State private var creating = false
    @State private var contributing = false

    var body: some View {
        WalletQuery { wallet in
            content(wallet)
        }
    }

    private func content(_ wallet: WalletSnapshot) -> some View {
        let id = wallet.space?.id
        let goals = allGoals.filter { $0.spaceId == id }
        let contributions = allContributions.filter { $0.spaceId == id }
        let progress = goals.map { goal in
            SavingsMath.progress(goal: goal.record,
                                 contributions: contributions.map { (goalId: $0.goalId, amountMinor: $0.amountMinor) },
                                 productBalance: goal.productId.flatMap { pid in wallet.products.first { $0.id == pid } }.map(wallet.balance),
                                 now: .now, calendar: calendar)
        }
        let total = progress.reduce(Int64(0)) { $0 + $1.savedMinor }
        let month = SavingsMath.savedThisMonth(contributions.map { (occurredAt: $0.occurredAt, amountMinor: $0.amountMinor) }, now: .now, calendar: calendar)
        let currency = wallet.currency

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack {
                    Text("Ahorro").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    CircleIconButton(systemImage: "plus", label: "Nueva meta", filled: true) { creating = true }
                }
                Card {
                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        Text("Ahorrado en total").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                        Text(Money(minor: total, currency: currency).formatted()).appFont(.cifraGrande).foregroundStyle(Palette.texto1)
                        if month != 0 {
                            Text("\(Money(minor: month, currency: currency).formatted(sign: true)) este mes").appFont(.leyenda).foregroundStyle(Palette.hielo)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                if goals.isEmpty {
                    Card {
                        EmptyStateView(title: "Tu primera meta", message: "Un viaje, un fondo de emergencia o lo que quieras. Puedes ligarla a una cajita para que se llene sola.") {
                            IconTile(content: .symbol("target"), tint: Palette.hieloVelo, foreground: Palette.hielo, size: 64)
                        } actions: {
                            Button("Crear meta") { creating = true }.buttonStyle(.primary)
                        }
                    }
                } else {
                    ForEach(progress, id: \.goal.id) { item in
                        Button { editingGoal = goals.first { $0.id == item.goal.id } } label: {
                            goalCard(item, wallet: wallet)
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Aportar a una meta") { contributing = true }
                        .buttonStyle(.secondary)
                        .disabled(!goals.contains { $0.productId == nil })
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
        .sheet(isPresented: $creating) {
            if let space = wallet.space { GoalFormView(spaceId: space.id, goal: nil, wallet: wallet) }
        }
        .sheet(item: $editingGoal) { goal in
            GoalFormView(spaceId: goal.spaceId, goal: goal, wallet: wallet)
        }
        .sheet(isPresented: $contributing) {
            ContributeView(goals: goals.filter { $0.productId == nil }, currency: currency)
        }
    }

    private func goalCard(_ item: GoalProgress, wallet: WalletSnapshot) -> some View {
        let currency = wallet.currency
        let product = item.goal.productId.flatMap { pid in wallet.products.first { $0.id == pid } }
        var lines: [String] = ["\(Money(minor: item.savedMinor, currency: currency).formatted()) de \(Money(minor: item.goal.targetMinor, currency: currency).formatted())"]
        if let product { lines.append("ligada a \(product.name)") }
        if let needed = item.monthlyNeededMinor { lines.append("aporta \(Money(minor: needed, currency: currency).formatted()) al mes") }
        var subtitle = "Personal"
        if let date = item.goal.targetDate {
            subtitle += " · meta \(DueText.monthName(date, calendar: calendar).prefix(3)) \(calendar.component(.year, from: date))"
        }
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                ListRow(tile: IconTile(content: .initials(item.goal.name), tint: Palette.hieloVelo, foreground: Palette.hielo),
                        title: item.goal.name, subtitle: subtitle) {
                    Text("\(Int((item.ratio * 100).rounded())) %").appFont(.cifraPequena).foregroundStyle(Palette.texto1)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.superficie3)
                        Capsule().fill(item.ratio >= 1 ? Palette.exito : Palette.hielo).frame(width: max(6, proxy.size.width * item.ratio))
                    }
                }
                .frame(height: 8)
                Text(lines.joined(separator: " · ")).appFont(.leyenda).foregroundStyle(Palette.texto2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para editar la meta")
    }
}

/// Crear o editar una meta.
private struct GoalFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let spaceId: UUID
    let goal: SavingsGoal?
    let wallet: WalletSnapshot

    @State private var name: String
    @State private var target: Int64
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var productId: UUID?
    @State private var confirmsDelete = false

    init(spaceId: UUID, goal: SavingsGoal?, wallet: WalletSnapshot) {
        self.spaceId = spaceId
        self.goal = goal
        self.wallet = wallet
        _name = State(initialValue: goal?.name ?? "")
        _target = State(initialValue: goal?.targetAmountMinor ?? 0)
        _hasDate = State(initialValue: goal?.targetDate != nil)
        _date = State(initialValue: goal?.targetDate ?? Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now)
        _productId = State(initialValue: goal?.productId)
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && target > 0 }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre: viaje, emergencias…", text: $name)
                Section {
                    MoneyField(title: "¿Cuánto quieres juntar?", minor: $target, currency: wallet.currency)
                        .listRowBackground(Color.clear)
                }
                Section {
                    Toggle("Con fecha", isOn: $hasDate).tint(Palette.brasa)
                    if hasDate {
                        DatePicker("Para", selection: $date, in: Date.now..., displayedComponents: .date).tint(Palette.brasa)
                    }
                }
                Section {
                    Picker("Ligada a una cajita", selection: $productId) {
                        Text("No, sumo aportes").tag(UUID?.none)
                        ForEach(wallet.products.filter { $0.kind.earnsYield || $0.kind == .cuenta }) { product in
                            Text(product.name).tag(UUID?.some(product.id))
                        }
                    }
                } footer: {
                    Text("Si la ligas, lo ahorrado es el saldo de esa cajita.")
                }
                if goal != nil {
                    Button("Borrar meta", role: .destructive) { confirmsDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle(goal == nil ? "Nueva meta" : "Editar meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.disabled(!canSave) }
            }
            .confirmationDialog("¿Borrar \(name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let goal { try? PlanningStore(context: context).deleteGoal(goal) }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let store = PlanningStore(context: context)
        if let goal {
            try? store.updateGoal(goal, name: name, targetMinor: target, targetDate: hasDate ? date : nil, productId: productId)
        } else {
            _ = try? store.addGoal(spaceId: spaceId, name: name, targetMinor: target, targetDate: hasDate ? date : nil, productId: productId)
        }
        dismiss()
    }
}

/// Aportar a una meta con el teclado propio.
private struct ContributeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goals: [SavingsGoal]
    let currency: Currency
    @State private var goalId: UUID?
    @State private var amount: AmountInput
    @State private var withdraw = false

    init(goals: [SavingsGoal], currency: Currency) {
        self.goals = goals
        self.currency = currency
        _goalId = State(initialValue: goals.first?.id)
        _amount = State(initialValue: AmountInput(currency: currency))
    }

    var body: some View {
        VStack(spacing: Spacing.s4) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
                Spacer()
                Text("Aportar").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Spacer()
                CircleIconButton(systemImage: "checkmark", label: "Guardar", filled: true) { save() }
                    .disabled(amount.money.minor <= 0 || goalId == nil)
                    .opacity(amount.money.minor > 0 ? 1 : 0.4)
            }
            .padding(.top, Spacing.s4)
            SegmentedPill(options: [(value: false, title: "Aportar"), (value: true, title: "Retirar")], selection: $withdraw)
            Picker("Meta", selection: $goalId) {
                ForEach(goals) { goal in Text(goal.name).tag(UUID?.some(goal.id)) }
            }
            .pickerStyle(.menu)
            .tint(Palette.texto1)
            AmountDisplay(input: amount, active: true)
            Spacer()
            NumericKeypad(input: $amount)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s2)
        .background(Palette.superficie2.ignoresSafeArea())
    }

    private func save() {
        guard let goal = goals.first(where: { $0.id == goalId }) else { return }
        let value = amount.money.minor
        _ = try? PlanningStore(context: context).contribute(to: goal, amountMinor: withdraw ? -value : value, userId: LocalIdentity.userId)
        dismiss()
    }
}
