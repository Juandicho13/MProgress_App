import SwiftUI
import SwiftData

/// Inicio (pantalla 1), Inicio vacío (38).
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }, sort: \Entry.occurredAt, order: .reverse) private var allEntries: [Entry]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }, sort: \Recurring.nextDate) private var allRecurring: [Recurring]

    @State private var adding: AddRequest?
    @State private var showsMore = false
    @State private var selected: Entry?
    @State private var payingCard: CardDue?
    @State private var chargeActions: Recurring?
    @State private var reminderFor: Recurring?
    @State private var route: HomeRoute?
    @State private var scanning = false
    @State private var receipt: ReceiptDraft?

    struct ReceiptDraft: Identifiable {
        let id = UUID()
        var merchant: String
        var amountMinor: Int64
    }
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }) private var allProducts: [Product]
    @Query(filter: #Predicate<Transfer> { $0.deletedAt == nil }) private var allTransfers: [Transfer]
    @State private var errorText: String?

    struct AddRequest: Identifiable {
        let id = UUID()
        var kind: EntryKind
        var cycle: AddEntryModel.CycleChoice
    }

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var entries: [Entry] { allEntries.filter { $0.spaceId == space?.id } }
    private var recurring: [Recurring] { allRecurring.filter { $0.spaceId == space?.id && $0.active } }
    private var currency: Currency { space?.currency ?? .cop }
    private var now: Date { .now }

    private var summary: MonthSummary {
        BalanceCalculator.monthSummary(entries: entries.map(\.record), recurring: recurring.map(\.record), now: now, calendar: calendar)
    }

    private var upcoming: [UpcomingCharge] {
        BalanceCalculator.upcoming(recurring: recurring.map(\.record), now: now, calendar: calendar, kind: nil, limit: 6)
    }

    private var cardDues: [CardDue] {
        let id = space?.id
        return WalletMath.cardDues(products: allProducts.filter { $0.spaceId == id }.map(\.record),
                                   entries: entries.map(\.record),
                                   transfers: allTransfers.filter { $0.spaceId == id }.map(\.record),
                                   now: now, calendar: calendar)
    }

    private var isEmpty: Bool { entries.isEmpty && recurring.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                header
                balance
                quickActions
                if isEmpty {
                    emptyCard
                } else {
                    if !upcoming.isEmpty {
                        upcomingCard
                    } else if !recurring.isEmpty {
                        fixedShortcut
                    }
                    if !cardDues.isEmpty { cardDuesCard }
                    if !entries.isEmpty { recentCard }
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $adding) { request in
            if let space {
                AddEntryView(spaceId: space.id, kind: request.kind, cycle: request.cycle, currency: currency)
            }
        }
        .sheet(item: $payingCard) { due in
            WalletQuery { wallet in
                TransferView(wallet: wallet, to: due.productId)
            }
        }
        .sheet(item: $selected) { entry in
            EntryDetailView(entry: entry, currency: currency)
        }
        .sheet(isPresented: $showsMore) {
            MoreSheet { kind, cycle in
                showsMore = false
                adding = AddRequest(kind: kind, cycle: cycle)
            } onOpen: { target in
                showsMore = false
                if target == .recibo {
                    scanning = true
                } else if target == .rapido {
                    // Espera a que se cierre Más antes de abrir el registro rápido.
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        QuickAddRouter.shared.pending = true
                    }
                } else {
                    route = target
                }
            }
            .presentationDetents([.height(650), .large])
            .presentationCornerRadius(Radius.hoja)
        }
        .navigationDestination(item: $route) { target in
            switch target {
            case .avisos: AlertsView()
            case .limites: BudgetsView()
            case .ahorro: SavingsView()
            case .historial: HistoryView()
            case .automatico: AutoCaptureView()
            case .fijos: FixedView()
            case .recibo, .rapido: EmptyView()
            }
        }
        .sheet(isPresented: $scanning) {
            ReceiptScanView { merchant, amount in
                receipt = ReceiptDraft(merchant: merchant ?? "", amountMinor: amount ?? 0)
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(Radius.hoja)
        }
        .sheet(item: $receipt) { draft in
            if let space {
                AddEntryView(spaceId: space.id, prefillName: draft.merchant, amountMinor: draft.amountMinor, source: .recibo, currency: currency)
            }
        }
        .sheet(item: $reminderFor) { item in
            ReminderEditView(recurring: item, currency: currency)
        }
        .confirmationDialog(chargeActions?.name ?? "", isPresented: Binding(get: { chargeActions != nil }, set: { if !$0 { chargeActions = nil } }), titleVisibility: .visible) {
            if let item = chargeActions {
                Button(item.kind == .ingreso ? "Marcar recibido" : "Marcar pagado") { markPaid(item) }
                Button("Configurar aviso") { reminderFor = item }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: Partes

    private var header: some View {
        HStack {
            Menu {
                Button {} label: { Label(space?.name ?? "Personal", systemImage: "checkmark") }
                Divider()
                Button("Agregar cuenta (pronto)") {}.disabled(true)
            } label: {
                HStack(spacing: Spacing.s2) {
                    Avatar(name: space?.name ?? "Personal", size: 32)
                    Text(space?.name ?? "Personal").appFont(.titulo3).foregroundStyle(Palette.texto1)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.texto2)
                }
                .padding(.vertical, 6)
                .padding(.leading, 6)
                .padding(.trailing, Spacing.s4)
                .background(Capsule().fill(Palette.superficie1))
            }
            .accessibilityLabel("Cuenta \(space?.name ?? "Personal")")
            Spacer()
            CircleIconButton(systemImage: "bell", label: "Avisos") { route = .avisos }
        }
    }

    private var balance: some View {
        let remaining = Money(minor: summary.remainingMinor, currency: currency)
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Te quedan en \(DueText.monthName(now, calendar: calendar))")
                .appFont(.cuerpo2)
                .foregroundStyle(Palette.texto2)
            Text(remaining.formatted())
                .appFont(.cifraHeroe)
                .foregroundStyle(isEmpty ? Palette.texto2 : (remaining.isNegative ? Palette.peligro : Palette.texto1))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            if isEmpty {
                Button("Agrega tu ingreso para calcularlo") { adding = AddRequest(kind: .ingreso, cycle: .mensual) }
                    .appFont(.titulo3)
                    .foregroundStyle(Palette.brasaTinta)
                    .frame(minHeight: Size.toqueMinimo, alignment: .leading)
            } else {
                MonthBar(ratio: summary.spentRatio)
                Text("Gastado \(Money(minor: summary.spentMinor, currency: currency).formatted()) de \(Money(minor: summary.expectedIncomeMinor, currency: currency).formatted()) · faltan \(summary.daysLeft) días")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var quickActions: some View {
        HStack(spacing: Spacing.s3) {
            QuickAction(title: "Gasto", symbol: "plus", primary: true) { adding = AddRequest(kind: .gasto, cycle: .puntual) }
            QuickAction(title: "Ingreso", symbol: "arrow.down") { adding = AddRequest(kind: .ingreso, cycle: .puntual) }
            QuickAction(title: "Fijo", symbol: "repeat") { adding = AddRequest(kind: .gasto, cycle: .mensual) }
            QuickAction(title: "Más", symbol: "ellipsis") { showsMore = true }
        }
    }

    private var upcomingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    Text("Próximos cargos").appFont(.titulo3).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("Pagos fijos") { route = .fijos }
                        .appFont(.etiqueta)
                        .foregroundStyle(Palette.brasaTinta)
                        .frame(minHeight: Size.toqueMinimo)
                }
                ForEach(upcoming, id: \.recurringId) { charge in
                    let item = recurring.first { $0.id == charge.recurringId }
                    Button {
                        chargeActions = item
                    } label: {
                        ListRow(tile: IconTile(content: item?.icon.map { IconTile.Content.symbol($0) } ?? .initials(charge.name),
                                               tint: charge.kind == .ingreso ? Palette.hieloVelo : Palette.superficie3,
                                               foreground: charge.kind == .ingreso ? Palette.hielo : Palette.texto1),
                                title: charge.name,
                                subtitle: "\(DueText.describe(charge.date, now: now, calendar: calendar)) · \(item?.cycle.title ?? "")") {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(signed(charge.amountMinor, charge.kind))
                                    .appFont(.cifra)
                                    .foregroundStyle(charge.kind == .ingreso ? Palette.hielo : Palette.texto1)
                                urgencyBadge(charge)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Toca para marcarlo como pagado o configurar su aviso")
                }
            }
        }
    }

    /// Cuando no hay cobros cerca, igual se llega a la zona de pagos fijos.
    private var fixedShortcut: some View {
        Button { route = .fijos } label: {
            Card {
                ListRow(tile: IconTile(content: .symbol("repeat"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta),
                        title: "Pagos fijos", subtitle: "\(recurring.count) \(recurring.count == 1 ? "pago" : "pagos") · nada por cobrar pronto") {
                    Image(systemName: "chevron.right").foregroundStyle(Palette.texto2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Tarjetas de crédito con pago cerca (F06-07). Tocar abre Pagar tarjeta.
    private var cardDuesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Pago de tarjetas").appFont(.titulo3).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                ForEach(cardDues, id: \.productId) { due in
                    Button { payingCard = due } label: {
                        ListRow(tile: IconTile(content: .symbol("creditcard"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta),
                                title: due.name,
                                subtitle: "Pago \(DueText.describe(due.date, now: now, calendar: calendar).lowercased())") {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(Money(minor: due.debtMinor, currency: currency).formatted()).appFont(.cifra).foregroundStyle(Palette.texto1)
                                switch due.urgency {
                                case .hoy: Badge(text: "Hoy", tone: .peligro)
                                case .pronto: Badge(text: "Pronto", tone: .oro)
                                case .proximas: EmptyView()
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Toca para pagar la tarjeta")
                }
            }
        }
    }

    @ViewBuilder
    private func urgencyBadge(_ charge: UpcomingCharge) -> some View {
        switch charge.urgency {
        case .hoy: Badge(text: "Hoy", tone: .peligro)
        case .pronto: Badge(text: "Pronto", tone: .oro)
        case .proximas: EmptyView()
        }
    }

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    Text("Movimientos").appFont(.titulo3).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    NavigationLink("Ver todo") { HistoryView() }
                        .appFont(.etiqueta)
                        .foregroundStyle(Palette.brasaTinta)
                        .frame(minHeight: Size.toqueMinimo)
                }
                ForEach(entries.prefix(5)) { entry in
                    Button { selected = entry } label: {
                        EntryRow(entry: entry, subtitle: DueText.describe(entry.occurredAt, now: now, calendar: calendar), currency: currency)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyCard: some View {
        Card {
            EmptyStateView(title: "Aún no hay movimientos", message: "Agrega tu primer gasto o tus pagos fijos y aquí verás lo que viene.") {
                EmptyArt()
            } actions: {
                HStack(spacing: Spacing.s2) {
                    Button("Agregar gasto") { adding = AddRequest(kind: .gasto, cycle: .puntual) }.buttonStyle(.primary)
                    Button("Pagos fijos") { adding = AddRequest(kind: .gasto, cycle: .mensual) }.buttonStyle(.secondary)
                }
            }
        }
    }

    private func signed(_ minor: Int64, _ kind: EntryKind) -> String {
        Money(minor: kind == .ingreso ? minor : -minor, currency: currency).formatted(sign: true)
    }

    private func markPaid(_ item: Recurring) {
        let ledger = LedgerStore(context: context, calendar: calendar)
        let previousNext = item.nextDate
        let wasActive = item.active
        do {
            let entry = try ledger.markPaid(item, by: LocalIdentity.userId)
            undo.show("\(item.name) quedó \(item.kind == .ingreso ? "recibido" : "pagado")") {
                try? ledger.undoPaid(item, entry: entry, previousNext: previousNext, wasActive: wasActive)
            }
            Task { await NotificationScheduler.reschedule(context: context) }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: Piezas

private struct MonthBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.superficie3)
                Capsule().fill(ratio >= 1 ? Palette.peligro : Palette.brasa).frame(width: max(6, proxy.size.width * ratio))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Gastado del mes")
        .accessibilityValue("\(Int(ratio * 100)) %")
    }
}

private struct QuickAction: View {
    let title: String
    let symbol: String
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s1) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                Text(title).appFont(.etiqueta)
            }
            .foregroundStyle(primary ? Palette.sobreBrasa : Palette.texto1)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: Radius.boton, style: .continuous).fill(primary ? Palette.brasa : Palette.superficie1))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.superficie3)
                .frame(width: 88, height: 58).offset(y: 18)
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.brasaVelo)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.brasa, lineWidth: 2))
                .overlay(alignment: .top) { Capsule().fill(Palette.brasa).frame(width: 40, height: 6).padding(.top, 18) }
                .frame(width: 88, height: 58).offset(x: 30)
        }
        .frame(width: 120, height: 80)
        .accessibilityHidden(true)
    }
}

