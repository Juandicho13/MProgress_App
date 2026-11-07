import SwiftUI
import SwiftData

/// Ruta al detalle de una persona en Quién te debe (su nombre normalizado).
struct DebtPersonRoute: Hashable {
    let key: String
}

/// Deudas y abonos vivos del espacio, ya en valores del dominio.
@MainActor
struct DebtSnapshot {
    let debts: [Debt]
    let payments: [DebtPayment]

    var debtRecords: [DebtRecord] { debts.map(\.record) }
    var paymentRecords: [DebtPaymentRecord] { payments.map(\.record) }

    func payments(of debt: Debt) -> [DebtPayment] {
        payments.filter { $0.debtId == debt.id }.sorted { $0.occurredAt > $1.occurredAt }
    }

    func remaining(_ debt: Debt) -> Int64 {
        DebtMath.remaining(debt.record, payments: paymentRecords)
    }
}

/// Lee de SwiftData las deudas del espacio.
struct DebtQuery<Content: View>: View {
    let spaceId: UUID?
    @Query(filter: #Predicate<Debt> { $0.deletedAt == nil }, sort: \Debt.occurredAt, order: .reverse) private var debts: [Debt]
    @Query(filter: #Predicate<DebtPayment> { $0.deletedAt == nil }, sort: \DebtPayment.occurredAt) private var payments: [DebtPayment]

    @ViewBuilder let content: (DebtSnapshot) -> Content

    var body: some View {
        content(DebtSnapshot(debts: debts.filter { $0.spaceId == spaceId }, payments: payments.filter { $0.spaceId == spaceId }))
    }
}

/// Iniciales de una persona: "Ana María" → "AM".
enum DebtStyle {
    static func initials(_ name: String) -> String {
        let letters = DebtMath.cleanName(name).split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters
    }

    /// Azul si te debe, naranja si le debes, gris si están a mano.
    static func colors(net: Int64) -> (tint: Color, foreground: Color) {
        net > 0 ? (Palette.hieloVelo, Palette.hielo) : net < 0 ? (Palette.brasaVelo, Palette.brasaTinta) : (Palette.superficie3, Palette.texto2)
    }

    static func tile(_ name: String, net: Int64, size: CGFloat = Size.baldosa) -> IconTile {
        let colors = colors(net: net)
        return IconTile(content: .initials(initials(name)), tint: colors.tint, foreground: colors.foreground, size: size, circle: true)
    }
}

/// Quién te debe, dentro de Dinero, debajo de Bancos y billeteras.
struct DebtsSection: View {
    let wallet: WalletSnapshot
    var hideBalances = false

    @State private var adding = false
    @State private var showsSettled = false
    @State private var selected: Debt?

    var body: some View {
        DebtQuery(spaceId: wallet.space?.id) { snapshot in
            content(snapshot)
        }
        .sheet(isPresented: $adding) {
            DebtFormView(debt: nil, wallet: wallet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selected) { debt in
            DebtDetailView(debtId: debt.id, wallet: wallet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func content(_ snapshot: DebtSnapshot) -> some View {
        let people = DebtMath.people(snapshot.debtRecords, payments: snapshot.paymentRecords)
        let settled = DebtMath.settled(snapshot.debtRecords, payments: snapshot.paymentRecords)
        let totals = DebtMath.totals(snapshot.debtRecords, payments: snapshot.paymentRecords)
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack {
                SectionLabel(text: "Quién te debe")
                Spacer()
                Button("+ Agregar") { adding = true }
                    .appFont(.etiqueta)
                    .foregroundStyle(Palette.brasaTinta)
                    .frame(minHeight: Size.toqueMinimo)
            }
            if people.isEmpty && settled.isEmpty {
                Button { adding = true } label: {
                    Card {
                        ListRow(tile: IconTile(content: .symbol("person.2"), tint: Palette.hieloVelo, foreground: Palette.hielo),
                                title: "Anota lo que prestas", subtitle: "Y lo que te prestan, con abonos y aviso") {
                            Image(systemName: "plus").foregroundStyle(Palette.texto2)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Card(padding: Spacing.s3) {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        HideableText(text: DebtMath.summaryText(totals, currency: wallet.currency), hidden: hideBalances)
                            .appFont(.cuerpo2)
                            .foregroundStyle(Palette.texto2)
                            .padding(.horizontal, Spacing.s1)
                        ForEach(people) { person in
                            NavigationLink(value: DebtPersonRoute(key: person.key)) {
                                personRow(person)
                            }
                            .buttonStyle(.plain)
                        }
                        if !settled.isEmpty {
                            Divider().overlay(Palette.linea)
                            Button {
                                withAnimation(.snappy) { showsSettled.toggle() }
                            } label: {
                                HStack {
                                    Text("Saldadas (\(settled.count))").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                                    Spacer()
                                    Image(systemName: showsSettled ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Palette.texto2)
                                }
                                .frame(minHeight: Size.toqueMinimo)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Spacing.s1)
                            if showsSettled {
                                ForEach(settled) { record in
                                    if let debt = snapshot.debts.first(where: { $0.id == record.id }) {
                                        Button { selected = debt } label: { settledRow(debt) }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: DebtPersonRoute.self) { route in
            DebtPersonView(key: route.key)
        }
    }

    private func personRow(_ person: PersonDebts) -> some View {
        let color = DebtStyle.colors(net: person.netMinor).foreground
        let subtitle = person.openCount == 1 ? "1 deuda abierta" : "\(person.openCount) deudas abiertas"
        return ListRow(tile: DebtStyle.tile(person.name, net: person.netMinor), title: person.name, subtitle: subtitle) {
            VStack(alignment: .trailing, spacing: 2) {
                HideableAmount(text: Money(minor: abs(person.netMinor), currency: wallet.currency).formatted(), hidden: hideBalances)
                    .appFont(.cifraPequena)
                    .foregroundStyle(color)
                Text(DebtMath.netLabel(person)).appFont(.leyenda).foregroundStyle(color)
            }
        }
        .accessibilityHint("Toca para ver sus deudas")
    }

    private func settledRow(_ debt: Debt) -> some View {
        ListRow(tile: DebtStyle.tile(debt.person, net: 0), title: debt.person,
                subtitle: "\(debt.direction == .meDebe ? "Te debía" : "Le debías") · \(DueText.shortDate(debt.occurredAt, calendar: .current))") {
            VStack(alignment: .trailing, spacing: 2) {
                HideableAmount(text: Money(minor: debt.amountMinor, currency: wallet.currency).formatted(), hidden: hideBalances)
                    .appFont(.cifraPequena)
                    .foregroundStyle(Palette.texto2)
                Text("Saldada").appFont(.leyenda).foregroundStyle(Palette.exito)
            }
        }
    }
}

/// Texto que se esconde con el ojo de Mi dinero (para el resumen con montos).
struct HideableText: View {
    let text: String
    let hidden: Bool

    var body: some View {
        Text(hidden ? "Montos ocultos" : text)
    }
}

// MARK: Persona

/// Todas las deudas con una persona, en los dos sentidos, y el neto. Desde aquí se le recuerda.
struct DebtPersonView: View {
    let key: String

    var body: some View {
        WalletQuery { wallet in
            DebtQuery(spaceId: wallet.space?.id) { snapshot in
                DebtPersonContent(key: key, wallet: wallet, snapshot: snapshot)
            }
        }
        .background(Palette.fondo.ignoresSafeArea())
    }
}

private struct DebtPersonContent: View {
    let key: String
    let wallet: WalletSnapshot
    let snapshot: DebtSnapshot

    @Environment(\.calendar) private var calendar
    @AppStorage("dinero.ocultarSaldos") private var hideBalances = false
    @State private var adding = false
    @State private var selected: Debt?
    @State private var showsSettled = false

    private var currency: Currency { wallet.currency }
    private var debts: [Debt] { snapshot.debts.filter { DebtMath.personKey($0.person) == key } }

    var body: some View {
        let records = debts.map(\.record)
        let payments = snapshot.paymentRecords
        let open = DebtMath.open(records, payments: payments)
        let settled = DebtMath.settled(records, payments: payments)
        let totals = DebtMath.totals(records, payments: payments)
        let name = debts.first.map { DebtMath.cleanName($0.person) } ?? ""
        let net = totals.owedToMeMinor - totals.iOweMinor
        let owed = DebtMath.owedToMe(by: key, debts: records, payments: payments)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                if debts.isEmpty {
                    Text("Ya no hay deudas con esta persona.").appFont(.cuerpo).foregroundStyle(Palette.texto2)
                } else {
                    netCard(name: name, net: net, totals: totals)
                    HStack(spacing: Spacing.s3) {
                        if owed.remainingMinor > 0 {
                            ShareLink(item: DebtMath.shareText(person: name, remainingMinor: owed.remainingMinor, dueDate: owed.dueDate,
                                                               currency: currency, now: .now, calendar: calendar)) {
                                Text("Recordarle")
                            }
                            .buttonStyle(.secondary)
                        }
                        Button("+ Deuda") { adding = true }.buttonStyle(.primary)
                    }
                    if !open.isEmpty {
                        SectionLabel(text: "Pendientes")
                        Card(padding: Spacing.s3) {
                            VStack(spacing: Spacing.s2) {
                                ForEach(open) { record in
                                    if let debt = debts.first(where: { $0.id == record.id }) {
                                        Button { selected = debt } label: { row(debt, record: record) }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    if !settled.isEmpty {
                        Button {
                            withAnimation(.snappy) { showsSettled.toggle() }
                        } label: {
                            HStack {
                                SectionLabel(text: "Saldadas (\(settled.count))")
                                Image(systemName: showsSettled ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.texto2)
                            }
                            .frame(minHeight: Size.toqueMinimo)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if showsSettled {
                            Card(padding: Spacing.s3) {
                                VStack(spacing: Spacing.s2) {
                                    ForEach(settled) { record in
                                        if let debt = debts.first(where: { $0.id == record.id }) {
                                            Button { selected = debt } label: { row(debt, record: record) }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) {
            DebtFormView(debt: nil, wallet: wallet, person: name)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selected) { debt in
            DebtDetailView(debtId: debt.id, wallet: wallet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func netCard(name: String, net: Int64, totals: DebtTotals) -> some View {
        let colors = DebtStyle.colors(net: net)
        return Card {
            HStack(spacing: Spacing.s4) {
                DebtStyle.tile(name, net: net, size: 56)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(net > 0 ? "Te debe" : net < 0 ? "Le debes" : "Están a mano").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    HideableAmount(text: Money(minor: abs(net), currency: currency).formatted(), hidden: hideBalances)
                        .appFont(.cifraGrande)
                        .foregroundStyle(colors.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if totals.owedToMeMinor > 0 && totals.iOweMinor > 0 && !hideBalances {
                        Text(DebtMath.summaryText(totals, currency: currency).replacingOccurrences(of: "Te deben", with: "Te debe").replacingOccurrences(of: "Debes", with: "Le debes"))
                            .appFont(.leyenda)
                            .foregroundStyle(Palette.texto2)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ debt: Debt, record: DebtRecord) -> some View {
        let left = snapshot.remaining(debt)
        let status = DebtMath.status(record, payments: snapshot.paymentRecords, now: .now, calendar: calendar)
        var parts = [debt.direction == .meDebe ? "Te debe" : "Le debes", DueText.shortDate(debt.occurredAt, calendar: calendar)]
        if status == .saldada {
            parts.append("Saldada")
        } else if let due = debt.dueDate {
            parts.append(status == .vencida ? "venció \(DueText.shortDate(due, calendar: calendar))" : "vence \(DueText.describe(due, now: .now, calendar: calendar).lowercased())")
        }
        let color: Color = status == .saldada ? Palette.texto2 : debt.direction == .meDebe ? Palette.hielo : Palette.brasaTinta
        return ListRow(tile: IconTile(content: .symbol(debt.direction == .meDebe ? "arrow.up.right" : "arrow.down.left"),
                                      tint: debt.direction == .meDebe ? Palette.hieloVelo : Palette.brasaVelo, foreground: color),
                       title: debt.notes ?? (debt.direction == .meDebe ? "Le prestaste" : "Te prestó"), subtitle: parts.joined(separator: " · ")) {
            VStack(alignment: .trailing, spacing: 2) {
                HideableAmount(text: Money(minor: status == .saldada ? debt.amountMinor : left, currency: currency).formatted(), hidden: hideBalances)
                    .appFont(.cifraPequena)
                    .foregroundStyle(color)
                if status != .saldada && left < debt.amountMinor && !hideBalances {
                    Text("de \(Money(minor: debt.amountMinor, currency: currency).formatted())").appFont(.leyenda).foregroundStyle(Palette.texto2)
                } else if status == .vencida {
                    Text("Vencida").appFont(.leyenda).foregroundStyle(Palette.peligro)
                }
            }
        }
        .accessibilityHint("Toca para ver abonos")
    }
}

// MARK: Detalle de una deuda

/// Una deuda: lo que falta, los abonos con su historia, abonar, saldar, editar y borrar.
struct DebtDetailView: View {
    let debtId: UUID
    let wallet: WalletSnapshot

    var body: some View {
        DebtQuery(spaceId: wallet.space?.id) { snapshot in
            if let debt = snapshot.debts.first(where: { $0.id == debtId }) {
                DebtDetailContent(debt: debt, wallet: wallet, snapshot: snapshot)
            } else {
                NavigationStack {
                    Text("Esta deuda ya no existe.").appFont(.cuerpo).foregroundStyle(Palette.texto2)
                }
            }
        }
    }
}

private struct DebtDetailContent: View {
    let debt: Debt
    let wallet: WalletSnapshot
    let snapshot: DebtSnapshot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo
    @State private var paying = false
    @State private var editing = false
    @State private var confirmsDelete = false
    @State private var removingPayment: DebtPayment?
    @State private var errorText: String?

    private var currency: Currency { wallet.currency }

    var body: some View {
        let left = snapshot.remaining(debt)
        let status = DebtMath.status(debt.record, payments: snapshot.paymentRecords, now: .now, calendar: calendar)
        let history = snapshot.payments(of: debt)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            HStack {
                                Text(debt.direction == .meDebe ? "\(debt.person) te debe" : "Le debes a \(debt.person)")
                                    .appFont(.cuerpo2)
                                    .foregroundStyle(Palette.texto2)
                                Spacer()
                                Badge(text: status.title, tone: status == .saldada ? .neutral : status == .vencida ? .peligro : .hielo)
                            }
                            Text(Money(minor: left, currency: currency).formatted())
                                .appFont(.cifraGrande)
                                .foregroundStyle(status == .saldada ? Palette.texto2 : debt.direction == .meDebe ? Palette.hielo : Palette.brasaTinta)
                            Text(detailLine(left: left)).appFont(.leyenda).foregroundStyle(Palette.texto2)
                            if let note = debt.notes {
                                Text(note).appFont(.cuerpo2).foregroundStyle(Palette.texto1)
                            }
                        }
                    }
                    if status != .saldada {
                        HStack(spacing: Spacing.s3) {
                            Button("Saldar") { settle() }.buttonStyle(.secondary)
                            Button("+ Abono") { paying = true }.buttonStyle(.primary)
                        }
                        if debt.direction == .meDebe {
                            ShareLink(item: DebtMath.shareText(person: debt.person, remainingMinor: left, dueDate: debt.dueDate,
                                                               currency: currency, now: .now, calendar: calendar)) {
                                Text("Recordarle")
                            }
                            .buttonStyle(.secondary)
                        }
                    }
                    SectionLabel(text: "Abonos")
                    Card(padding: Spacing.s3) {
                        VStack(spacing: Spacing.s2) {
                            if history.isEmpty {
                                Text("Todavía no hay abonos.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                                    .frame(maxWidth: .infinity, minHeight: Size.toqueMinimo, alignment: .leading)
                            }
                            ForEach(history) { payment in
                                Button { removingPayment = payment } label: { paymentRow(payment) }.buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Borrar deuda") { confirmsDelete = true }.buttonStyle(.destructive)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .scrollIndicators(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle(debt.person)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Editar") { editing = true } }
            }
            .sheet(isPresented: $paying) {
                DebtPaymentFormView(debt: debt, remainingMinor: left, wallet: wallet)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $editing) {
                DebtFormView(debt: debt, wallet: wallet)
                    .presentationDetents([.large])
            }
            .confirmationDialog("¿Borrar esta deuda?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { delete() }
            } message: {
                Text("Se borran también sus abonos y lo que movieron en tus cuentas.")
            }
            .confirmationDialog("¿Borrar este abono?", isPresented: Binding(get: { removingPayment != nil }, set: { if !$0 { removingPayment = nil } }),
                                titleVisibility: .visible) {
                Button("Borrar abono", role: .destructive) {
                    if let payment = removingPayment { try? DebtStore(context: context).delete(payment) }
                    removingPayment = nil
                }
            }
            .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    /// "De $ 300.000 · 1 nov · vence el 15 nov · desde Ahorros".
    private func detailLine(left: Int64) -> String {
        var parts = ["De \(Money(minor: debt.amountMinor, currency: currency).formatted())", DueText.shortDate(debt.occurredAt, calendar: calendar)]
        if let due = debt.dueDate { parts.append("vence el \(DueText.shortDate(due, calendar: calendar))") }
        if let product = wallet.products.first(where: { $0.id == debt.productId }) {
            parts.append(debt.direction == .meDebe ? "salió de \(product.name)" : "llegó a \(product.name)")
        }
        return parts.joined(separator: " · ")
    }

    private func paymentRow(_ payment: DebtPayment) -> some View {
        let product = wallet.products.first { $0.id == payment.productId }
        let subtitle = [DueText.shortDate(payment.occurredAt, calendar: calendar), product?.name].compactMap { $0 }.joined(separator: " · ")
        return ListRow(tile: IconTile(content: .symbol("checkmark.circle"), tint: Palette.superficie3, foreground: Palette.exito),
                       title: "Abono", subtitle: subtitle) {
            Text(Money(minor: payment.amountMinor, currency: currency).formatted()).appFont(.cifraPequena).foregroundStyle(Palette.texto1)
        }
        .accessibilityHint("Toca para borrarlo")
    }

    private func settle() {
        do {
            try DebtStore(context: context).settle(debt, productId: debt.productId)
            undo.show("Quedó saldada")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        let store = DebtStore(context: context)
        do {
            let removed = try store.delete(debt)
            let debt = self.debt
            dismiss()
            undo.show("Borraste la deuda con \(debt.person)") {
                try? store.restore(debt, payments: removed)
            }
            Task { await NotificationScheduler.reschedule(context: context) }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: Formularios

/// Agregar o editar una deuda: quién, hacia dónde, cuánto, fechas, nota y por qué cuenta pasó la plata.
struct DebtFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Debt> { $0.deletedAt == nil }, sort: \Debt.occurredAt, order: .reverse) private var allDebts: [Debt]

    let debt: Debt?
    let wallet: WalletSnapshot

    @State private var person: String
    @State private var direction: DebtDirection
    @State private var amountText: String
    @State private var date: Date
    @State private var hasDue: Bool
    @State private var dueDate: Date
    @State private var note: String
    @State private var productId: UUID?
    @State private var errorText: String?

    init(debt: Debt?, wallet: WalletSnapshot, person: String = "") {
        self.debt = debt
        self.wallet = wallet
        let units = (debt?.amountMinor ?? 0) / wallet.currency.minorPerUnit
        _person = State(initialValue: debt?.person ?? person)
        _direction = State(initialValue: debt?.direction ?? .meDebe)
        _amountText = State(initialValue: units > 0 ? Money.groupThousands(units) : "")
        _date = State(initialValue: debt?.occurredAt ?? .now)
        _hasDue = State(initialValue: debt?.dueDate != nil)
        _dueDate = State(initialValue: debt?.dueDate ?? Calendar.current.date(byAdding: .day, value: 15, to: .now) ?? .now)
        _note = State(initialValue: debt?.notes ?? "")
        _productId = State(initialValue: debt?.productId)
    }

    private var amountMinor: Int64 { (Int64(amountText.filter(\.isNumber)) ?? 0) * wallet.currency.minorPerUnit }
    private var canSave: Bool { !DebtMath.cleanName(person).isEmpty && amountMinor > 0 }
    private var products: [Product] { wallet.products.filter { $0.kind != .debito } }
    private var suggestions: [String] {
        DebtMath.suggestions(for: person, debts: allDebts.filter { $0.spaceId == wallet.space?.id }.map(\.record))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Hacia dónde", selection: $direction) {
                        ForEach(DebtDirection.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("¿Quién?", text: $person)
                        .textInputAutocapitalization(.words)
                    if !suggestions.isEmpty {
                        FlowChips(items: suggestions) { person = $0 }
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    TextField("Monto (\(wallet.currency.symbol))", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { _, text in
                            let digits = String(text.filter(\.isNumber).prefix(12))
                            let formatted = digits.isEmpty ? "" : Money.groupThousands(Int64(digits) ?? 0)
                            if formatted != text { amountText = formatted }
                        }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date).tint(Palette.brasa)
                }
                Section {
                    Toggle("Tiene fecha límite", isOn: $hasDue).tint(Palette.brasa)
                    if hasDue {
                        DatePicker("Fecha límite", selection: $dueDate, displayedComponents: .date).tint(Palette.brasa)
                    }
                } footer: {
                    if hasDue { Text("Te avisamos el día antes.") }
                }
                Section {
                    Picker(DebtMath.productQuestion(direction, isPayment: false), selection: $productId) {
                        Text("No la anoto").tag(UUID?.none)
                        ForEach(products) { product in
                            Text(product.last4.map { "\(product.name) ·· \($0)" } ?? product.name).tag(UUID?.some(product.id))
                        }
                    }
                } footer: {
                    Text("Opcional. Si eliges una cuenta, su saldo se mueve con esta deuda. No cuenta como gasto ni ingreso del mes.")
                }
                Section {
                    TextField("Nota (opcional)", text: $note, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle(debt == nil ? "Nueva deuda" : "Editar deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(!canSave)
                }
            }
            .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func save() {
        guard let space = wallet.space, canSave else { return }
        do {
            try DebtStore(context: context).save(debt, spaceId: space.id, person: person, direction: direction, amountMinor: amountMinor,
                                                 date: date, dueDate: hasDue ? dueDate : nil, note: note, productId: productId)
            let wantsReminder = hasDue
            dismiss()
            Task {
                if wantsReminder { _ = await NotificationScheduler.requestIfNeeded() }
                await NotificationScheduler.reschedule(context: context)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Un abono: cuánto, cuándo y por qué cuenta pasó.
struct DebtPaymentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let debt: Debt
    let remainingMinor: Int64
    let wallet: WalletSnapshot

    @State private var amountText: String
    @State private var date = Date.now
    @State private var productId: UUID?
    @State private var errorText: String?

    init(debt: Debt, remainingMinor: Int64, wallet: WalletSnapshot) {
        self.debt = debt
        self.remainingMinor = remainingMinor
        self.wallet = wallet
        let units = remainingMinor / wallet.currency.minorPerUnit
        _amountText = State(initialValue: units > 0 ? Money.groupThousands(units) : "")
        _productId = State(initialValue: debt.productId)
    }

    private var amountMinor: Int64 { (Int64(amountText.filter(\.isNumber)) ?? 0) * wallet.currency.minorPerUnit }
    private var products: [Product] { wallet.products.filter { $0.kind != .debito } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Monto (\(wallet.currency.symbol))", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { _, text in
                            let digits = String(text.filter(\.isNumber).prefix(12))
                            let formatted = digits.isEmpty ? "" : Money.groupThousands(Int64(digits) ?? 0)
                            if formatted != text { amountText = formatted }
                        }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date).tint(Palette.brasa)
                } footer: {
                    Text(amountMinor > remainingMinor
                         ? "Falta \(Money(minor: remainingMinor, currency: wallet.currency).formatted()). El abono queda en ese valor."
                         : "Falta \(Money(minor: remainingMinor, currency: wallet.currency).formatted()).")
                }
                Section {
                    Picker(DebtMath.productQuestion(debt.direction, isPayment: true), selection: $productId) {
                        Text("No la anoto").tag(UUID?.none)
                        ForEach(products) { product in
                            Text(product.last4.map { "\(product.name) ·· \($0)" } ?? product.name).tag(UUID?.some(product.id))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Abono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(amountMinor <= 0)
                }
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
            try DebtStore(context: context).addPayment(to: debt, amountMinor: amountMinor, date: date, productId: productId)
            dismiss()
            Task { await NotificationScheduler.reschedule(context: context) }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
