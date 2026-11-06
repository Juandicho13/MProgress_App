import SwiftUI
import SwiftData

/// Límites (pantalla 27): anillo del total del mes, barras por categoría y aviso de exceso.
struct BudgetsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }) private var allEntries: [Entry]
    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil }) private var allBudgets: [Budget]
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var categories: [SpendCategory]

    @State private var editing: BudgetEdit?

    struct BudgetEdit: Identifiable {
        let id = UUID()
        var categoryId: UUID?
        var limitMinor: Int64
        var existing: Budget?
    }

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    private var budgets: [Budget] { allBudgets.filter { $0.spaceId == space?.id } }

    private var statuses: [BudgetStatus] {
        BudgetMath.statuses(budgets: budgets.map(\.record), entries: allEntries.filter { $0.spaceId == space?.id }.map(\.record),
                            now: .now, calendar: calendar)
    }

    var body: some View {
        let statuses = self.statuses
        let total = statuses.first { $0.budget.categoryId == nil }
        let byCategory = statuses.filter { $0.budget.categoryId != nil }
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Límites").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                if let total {
                    Button { edit(total) } label: { ringCard(total) }.buttonStyle(.plain)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s3) {
                            Text("Ponle un tope al mes").appFont(.titulo3).foregroundStyle(Palette.texto1)
                            Text("Te avisamos al llegar al 80 % y al pasarte.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                            Button("Límite del mes") { editing = BudgetEdit(categoryId: nil, limitMinor: 0) }.buttonStyle(.secondary)
                        }
                    }
                }
                if !byCategory.isEmpty {
                    SectionLabel(text: "Por categoría")
                    Card(padding: Spacing.s3) {
                        VStack(spacing: Spacing.s4) {
                            ForEach(byCategory, id: \.budget.id) { status in
                                Button { edit(status) } label: { bar(status) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                if let over = byCategory.first(where: { $0.level == .superado }) {
                    Text("Te pasaste en \(name(over.budget.categoryId)) por \(money(-over.remainingMinor)). Toca la categoría si quieres ajustar el límite.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto1)
                        .padding(Spacing.s4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.boton, style: .continuous).fill(Palette.brasaVelo))
                }
                Button("Nuevo límite") {
                    let used = Set(budgets.compactMap(\.categoryId))
                    editing = BudgetEdit(categoryId: categories.first { !used.contains($0.id) }?.id, limitMinor: 0)
                }
                .buttonStyle(.secondary)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { edit in
            if let space {
                BudgetFormView(spaceId: space.id, edit: edit, categories: categories, currency: currency)
            }
        }
    }

    private func ringCard(_ status: BudgetStatus) -> some View {
        Card {
            HStack(spacing: Spacing.s5) {
                ZStack {
                    Circle().stroke(Palette.superficie3, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: min(1, status.ratio))
                        .stroke(color(status.level), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int((status.ratio * 100).rounded())) %").appFont(.cifraPequena).foregroundStyle(Palette.texto1)
                        Text("usado").appFont(.leyenda).foregroundStyle(Palette.texto2)
                    }
                }
                .frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("Límite del mes").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    Text(money(status.budget.limitMinor)).appFont(.cifra).foregroundStyle(Palette.texto1)
                    Text(status.remainingMinor >= 0
                         ? "Te quedan \(money(status.remainingMinor)) · \(money(BudgetMath.dailyAllowance(remainingMinor: status.remainingMinor, now: .now, calendar: calendar))) al día"
                         : "Te pasaste por \(money(-status.remainingMinor))")
                        .appFont(.cuerpo2)
                        .foregroundStyle(status.remainingMinor >= 0 ? Palette.texto2 : Palette.peligro)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para cambiar el límite")
    }

    private func bar(_ status: BudgetStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            HStack {
                Text(name(status.budget.categoryId)).appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Spacer()
                Text(money(status.spentMinor)).appFont(.cifraPequena).foregroundStyle(color(status.level))
                Text("de \(money(status.budget.limitMinor))").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.superficie3)
                    Capsule().fill(color(status.level)).frame(width: max(6, proxy.size.width * min(1, status.ratio)))
                }
            }
            .frame(height: 6)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((status.ratio * 100).rounded())) por ciento")
    }

    private func color(_ level: BudgetStatus.Level) -> Color {
        switch level {
        case .bien: Palette.brasa
        case .cerca: Palette.oroRelleno
        case .superado: Palette.peligro
        }
    }

    private func edit(_ status: BudgetStatus) {
        editing = BudgetEdit(categoryId: status.budget.categoryId, limitMinor: status.budget.limitMinor,
                             existing: budgets.first { $0.id == status.budget.id })
    }

    private func name(_ id: UUID?) -> String {
        guard let id else { return "Total del mes" }
        return categories.first { $0.id == id }?.name ?? "Categoría"
    }

    private func money(_ minor: Int64) -> String { Money(minor: minor, currency: currency).formatted() }
}

/// Nuevo límite o cambiar uno: categoría (o total) y tope del mes.
private struct BudgetFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let spaceId: UUID
    let edit: BudgetsView.BudgetEdit
    let categories: [SpendCategory]
    let currency: Currency

    @State private var categoryId: UUID?
    @State private var limit: Int64

    init(spaceId: UUID, edit: BudgetsView.BudgetEdit, categories: [SpendCategory], currency: Currency) {
        self.spaceId = spaceId
        self.edit = edit
        self.categories = categories
        self.currency = currency
        _categoryId = State(initialValue: edit.categoryId)
        _limit = State(initialValue: edit.limitMinor)
    }

    var body: some View {
        NavigationStack {
            Form {
                if edit.existing == nil {
                    Picker("Categoría", selection: $categoryId) {
                        Text("Total del mes").tag(UUID?.none)
                        ForEach(categories) { category in Text(category.name).tag(UUID?.some(category.id)) }
                    }
                }
                Section {
                    MoneyField(title: "Tope del mes", minor: $limit, currency: currency)
                        .listRowBackground(Color.clear)
                }
                if let existing = edit.existing {
                    Button("Quitar límite", role: .destructive) {
                        try? PlanningStore(context: context).removeBudget(existing)
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle(edit.existing == nil ? "Nuevo límite" : "Cambiar límite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        _ = try? PlanningStore(context: context).setBudget(spaceId: spaceId, categoryId: categoryId, limitMinor: limit)
                        dismiss()
                    }
                    .disabled(limit <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