/// Menú Más (pantalla 20): solo las acciones de fases ya hechas.
enum HomeRoute: Hashable, Identifiable {
    case avisos, limites, ahorro, historial, automatico, recibo, fijos, rapido
    var id: Self { self }
}

private struct MoreSheet: View {
    let onAdd: (EntryKind, AddEntryModel.CycleChoice) -> Void
    let onOpen: (HomeRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("Más acciones").appFont(.titulo2).foregroundStyle(Palette.texto1).padding(.top, Spacing.s6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s3), count: 3), spacing: Spacing.s3) {
                tile("Ingreso extra", "arrow.down.circle") { onAdd(.ingreso, .puntual) }
                tile("Sueldo o fijo", "repeat") { onAdd(.ingreso, .mensual) }
                tile("Pago anual", "calendar") { onAdd(.gasto, .anual) }
                tile("Pagos fijos", "repeat") { onOpen(.fijos) }
                tile("Registro rápido", "hand.tap") { onOpen(.rapido) }
                tile("Límites", "gauge.with.dots.needle.33percent") { onOpen(.limites) }
                tile("Ahorro", "target") { onOpen(.ahorro) }
                tile("Historial", "clock.arrow.circlepath") { onOpen(.historial) }
                tile("Escanear recibo", "doc.text.viewfinder") { onOpen(.recibo) }
                tile("Registro automático", "wand.and.stars") { onOpen(.automatico) }
            }
            Text("Dividir gastos llega con los espacios en pareja.")
                .appFont(.cuerpo2)
                .foregroundStyle(Palette.texto2)
            Spacer()
        }
        .padding(.horizontal, Spacing.margen)
        .background(Palette.superficie2.ignoresSafeArea())
    }

    private func tile(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.s2) {
                Image(systemName: symbol).font(.system(size: 24, weight: .medium))
                Text(title).appFont(.leyenda).multilineTextAlignment(.center)
            }
            .foregroundStyle(Palette.texto1)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(RoundedRectangle(cornerRadius: Radius.boton, style: .continuous).fill(Palette.superficie3))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Con datos") {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let ledger = LedgerStore(context: container.mainContext)
    try! ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: 220_000_000, name: "Sueldo", occurredAt: .now.addingTimeInterval(-86_400 * 3))
    try! ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: 8_430_000, name: "Mercado")
    try! ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Gimnasio", amountMinor: 11_990_000, cycle: .mensual, nextDate: .now.addingTimeInterval(86_400))
    return NavigationStack { HomeView() }.modelContainer(container).environment(UndoCenter()).preferredColorScheme(.dark)
}

#Preview("Vacío") {
    let container = try! Persistence.makeContainer(inMemory: true)
    _ = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    return NavigationStack { HomeView() }.modelContainer(container).environment(UndoCenter()).preferredColorScheme(.dark)
}

extension CardDue: Identifiable {
    var id: UUID { productId }
}
