import SwiftUI
import SwiftData

/// Calendario (pantalla 12): puntos por día, detalle del día y marcar pagado (F04-04 y F04-05).
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }, sort: \Entry.occurredAt, order: .reverse) private var allEntries: [Entry]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }, sort: \Recurring.nextDate) private var allRecurring: [Recurring]

    @State private var month = CycleMath.startOfMonth(.now, Calendar.current)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var selectedEntry: Entry?
    @State private var paying: Recurring?
    @State private var errorText: String?

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    private var entries: [Entry] { allEntries.filter { $0.spaceId == space?.id } }
    private var recurring: [Recurring] { allRecurring.filter { $0.spaceId == space?.id } }

    private var days: [Date: CalendarDay] {
        CalendarMath.days(month: month, entries: entries.map(\.record), recurring: recurring.map(\.record), now: .now, calendar: calendar)
    }

    var body: some View {
        let days = self.days
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Calendario")
                    .appFont(.titulo1)
                    .foregroundStyle(Palette.texto1)
                    .accessibilityAddTraits(.isHeader)
                Card {
                    VStack(spacing: Spacing.s4) {
                        monthHeader
                        grid(days)
                        legend
                    }
                }
                let pending = CalendarMath.pendingMinor(days)
                if pending > 0 {
                    Text("Faltan por pagar \(Money(minor: pending, currency: currency).formatted()) este mes")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                }
                dayDetail(days[selectedDay] ?? CalendarDay())
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry, currency: currency)
        }
        .confirmationDialog(paying.map { "¿Marcar \($0.name) como \($0.kind == .ingreso ? "recibido" : "pagado")?" } ?? "",
                            isPresented: Binding(get: { paying != nil }, set: { if !$0 { paying = nil } }), titleVisibility: .visible) {
            Button(paying?.kind == .ingreso ? "Marcar recibido" : "Marcar pagado") { markPaid() }
            Button("Cancelar", role: .cancel) { paying = nil }
        } message: {
            if let paying {
                Text("Se registra \(Money(minor: paying.amountMinor, currency: currency).formatted()) hoy y pasa al siguiente cobro.")
            }
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: Mes

    private var monthHeader: some View {
        HStack {
            CircleIconButton(systemImage: "chevron.left", label: "Mes anterior") { move(-1) }
            Spacer()
            Text(monthTitle)
                .appFont(.titulo3)
                .foregroundStyle(Palette.texto1)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CircleIconButton(systemImage: "chevron.right", label: "Mes siguiente") { move(1) }
        }
    }

    private var monthTitle: String {
        let name = DueText.monthName(month, calendar: calendar).capitalized
        return "\(name) \(calendar.component(.year, from: month))"
    }

    private func grid(_ days: [Date: CalendarDay]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: Spacing.s1) {
            ForEach(Array(CalendarMath.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { item in
                Text(item.element).appFont(.leyenda).foregroundStyle(Palette.texto2).frame(height: 24).accessibilityHidden(true)
            }
            ForEach(Array(CalendarMath.grid(month: month, calendar: calendar).enumerated()), id: \.offset) { item in
                if let date = item.element {
                    DayCell(date: date, info: days[date], selected: date == selectedDay,
                            today: calendar.isDateInToday(date), calendar: calendar) {
                        selectedDay = date
                    }
                } else {
                    Color.clear.frame(height: 48).accessibilityHidden(true)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Spacing.s4) {
            dot(Palette.brasa, "Gasto")
            dot(Palette.hielo, "Ingreso")
            dot(Palette.oroRelleno, "Por pagar")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func dot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: Spacing.s1) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).appFont(.leyenda).foregroundStyle(Palette.texto2)
        }
    }

    // MARK: Día

    private func dayDetail(_ day: CalendarDay) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(dayTitle).appFont(.titulo3).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
            if day.isEmpty {
                Card {
                    Text("Nada registrado ni por pagar este día.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                }
            } else {
                Card(padding: Spacing.s3) {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        ForEach(day.charges, id: \.self) { charge in
                            chargeRow(charge)
                        }
                        ForEach(day.entries, id: \.id) { record in
                            if let entry = entries.first(where: { $0.id == record.id }) {
                                Button { selectedEntry = entry } label: {
                                    EntryRow(entry: entry, subtitle: "Registrado", currency: currency)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chargeRow(_ charge: UpcomingCharge) -> some View {
        let item = recurring.first { $0.id == charge.recurringId }
        // Solo el cobro más cercano se puede marcar: marcarlo mueve la próxima fecha.
        let isNext = item.map { calendar.isDate($0.nextDate, inSameDayAs: charge.date) } ?? false
        ListRow(tile: entryTile(icon: item?.icon, name: charge.name, kind: charge.kind), title: charge.name,
                subtitle: "\(DueText.describe(charge.date, now: .now, calendar: calendar)) · \(item?.cycle.title ?? "")") {
            VStack(alignment: .trailing, spacing: 4) {
                Text(signedAmount(charge.amountMinor, charge.kind, currency))
                    .appFont(.cifra)
                    .foregroundStyle(charge.kind == .ingreso ? Palette.hielo : Palette.texto1)
                if isNext {
                    Button(charge.kind == .ingreso ? "Recibido" : "Pagar") { paying = item }
                        .appFont(.etiqueta)
                        .foregroundStyle(Palette.brasaTinta)
                        .frame(minHeight: 32)
                } else {
                    Badge(text: "Programado", tone: .neutral)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var dayTitle: String {
        switch Urgency.dayDifference(from: .now, to: selectedDay, calendar: calendar) {
        case 0: return "Hoy"
        case 1: return "Mañana"
        case -1: return "Ayer"
        default:
            let day = calendar.component(.day, from: selectedDay)
            return "\(day) de \(DueText.monthName(selectedDay, calendar: calendar))"
        }
    }

    private func move(_ months: Int) {
        withAnimation(.snappy) {
            month = CalendarMath.add(months: months, to: month, calendar: calendar)
            selectedDay = calendar.isDate(month, equalTo: .now, toGranularity: .month) ? calendar.startOfDay(for: .now) : month
        }
    }

    private func markPaid() {
        guard let item = paying else { return }
        let ledger = LedgerStore(context: context, calendar: calendar)
        let previousNext = item.nextDate
        let wasActive = item.active
        do {
            let entry = try ledger.markPaid(item, by: LocalIdentity.userId)
            // Con la última cuota o al pasar la fecha final el pago queda terminado.
            let message = ledger.finishedByEnd(item)
                ? RecurringEnd.finishedMessage(name: item.name, kind: item.kind)
                : "\(item.name) quedó \(item.kind == .ingreso ? "recibido" : "pagado")"
            undo.show(message) {
                try? ledger.undoPaid(item, entry: entry, previousNext: previousNext, wasActive: wasActive)
            }
            Task { await NotificationScheduler.reschedule(context: context) }
        } catch {
            errorText = error.localizedDescription
        }
        paying = nil
    }
}

/// Un día de la cuadrícula con hasta tres puntos.
private struct DayCell: View {
    let date: Date
    let info: CalendarDay?
    let selected: Bool
    let today: Bool
    let calendar: Calendar
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .appFont(.cuerpo2)
                    .foregroundStyle(selected ? Palette.sobreBrasa : (today ? Palette.brasaTinta : Palette.texto1))
                HStack(spacing: 2) {
                    if info?.hasExpense == true { Circle().fill(selected ? Palette.sobreBrasa : Palette.brasa).frame(width: 5, height: 5) }
                    if info?.hasIncome == true { Circle().fill(Palette.hielo).frame(width: 5, height: 5) }
                    if info?.hasCharge == true { Circle().fill(Palette.oroRelleno).frame(width: 5, height: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: Radius.campo, style: .continuous)
                    .fill(selected ? Palette.brasa : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.campo, style: .continuous)
                    .stroke(today && !selected ? Palette.brasa : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var label: String {
        var parts = ["\(calendar.component(.day, from: date)) de \(DueText.monthName(date, calendar: calendar))"]
        if today { parts.append("hoy") }
        if info?.hasExpense == true { parts.append("con gastos") }
        if info?.hasIncome == true { parts.append("con ingresos") }
        if info?.hasCharge == true { parts.append("con pagos por hacer") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let ledger = LedgerStore(context: container.mainContext)
    try! ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: 8_430_000, name: "Mercado")
    try! ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Gimnasio", amountMinor: 2_000_000, cycle: .semanal, nextDate: .now.addingTimeInterval(86_400))
    return CalendarView()
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}
