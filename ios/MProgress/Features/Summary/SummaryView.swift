import SwiftUI
import SwiftData
import Charts

/// Resumen (pantalla 10): periodo, chips de categoría, este mes (solo datos reales), ingresos y gastos,
/// cómo va tu gasto, en qué gastas, tu mes normal, el mes que viene y los próximos 3 meses con pagos fijos (F05, PLAN_F12B Paso 4).
struct SummaryView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }, sort: \Entry.occurredAt) private var allEntries: [Entry]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }) private var allRecurring: [Recurring]
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var categories: [SpendCategory]

    @State private var period: SummaryPeriod = .meses(12)
    @State private var categoryId: UUID?
    @State private var showsCustom = false
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEnd = Date.now

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    private var records: [EntryRecord] { allEntries.filter { $0.spaceId == space?.id }.map(\.record) }
    private var recurring: [RecurringRecord] { allRecurring.filter { $0.spaceId == space?.id }.map(\.record) }

    var body: some View {
        let now = Date.now
        let records = self.records
        let interval = period.interval(now: now, calendar: calendar)
        let filterSet = categoryId.map { Set([$0]) }
        let visible = SummaryMath.filter(records, in: interval, categories: filterSet)
        let flows = SummaryMath.monthlyFlows(visible, in: interval, calendar: calendar)
        let chipIds = SummaryMath.activeCategories(records, in: interval)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                header
                if !chipIds.isEmpty { chips(chipIds) }
                if records.isEmpty {
                    emptyCard
                } else {
                    monthFactsCard(records, now: now)
                    flowsCard(flows)
                    paceCard(records, now: now)
                    categoriesCard(visible, interval: interval)
                    HStack(alignment: .top, spacing: Spacing.s3) {
                        normalCard(records, now: now)
                        nextMonthCard(now: now)
                    }
                    nextMonthsSection(now: now)
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsCustom) { customSheet }
    }

    // MARK: Encabezado y filtros

    private var header: some View {
        HStack {
            Text("Resumen")
                .appFont(.titulo1)
                .foregroundStyle(Palette.texto1)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Menu {
                ForEach(SummaryPeriod.presets, id: \.self) { option in
                    Button {
                        period = option
                    } label: {
                        if option == period { Label(option.title, systemImage: "checkmark") } else { Text(option.title) }
                    }
                }
                Divider()
                Button("Personalizado…") { showsCustom = true }
            } label: {
                HStack(spacing: Spacing.s1) {
                    Text(periodLabel).appFont(.etiqueta)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Palette.texto1)
                .padding(.horizontal, Spacing.s4)
                .frame(minHeight: 36)
                .background(Capsule().fill(Palette.superficie1))
            }
            .accessibilityLabel("Periodo, \(periodLabel)")
        }
    }

    private var periodLabel: String {
        if case .personalizado(let start, let end) = period {
            return "\(DueText.shortDate(start, calendar: calendar)) a \(DueText.shortDate(end, calendar: calendar))"
        }
        return period.title
    }

    private func chips(_ ids: [UUID]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s2) {
                Chip(title: "Todas", selected: categoryId == nil) { categoryId = nil }
                ForEach(ids, id: \.self) { id in
                    Chip(title: name(of: id), selected: categoryId == id) { categoryId = categoryId == id ? nil : id }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var customSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Desde", selection: $customStart, displayedComponents: .date)
                DatePicker("Hasta", selection: $customEnd, displayedComponents: .date)
            }
            .tint(Palette.brasa)
            .navigationTitle("Periodo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showsCustom = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        period = .personalizado(start: customStart, end: customEnd)
                        showsCustom = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Tarjetas

    private func flowsCard(_ flows: [MonthFlow]) -> some View {
        let totals = SummaryMath.totals(flows)
        let showsIncome = categoryId == nil
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text(showsIncome ? "Ingresos y gastos" : "Gastos de \(name(of: categoryId))").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                Text(showsIncome ? money(totals.net, sign: true) : money(totals.spent))
                    .appFont(.cifraGrande)
                    .foregroundStyle(Palette.texto1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: Spacing.s3) {
                    if showsIncome { legendDot(Palette.hielo, "Ingresos \(money(totals.income))") }
                    legendDot(Palette.brasa, "Gastos \(money(totals.spent))")
                }
                Chart {
                    ForEach(flows) { flow in
                        if showsIncome {
                            BarMark(x: .value("Mes", monthLabel(flow.month)), y: .value("Monto", Double(flow.incomeMinor) / 100))
                                .foregroundStyle(Palette.hielo)
                                .position(by: .value("Tipo", "Ingresos"))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .accessibilityLabel(monthLabel(flow.month))
                                .accessibilityValue("Ingresos \(money(flow.incomeMinor))")
                        }
                        BarMark(x: .value("Mes", monthLabel(flow.month)), y: .value("Monto", Double(flow.spentMinor) / 100))
                            .foregroundStyle(Palette.brasa)
                            .position(by: .value("Tipo", "Gastos"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel(monthLabel(flow.month))
                            .accessibilityValue("Gastos \(money(flow.spentMinor))")
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(AppFont.font(.leyenda)).foregroundStyle(Palette.texto2)
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private func paceCard(_ records: [EntryRecord], now: Date) -> some View {
        let filterSet = categoryId.map { Set([$0]) }
        let base = filterSet.map { set in records.filter { $0.kind == .gasto && $0.categoryId.map(set.contains) == true } } ?? records
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: CycleMath.startOfMonth(now, calendar)) ?? now
        let thisSeries = SummaryMath.cumulative(base, month: now, upTo: now, calendar: calendar)
        let lastSeries = SummaryMath.cumulative(base, month: lastMonth, calendar: calendar)
        let versus = SummaryMath.versusLastMonth(base, now: now, calendar: calendar)
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Cómo va tu gasto").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                Text(money(versus.thisMonth)).appFont(.cifraGrande).foregroundStyle(Palette.texto1)
                Text(paceText(versus.difference, monthName: DueText.monthName(lastMonth, calendar: calendar)))
                    .appFont(.cuerpo2)
                    .foregroundStyle(versus.difference > 0 ? Palette.peligro : Palette.texto2)
                Chart {
                    ForEach(lastSeries) { point in
                        LineMark(x: .value("Día", point.day), y: .value("Gastado", Double(point.cumulativeMinor) / 100),
                                 series: .value("Mes", "Pasado"))
                            .foregroundStyle(Palette.texto2.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                    ForEach(thisSeries) { point in
                        LineMark(x: .value("Día", point.day), y: .value("Gastado", Double(point.cumulativeMinor) / 100),
                                 series: .value("Mes", "Este"))
                            .foregroundStyle(Palette.brasa)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }
                .chartXScale(domain: 1...31)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: [1, 10, 20, 30]) { _ in
                        AxisValueLabel().font(AppFont.font(.leyenda)).foregroundStyle(Palette.texto2)
                    }
                }
                .frame(height: 120)
                .accessibilityElement()
                .accessibilityLabel("Gasto acumulado de este mes contra el mes pasado")
                .accessibilityValue(paceText(versus.difference, monthName: DueText.monthName(lastMonth, calendar: calendar)))
                HStack(spacing: Spacing.s3) {
                    legendDot(Palette.brasa, "Este mes")
                    legendDot(Palette.texto2, "Mes pasado")
                }
            }
        }
    }

    // MARK: Este mes y los próximos 3 meses (PLAN_F12B Paso 4, sin predicciones inventadas). No dependen del periodo ni del filtro.

    /// "Este mes": entró, gastaste, fijos que faltan y te quedan (el mismo número de Inicio).
    private func monthFactsCard(_ records: [EntryRecord], now: Date) -> some View {
        let facts = Forecast.monthFacts(entries: records, recurring: recurring, now: now, calendar: calendar)
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    Text("Este mes").appFont(.cuerpo2).foregroundStyle(Palette.texto2).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if facts.isOver { Badge(text: "Ojo", tone: .peligro) }
                }
                factRow("Entró", money(facts.enteredMinor))
                if facts.pendingIncomeMinor > 0 { factRow("Por entrar", money(facts.pendingIncomeMinor)) }
                factRow("Gastaste", money(facts.spentMinor))
                factRow("Fijos que faltan", money(facts.pendingFixedMinor))
                Divider().overlay(Palette.linea)
                HStack(alignment: .firstTextBaseline) {
                    Text("Te quedan").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    Spacer()
                    Text(money(facts.remainingMinor))
                        .appFont(.cifraGrande)
                        .foregroundStyle(facts.isOver ? Palette.peligro : Palette.texto1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if let over = Forecast.overText(remainingMinor: facts.remainingMinor, currency: currency) {
                    Text(over).appFont(.cuerpo2).foregroundStyle(Palette.peligro)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto2)
            Spacer()
            Text(value).appFont(.cifraPequena).foregroundStyle(Palette.texto1)
        }
        .frame(minHeight: 28)
    }

    /// "Los próximos 3 meses": ingresos fijos y gastos fijos, con lo que quedaría. Solo pagos fijos.
    private func nextMonthsSection(now: Date) -> some View {
        let months = Forecast.nextMonths(3, recurring: recurring, now: now, calendar: calendar)
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Los próximos 3 meses").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                Chart {
                    ForEach(months) { month in
                        BarMark(x: .value("Mes", monthLabel(month.month)), y: .value("Monto", Double(month.fixedIncomeMinor) / 100))
                            .foregroundStyle(Palette.hielo)
                            .position(by: .value("Tipo", "Ingresos"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel(monthLabel(month.month))
                            .accessibilityValue("Ingresos fijos \(money(month.fixedIncomeMinor))")
                        BarMark(x: .value("Mes", monthLabel(month.month)), y: .value("Monto", Double(month.fixedExpenseMinor) / 100))
                            .foregroundStyle(Palette.brasa)
                            .position(by: .value("Tipo", "Fijos"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel(monthLabel(month.month))
                            .accessibilityValue("Gastos fijos \(money(month.fixedExpenseMinor))")
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(AppFont.font(.leyenda)).foregroundStyle(Palette.texto2)
                    }
                }
                .frame(height: 140)
                HStack(spacing: Spacing.s3) {
                    legendDot(Palette.hielo, "Ingresos fijos")
                    legendDot(Palette.brasa, "Gastos fijos")
                }
                ForEach(months) { month in
                    HStack {
                        Text(DueText.monthName(month.month, calendar: calendar).capitalizedFirst).appFont(.cuerpo).foregroundStyle(Palette.texto1)
                        Spacer()
                        Text(Forecast.netText(month, currency: currency))
                            .appFont(.cifraPequena)
                            .foregroundStyle(month.netMinor < 0 ? Palette.peligro : Palette.texto1)
                    }
                    .frame(minHeight: 32)
                    .accessibilityElement(children: .combine)
                }
                Text(Forecast.nextMonthsNote)
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }

    private func paceText(_ difference: Int64, monthName: String) -> String {
        if difference == 0 { return "Igual que a esta altura de \(monthName)" }
        let amount = money(abs(difference))
        return difference > 0 ? "\(amount) más que a esta altura de \(monthName)" : "\(amount) menos que a esta altura de \(monthName)"
    }

    private func categoriesCard(_ visible: [EntryRecord], interval: DateInterval) -> some View {
        let rows = BalanceCalculator.spendingByCategory(entries: visible, in: interval)
        let total = rows.reduce(Int64(0)) { $0 + $1.totalMinor }
        let top = rows.first?.totalMinor ?? 1
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("En qué gastas").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                Text(money(total)).appFont(.cifraGrande).foregroundStyle(Palette.texto1)
                if rows.isEmpty {
                    Text("Sin gastos en este periodo.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                }
                ForEach(Array(rows.prefix(8).enumerated()), id: \.offset) { item in
                    let row = item.element
                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        HStack {
                            Text(row.categoryId.map(name(of:)) ?? "Sin categoría").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                            Spacer()
                            Text(money(row.totalMinor)).appFont(.cifraPequena).foregroundStyle(Palette.texto1)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.superficie3)
                                Capsule().fill(Palette.brasa)
                                    .frame(width: max(6, proxy.size.width * Double(row.totalMinor) / Double(max(1, top))))
                            }
                        }
                        .frame(height: 6)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func normalCard(_ records: [EntryRecord], now: Date) -> some View {
        let normal = BalanceCalculator.normalMonth(entries: records, now: now, calendar: calendar)
        let above = SummaryMath.monthsAboveNormal(records, now: now, calendar: calendar)
        return smallCard(title: "Tu mes normal",
                         value: normal.map { money($0) } ?? "Sin datos",
                         caption: above.map { "\($0.above) de \($0.counted) meses arriba" } ?? "Necesita un mes completo")
    }

    private func nextMonthCard(now: Date) -> some View {
        let plan = SummaryMath.nextMonth(recurring, now: now, calendar: calendar)
        return smallCard(title: "El mes que viene",
                         value: money(plan.expenseMinor),
                         caption: plan.count == 0 ? "Nada programado" : "ya previsto en \(plan.count) \(plan.count == 1 ? "pago" : "pagos")")
    }

    private func smallCard(title: String, value: String, caption: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(title).appFont(.leyenda).foregroundStyle(Palette.texto2)
                Text(value).appFont(.cifra).foregroundStyle(Palette.texto1).lineLimit(1).minimumScaleFactor(0.6)
                Text(caption).appFont(.leyenda).foregroundStyle(Palette.texto2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Ingresos y gastos").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                HStack(alignment: .bottom, spacing: Spacing.s3) {
                    ForEach([0.5, 0.8, 0.6, 0.9, 0.7, 1.0], id: \.self) { height in
                        RoundedRectangle(cornerRadius: 4).fill(Palette.superficie3).frame(height: 110 * height)
                    }
                }
                .frame(height: 110, alignment: .bottom)
                .accessibilityHidden(true)
                Text("Agrega movimientos para ver tu resumen").appFont(.cuerpo).foregroundStyle(Palette.texto2)
            }
        }
    }

    // MARK: Ayudas

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Spacing.s1) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).appFont(.leyenda).foregroundStyle(color == Palette.texto2 ? Palette.texto2 : color)
        }
    }

    private func money(_ minor: Int64, sign: Bool = false) -> String {
        Money(minor: minor, currency: currency).formatted(sign: sign)
    }

    private func monthLabel(_ date: Date) -> String {
        DueText.months[max(0, min(11, calendar.component(.month, from: date) - 1))]
    }

    private func name(of id: UUID?) -> String {
        categories.first { $0.id == id }?.name ?? "Sin categoría"
    }
}

#Preview("Con datos") {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let ledger = LedgerStore(context: container.mainContext)
    let cats = try! ledger.categories(spaceId: space.id)
    for month in 0..<6 {
        let date = Calendar.current.date(byAdding: .month, value: -month, to: .now)!
        try! ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: 220_000_000, name: "Sueldo", occurredAt: date)
        try! ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: Int64(20_000_000 + month * 3_000_000), name: "Mercado", occurredAt: date, categoryId: cats.first?.id)
        try! ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: 11_990_000, name: "Gimnasio", occurredAt: date, categoryId: cats.last?.id)
    }
    return SummaryView().modelContainer(container).preferredColorScheme(.dark)
}

#Preview("Vacío") {
    let container = try! Persistence.makeContainer(inMemory: true)
    _ = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    return SummaryView().modelContainer(container).preferredColorScheme(.dark)
}
