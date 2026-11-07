import SwiftUI
import SwiftData

/// Zona de pagos fijos: todo lo que se cobra o llega solo, con su total al mes.
/// Los que quedaron "Más tarde" en el onboarding salen arriba para ponerles fecha.
struct FixedView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }, sort: \Recurring.nextDate) private var allRecurring: [Recurring]
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }) private var products: [Product]

    @State private var editing: Recurring?
    @State private var adding: EntryKind?

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    private var items: [Recurring] { allRecurring.filter { $0.spaceId == space?.id && $0.cycle != .puntual } }

    var body: some View {
        let all = self.items
        // Los que terminaron sus cuotas o pasaron su fecha final van aparte y no suman.
        let finished = all.filter { isFinishedByEnd($0) }
        let items = all.filter { !isFinishedByEnd($0) }
        let totals = FixedMath.totals(items.map { (kind: $0.kind, amountMinor: $0.amountMinor, cycle: $0.cycle, active: $0.active, dateUnset: $0.dateUnset) })
        let withoutDate = items.filter { $0.dateUnset && $0.active }
        let expenses = items.filter { $0.kind == .gasto && !($0.dateUnset && $0.active) }
        let incomes = items.filter { $0.kind == .ingreso && !($0.dateUnset && $0.active) }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack {
                    Text("Pagos fijos").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Menu {
                        Button("Gasto fijo", systemImage: "arrow.up.right") { adding = .gasto }
                        Button("Ingreso fijo", systemImage: "arrow.down.left") { adding = .ingreso }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.sobreBrasa)
                            .frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
                            .background(Circle().fill(Palette.brasa))
                    }
                    .accessibilityLabel("Agregar pago fijo")
                }

                Card {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("Al mes se te van").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                        Text(money(totals.expenseMinor)).appFont(.cifraGrande).foregroundStyle(Palette.texto1)
                        HStack(spacing: Spacing.s3) {
                            if totals.incomeMinor > 0 {
                                Text("Te llegan \(money(totals.incomeMinor))").appFont(.leyenda).foregroundStyle(Palette.hielo)
                            }
                            if totals.paused > 0 {
                                Text("\(totals.paused) pausado\(totals.paused == 1 ? "" : "s")").appFont(.leyenda).foregroundStyle(Palette.texto2)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)

                if all.isEmpty {
                    Card {
                        EmptyStateView(title: "Sin pagos fijos", message: "Arriendo, servicios, suscripciones o tu sueldo. Los agregas una vez y la app te avisa cada mes.") {
                            IconTile(content: .symbol("repeat"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta, size: 64)
                        } actions: {
                            Button("Agregar pago fijo") { adding = .gasto }.buttonStyle(.primary)
                        }
                    }
                }
                if !withoutDate.isEmpty {
                    SectionLabel(text: "Falta la fecha")
                    list(withoutDate, highlight: true)
                }
                if !expenses.isEmpty {
                    SectionLabel(text: "Gastos")
                    list(expenses)
                }
                if !incomes.isEmpty {
                    SectionLabel(text: "Ingresos")
                    list(incomes)
                }
                if !finished.isEmpty {
                    SectionLabel(text: "Terminados")
                    list(finished)
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
        .sheet(item: $editing) { item in
            RecurringEditView(item: item, currency: currency)
        }
        .sheet(item: $adding) { kind in
            if let space { NewFixedView(spaceId: space.id, kind: kind, cycle: .mensual, currency: currency) }
        }
    }

    private func list(_ items: [Recurring], highlight: Bool = false) -> some View {
        Card(padding: Spacing.s3) {
            VStack(spacing: Spacing.s2) {
                ForEach(items) { item in
                    Button { editing = item } label: { row(item, highlight: highlight) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ item: Recurring, highlight: Bool) -> some View {
        let product = products.first { $0.id == item.productId }
        let paidWith = product.map { p in p.last4.map { "\(p.name) ·· \($0)" } ?? p.name }
        let finished = isFinishedByEnd(item)
        let schedule = finished ? nil : FixedMath.scheduleText(cycle: item.cycle, nextDate: item.nextDate, dateUnset: item.dateUnset, calendar: calendar)
        let subtitle = [schedule, item.endText(calendar: calendar), paidWith]
            .compactMap { $0 }.joined(separator: " · ")
        return ListRow(tile: entryTile(icon: item.icon, name: item.name, kind: item.kind), title: item.name, subtitle: subtitle) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(signedAmount(item.amountMinor, item.kind, currency))
                    .appFont(.cifra)
                    .foregroundStyle(item.kind == .ingreso ? Palette.hielo : Palette.texto1)
                if finished {
                    Badge(text: "Terminado", tone: .neutral)
                } else if !item.active {
                    Badge(text: "Pausado", tone: .neutral)
                } else if highlight {
                    Badge(text: "Poner fecha", tone: .oro)
                } else {
                    Text(DueText.describe(item.nextDate, now: .now, calendar: calendar)).appFont(.leyenda).foregroundStyle(Palette.texto2)
                }
            }
        }
        .opacity(item.active ? 1 : 0.55)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para editar")
    }

    private func money(_ minor: Int64) -> String { Money(minor: minor, currency: currency).formatted() }

    private func isFinishedByEnd(_ item: Recurring) -> Bool {
        (item.endDate != nil || item.totalCount != nil) && item.isFinished(calendar: calendar)
    }
}

extension EntryKind: Identifiable {
    var id: String { rawValue }
}
