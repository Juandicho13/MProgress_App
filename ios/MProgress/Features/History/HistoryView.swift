import SwiftUI
import SwiftData

/// Historial (pantalla 11) por mes con total y buscador. Historial vacío (pantalla 39).
struct HistoryView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }, sort: \Entry.occurredAt, order: .reverse) private var allEntries: [Entry]
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }) private var categories: [SpendCategory]

    @State private var query = ""
    @State private var selected: Entry?
    @State private var adding = false

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    private var entries: [Entry] { allEntries.filter { $0.spaceId == space?.id } }

    private var filtered: [Entry] {
        let notes = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in entry.notes.map { (entry.id, $0) } })
        let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let ids = Set(HistoryMath.filter(entries.map(\.record), query: query, notes: notes) { names[$0] }.map(\.id))
        return entries.filter { ids.contains($0.id) }
    }

    private var months: [HistoryMonth] { HistoryMath.months(filtered.map(\.record), calendar: calendar) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Historial")
                    .appFont(.titulo1)
                    .foregroundStyle(Palette.texto1)
                    .accessibilityAddTraits(.isHeader)
                if entries.isEmpty {
                    emptyCard
                } else {
                    SearchField(text: $query, prompt: "Buscar por nombre, categoría o monto")
                    if months.isEmpty {
                        Text("Nada coincide con \u{201C}\(query)\u{201D}.")
                            .appFont(.cuerpo)
                            .foregroundStyle(Palette.texto2)
                            .padding(.top, Spacing.s4)
                    }
                    ForEach(months) { month in
                        monthSection(month)
                    }
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { entry in
            EntryDetailView(entry: entry, currency: currency)
        }
        .sheet(isPresented: $adding) {
            if let space { AddEntryView(spaceId: space.id, currency: currency) }
        }
    }

    private func monthSection(_ month: HistoryMonth) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthTitle(month.start)).appFont(.titulo2).foregroundStyle(Palette.texto1)
                Spacer()
                Text(Money(minor: month.netMinor, currency: currency).formatted(sign: true))
                    .appFont(.cifra)
                    .foregroundStyle(month.netMinor < 0 ? Palette.texto1 : Palette.hielo)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text("Entró \(Money(minor: month.incomeMinor, currency: currency).formatted()) · salió \(Money(minor: month.spentMinor, currency: currency).formatted())")
                .appFont(.cuerpo2)
                .foregroundStyle(Palette.texto2)
            Card(padding: Spacing.s3) {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    ForEach(HistoryMath.days(month.entries, calendar: calendar)) { day in
                        SectionLabel(text: dayTitle(day.day))
                            .padding(.top, Spacing.s2)
                        ForEach(day.entries, id: \.id) { record in
                            if let entry = entries.first(where: { $0.id == record.id }) {
                                Button { selected = entry } label: {
                                    EntryRow(entry: entry, subtitle: subtitle(entry), currency: currency,
                                             pending: CloudAccount.shared.showsPendingMark(entry))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        Card {
            EmptyStateView(title: "Tu historial está vacío", message: "Cada gasto o ingreso que registres queda aquí, ordenado por mes.") {
                IconTile(content: .symbol("clock.arrow.circlepath"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta, size: 64)
            } actions: {
                Button("Agregar movimiento") { adding = true }.buttonStyle(.primary)
            }
        }
    }

    private func subtitle(_ entry: Entry) -> String {
        let name = categories.first { $0.id == entry.categoryId }?.name
        return [name, entry.recurringId != nil ? "Pago fijo" : nil].compactMap { $0 }.joined(separator: " · ").ifEmpty("Sin categoría")
    }

    private func monthTitle(_ date: Date) -> String {
        let name = DueText.monthName(date, calendar: calendar).capitalized
        let year = calendar.component(.year, from: date)
        return year == calendar.component(.year, from: .now) ? name : "\(name) \(year)"
    }

    private func dayTitle(_ date: Date) -> String {
        switch Urgency.dayDifference(from: .now, to: date, calendar: calendar) {
        case 0: "Hoy"
        case -1: "Ayer"
        default: DueText.shortDate(date, calendar: calendar)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

/// Campo de búsqueda con lupa y botón para borrar.
struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.texto2).accessibilityHidden(true)
            TextField(prompt, text: $text)
                .appFont(.cuerpo)
                .foregroundStyle(Palette.texto1)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.texto2)
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, Spacing.s4)
        .frame(minHeight: Size.toqueMinimo)
        .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie1))
    }
}

#Preview("Con datos") {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let ledger = LedgerStore(context: container.mainContext)
    try! ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: 220_000_000, name: "Sueldo", occurredAt: .now.addingTimeInterval(-86_400 * 3))
    try! ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: 8_430_000, name: "Mercado")
    try! ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: 4_550_000, name: "Netflix", occurredAt: .now.addingTimeInterval(-86_400 * 40))
    return NavigationStack { HistoryView() }
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}

#Preview("Vacío") {
    let container = try! Persistence.makeContainer(inMemory: true)
    _ = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    return NavigationStack { HistoryView() }
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}
