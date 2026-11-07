import SwiftUI
import SwiftData

/// A dónde lleva cada paso de los primeros pasos (dentro de la pila de Inicio).
enum GuideRoute: Hashable, Identifiable {
    case fijos, automatico, limites, ahorro, avisos, cuenta
    var id: Self { self }
}

/// "Saca todo el provecho a MProgress": primeros pasos en Inicio, debajo de los accesos rápidos.
/// Cada paso se marca solo con los datos reales (`Domain/Guide.swift`) y al tocarlo abre su pantalla.
/// Se pliega con el chevrón, se oculta con la X y, con los ocho hechos, celebra una vez y se va.
/// Las marcas (oculta, celebrada, plegada) son de este dispositivo. Igual que GuideCard de Android.
struct GuideCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }) private var allEntries: [Entry]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }) private var allRecurring: [Recurring]
    @Query(filter: #Predicate<Institution> { $0.deletedAt == nil }) private var allInstitutions: [Institution]
    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil }) private var allBudgets: [Budget]
    @Query(filter: #Predicate<SavingsGoal> { $0.deletedAt == nil }) private var allGoals: [SavingsGoal]
    @Query(filter: #Predicate<Reminder> { $0.deletedAt == nil }) private var allReminders: [Reminder]

    @AppStorage(Guide.dismissedKey) private var dismissed = false
    @AppStorage(Guide.celebratedKey) private var celebrated = false
    @AppStorage(Guide.collapsedKey) private var collapsed = false
    @AppStorage(Guide.firstStepOpenKey) private var firstStepOpen = false
    @AppStorage(LockGate.enabledKey) private var lockEnabled = false
    @AppStorage(AlertSettings.enabledKey) private var alertsEnabled = true
    @AppStorage(AutoSetup.dobleToque.storageKey) private var backTapAt: Double = 0
    @AppStorage(AutoSetup.applePay.storageKey) private var applePayAt: Double = 0
    @AppStorage(AutoSetup.sms.storageKey) private var smsAt: Double = 0

    @State private var notificationsAllowed = false
    @State private var route: GuideRoute?
    @State private var adding: AddRequest?
    @State private var addingBank = false
    @State private var confirmsHide = false
    @State private var confirmsLock = false

    struct AddRequest: Identifiable {
        let id = UUID()
        var kind: EntryKind
        var cycle: AddEntryModel.CycleChoice
    }

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }

    private var snapshot: GuideSnapshot {
        let id = space?.id
        let entries = allEntries.filter { $0.spaceId == id }
        let recurring = allRecurring.filter { $0.spaceId == id && $0.active }
        let reminders = allReminders.filter { $0.spaceId == id }
        let modes: [ReminderMode?] = recurring.map { item in reminders.first { $0.recurringId == item.id }?.mode }
        return GuideSnapshot(
            hasIncome: recurring.contains { $0.kind == .ingreso } || entries.contains { $0.kind == .ingreso },
            hasFixedExpense: recurring.contains { $0.kind == .gasto },
            hasExpense: entries.contains { $0.kind == .gasto },
            hasInstitution: allInstitutions.contains { $0.spaceId == id },
            autoCaptureConfigured: backTapAt > 0 || applePayAt > 0 || smsAt > 0,
            hasBudget: allBudgets.contains { $0.spaceId == id },
            hasGoal: allGoals.contains { $0.spaceId == id },
            notificationsAllowed: notificationsAllowed,
            hasReminder: Guide.hasReminder(modes: modes, generalEnabled: alertsEnabled),
            lockEnabled: lockEnabled,
            signedIn: CloudAccount.shared.isSignedIn
        )
    }

    var body: some View {
        let snapshot = self.snapshot
        let steps = Guide.steps(snapshot)
        Group {
            switch Guide.visibility(steps, dismissed: dismissed, celebrated: celebrated) {
            case .hidden:
                EmptyView()
            case .celebration:
                celebration
            case .checklist:
                checklist(steps, snapshot: snapshot)
            }
        }
        .task { notificationsAllowed = await NotificationScheduler.isAuthorized() }
        .onChange(of: scenePhase) { _, phase in
            // Al volver de Ajustes del iPhone el permiso puede haber cambiado.
            guard phase == .active else { return }
            Task { notificationsAllowed = await NotificationScheduler.isAuthorized() }
        }
        .onChange(of: route) { _, value in
            // Al volver de Avisos se vuelve a leer el permiso.
            guard value == nil else { return }
            Task { notificationsAllowed = await NotificationScheduler.isAuthorized() }
        }
        .navigationDestination(item: $route) { target in
            switch target {
            case .fijos: FixedView()
            case .automatico: AutoCaptureView()
            case .limites: BudgetsView()
            case .ahorro: SavingsView()
            case .avisos: AlertsView()
            case .cuenta: AccountView()
            }
        }
        .sheet(item: $adding) { request in
            if let space {
                AddEntryView(spaceId: space.id, kind: request.kind, cycle: request.cycle, currency: currency)
            }
        }
        .sheet(isPresented: $addingBank) {
            if let space { AddInstitutionView(spaceId: space.id) }
        }
        .confirmationDialog(Guide.hideQuestion, isPresented: $confirmsHide, titleVisibility: .visible) {
            Button("Ocultar", role: .destructive) { withAnimation(.snappy) { dismissed = true } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(Guide.hideMessage)
        }
        .confirmationDialog("¿Proteger MProgress con Face ID?", isPresented: $confirmsLock, titleVisibility: .visible) {
            Button("Activar bloqueo") { lockEnabled = true }
            Button("Ahora no", role: .cancel) {}
        } message: {
            Text("Cada vez que abras la app te pide tu rostro o tu código. Lo cambias en Ajustes.")
        }
    }

    // MARK: Lista

    private func checklist(_ steps: [GuideStep], snapshot: GuideSnapshot) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .center, spacing: Spacing.s2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Guide.title).appFont(.titulo3).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                        Text(Guide.progressText(steps)).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    }
                    Spacer(minLength: Spacing.s2)
                    iconButton(collapsed ? "chevron.down" : "chevron.up", label: collapsed ? "Mostrar los pasos" : "Plegar los pasos") {
                        withAnimation(.snappy) { collapsed.toggle() }
                    }
                    iconButton("xmark", label: "Ocultar los primeros pasos") { confirmsHide = true }
                }
                GuideProgressBar(ratio: Guide.progress(steps))
                    .accessibilityLabel("Primeros pasos")
                    .accessibilityValue(Guide.progressText(steps))
                if !collapsed {
                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        if let first = steps.first, first.done { firstDoneRow(first, snapshot: snapshot) }
                        ForEach(Guide.visiblePendingSteps(steps)) { step in
                            stepRow(step, snapshot: snapshot)
                        }
                    }
                    if let more = Guide.moreText(steps) {
                        Text(more).appFont(.leyenda).foregroundStyle(Palette.texto2).lineLimit(2)
                    }
                }
            }
        }
    }

    private func stepRow(_ step: GuideStep, snapshot: GuideSnapshot) -> some View {
        Button { open(step.id, snapshot: snapshot) } label: {
            HStack(spacing: Spacing.s3) {
                IconTile(content: .symbol(step.symbol), tint: Palette.brasaVelo, foreground: Palette.brasaTinta)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title).appFont(.cuerpo).foregroundStyle(Palette.texto1).lineLimit(2).multilineTextAlignment(.leading)
                    if step.id == .primerosDatos {
                        Text(Guide.firstStepSubtitle(snapshot)).appFont(.cuerpo2).foregroundStyle(Palette.texto2).lineLimit(2)
                    }
                }
                Spacer(minLength: Spacing.s2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.texto2)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// El primer paso hecho queda en una sola fila con chevrón; al abrirla se ven sus tres partes.
    private func firstDoneRow(_ step: GuideStep, snapshot: GuideSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Button {
                withAnimation(.snappy) { firstStepOpen.toggle() }
            } label: {
                HStack(spacing: Spacing.s3) {
                    IconTile(content: .symbol("checkmark"), tint: Palette.exito.opacity(0.16), foreground: Palette.exito)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).appFont(.cuerpo).foregroundStyle(Palette.texto2).lineLimit(2).multilineTextAlignment(.leading)
                        Text(Guide.firstStepSubtitle(snapshot)).appFont(.cuerpo2).foregroundStyle(Palette.texto2).lineLimit(1)
                    }
                    Spacer(minLength: Spacing.s2)
                    Image(systemName: firstStepOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.texto2)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue("Hecho")
            if firstStepOpen {
                ForEach(Guide.parts(snapshot)) { part in
                    Label(part.title, systemImage: part.done ? "checkmark.circle.fill" : "circle")
                        .appFont(.cuerpo2)
                        .foregroundStyle(part.done ? Palette.exito : Palette.texto2)
                        .padding(.leading, Size.baldosa + Spacing.s3)
                        .frame(minHeight: 28)
                }
            }
        }
    }

    // MARK: Celebración

    private var celebration: some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.s3) {
                IconTile(content: .symbol("checkmark.seal"), tint: Palette.exito.opacity(0.16), foreground: Palette.exito)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(Guide.celebrationTitle).appFont(.titulo3).foregroundStyle(Palette.texto1)
                    Text(Guide.celebrationText).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    GuideProgressBar(ratio: 1).padding(.top, Spacing.s1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .task {
            // Se ve unos segundos y se va sola; si sales antes de Inicio, igual queda vista.
            try? await Task.sleep(for: .seconds(Guide.celebrationSeconds))
            withAnimation(.snappy) { celebrated = true }
        }
    }

    // MARK: Ayudas

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.texto2)
                .frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func open(_ id: GuideStepId, snapshot: GuideSnapshot) {
        switch id {
        case .primerosDatos:
            switch Guide.nextPart(snapshot) {
            case .ingreso: adding = AddRequest(kind: .ingreso, cycle: .mensual)
            case .fijo: route = .fijos
            case .gasto: adding = AddRequest(kind: .gasto, cycle: .puntual)
            case nil: break
            }
        case .bancos: addingBank = true
        case .automatico: route = .automatico
        case .limites: route = .limites
        case .ahorro: route = .ahorro
        case .avisos: route = .avisos
        case .bloqueo: confirmsLock = true
        case .cuenta: route = .cuenta
        }
    }
}

/// Barra de avance de los primeros pasos.
private struct GuideProgressBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.superficie3)
                Capsule().fill(Palette.brasa).frame(width: max(6, proxy.size.width * min(1, max(0, ratio))))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
    }
}
