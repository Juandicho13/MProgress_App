import SwiftUI
import SwiftData
import UIKit

/// Avisos (pantalla 22): lo de hoy y mañana con ícono por tipo, y los ajustes de avisos.
struct AlertsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }) private var allRecurring: [Recurring]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }) private var allEntries: [Entry]
    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil }) private var allBudgets: [Budget]
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }) private var categories: [SpendCategory]

    @AppStorage(AlertSettings.enabledKey) private var generalEnabled = true
    @AppStorage(AlertSettings.daysBeforeKey) private var daysBefore = 3
    @AppStorage(AlertSettings.atMinutesKey) private var atMinutes = 540
    @AppStorage(AlertSettings.budgetsKey) private var budgetAlerts = true
    @AppStorage(AlertSettings.cardsKey) private var cardAlerts = true
    @AppStorage(AlertSettings.weeklyKey) private var weekly = false
    @State private var authorized = true
    @State private var denied = false
    @Environment(\.openURL) private var openURL

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let tint: Color
        let foreground: Color
        let title: String
        let subtitle: String
    }

    private var items: [Item] {
        let id = space?.id
        let now = Date.now
        var result: [Item] = []
        let recurring = allRecurring.filter { $0.spaceId == id && $0.active }
        for charge in BalanceCalculator.upcoming(recurring: recurring.map(\.record), now: now, calendar: calendar, kind: nil, limit: 50)
        where charge.daysLeft <= 1 {
            result.append(Item(id: "c\(charge.recurringId)", symbol: "bell", tint: Palette.oroVelo, foreground: Palette.oro,
                               title: "\(charge.name) \(charge.kind == .ingreso ? "llega" : "se cobra") \(charge.daysLeft < 0 ? "y está vencido" : ReminderPlanner.inDays(max(0, charge.daysLeft)))",
                               subtitle: Money(minor: charge.amountMinor, currency: currency).formatted()))
        }
        let statuses = BudgetMath.statuses(budgets: allBudgets.filter { $0.spaceId == id }.map(\.record),
                                           entries: allEntries.filter { $0.spaceId == id }.map(\.record), now: now, calendar: calendar)
        for status in statuses where status.level > .bien {
            let name = status.budget.categoryId.flatMap { cid in categories.first { $0.id == cid }?.name } ?? "el total del mes"
            let over = status.level == .superado
            result.append(Item(id: "b\(status.budget.id)", symbol: "exclamationmark.triangle", tint: over ? Palette.peligroVelo : Palette.brasaVelo,
                               foreground: over ? Palette.peligro : Palette.brasaTinta,
                               title: over ? "Te pasaste del límite" : "Te acercas al límite",
                               subtitle: "\(name.capitalizedFirst) al \(Int((status.ratio * 100).rounded())) %"))
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Avisos").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                SectionLabel(text: "Hoy")
                Card(padding: Spacing.s3) {
                    if items.isEmpty {
                        Text("Nada pendiente por hoy.").appFont(.cuerpo2).foregroundStyle(Palette.texto2).padding(Spacing.s2)
                    } else {
                        VStack(spacing: Spacing.s2) {
                            ForEach(items) { item in
                                ListRow(tile: IconTile(content: .symbol(item.symbol), tint: item.tint, foreground: item.foreground),
                                        title: item.title, subtitle: item.subtitle) { EmptyView() }
                                    .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                if !authorized {
                    permissionCard
                }
                SectionLabel(text: "Aviso general de pagos fijos")
                Card(padding: Spacing.s2) {
                    VStack(spacing: 0) {
                        toggle("Avisarme antes de cada pago", $generalEnabled)
                        Divider().overlay(Palette.linea)
                        Picker(selection: $daysBefore) {
                            ForEach(0...14, id: \.self) { day in Text(day == 0 ? "El mismo día" : "\(day)").tag(day) }
                        } label: {
                            Text("Días antes").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                        }
                        .tint(Palette.texto2)
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                        .disabled(!generalEnabled)
                        Divider().overlay(Palette.linea)
                        Picker(selection: $atMinutes) {
                            ForEach(Array(stride(from: 360, through: 1320, by: 30)), id: \.self) { minutes in
                                Text(ReminderPlanner.timeText(minutes)).tag(minutes)
                            }
                        } label: {
                            Text("Hora del aviso").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                        }
                        .tint(Palette.texto2)
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                    }
                }
                Text("Cada pago fijo usa este aviso, uno propio o ninguno: en Pagos fijos tócalo y elige Aviso.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
                SectionLabel(text: "Otros avisos")
                Card(padding: Spacing.s2) {
                    VStack(spacing: 0) {
                        toggle("Avisar al acercarme a un límite", $budgetAlerts)
                        Divider().overlay(Palette.linea)
                        toggle("Avisar el pago de mis tarjetas", $cardAlerts)
                        Divider().overlay(Palette.linea)
                        toggle("Resumen semanal", $weekly)
                    }
                }
                Text("Los límites avisan al 80 % y al 100 %. Las tarjetas usan los días y la hora del aviso general.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshPermission() }
        .onChange(of: generalEnabled) {
            Task {
                if generalEnabled { authorized = await NotificationScheduler.requestIfNeeded() }
                await NotificationScheduler.reschedule(context: context)
                await refreshPermission()
            }
        }
        .onChange(of: daysBefore) { reschedule() }
        .onChange(of: atMinutes) { reschedule() }
        .onChange(of: cardAlerts) { reschedule() }
        .onChange(of: weekly) {
            Task {
                if weekly { authorized = await NotificationScheduler.requestIfNeeded() }
                await NotificationScheduler.reschedule(context: context)
            }
        }
    }

    /// Sin permiso. Si nunca se pidió, se pide aquí; si la persona dijo que no, solo se activa desde Ajustes del iPhone.
    private var permissionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Las notificaciones están apagadas").appFont(.titulo3).foregroundStyle(Palette.texto1)
                if denied {
                    Text("Para que te avisemos antes de cada pago: abre Ajustes del iPhone › Notificaciones › MProgress y activa Permitir notificaciones.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                    Button("Abrir Ajustes del iPhone") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.secondary)
                } else {
                    Text("Actívalas para que te avisemos antes de cada pago.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    Button("Activar") {
                        Task {
                            UserDefaults.standard.set(true, forKey: AlertSettings.askedKey)
                            _ = await NotificationScheduler.requestIfNeeded()
                            await NotificationScheduler.reschedule(context: context)
                            await refreshPermission()
                        }
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    private func refreshPermission() async {
        authorized = await NotificationScheduler.isAuthorized()
        denied = await NotificationScheduler.isDenied()
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
        }
        .tint(Palette.brasa)
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
    }

    private func reschedule() {
        Task { await NotificationScheduler.reschedule(context: context) }
    }
}

extension String {
    /// Primera letra en mayúscula: "el total del mes" pasa a "El total del mes".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
