import SwiftUI
import SwiftData
import Combine

enum AppTab: String, CaseIterable, Identifiable {
    case inicio, resumen, dinero, calendario, ajustes
    var id: String { rawValue }

    var title: String {
        switch self {
        case .inicio: "Inicio"
        case .resumen: "Resumen"
        case .dinero: "Dinero"
        case .calendario: "Calendario"
        case .ajustes: "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .inicio: "house"
        case .resumen: "chart.bar"
        case .dinero: "building.columns"
        case .calendario: "calendar"
        case .ajustes: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = .inicio
    @State private var undo = UndoCenter()
    @State private var router = QuickAddRouter.shared
    @State private var alertsAsk = NotificationAsk.shared
    @Environment(\.modelContext) private var context
    @AppStorage(GlassLevel.storageKey) private var glassRaw = GlassLevel.normal.rawValue

    private var glassLevel: GlassLevel { GlassLevel(rawValue: glassRaw) ?? .normal }

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.fondo.ignoresSafeArea()

            Group {
                switch tab {
                case .inicio:
                    NavigationStack {
                        HomeView()
                            .background(Palette.fondo.ignoresSafeArea())
                            .toolbar(.hidden, for: .navigationBar)
                    }
                case .calendario:
                    CalendarView()
                case .resumen:
                    SummaryView()
                case .dinero:
                    MoneyView()
                case .ajustes:
                    SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Size.barra + Spacing.s4) }

            VStack(spacing: Spacing.s2) {
                UndoToast(center: undo)
                    .padding(.horizontal, Spacing.s2)
                GlassTabBar(selection: $tab)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, Spacing.s2)
            .animation(.snappy, value: undo.notice?.id)
        }
        .environment(\.glassLevel, glassLevel)
        .environment(undo)
        .onOpenURL { url in
            // Enlaces de los widgets: mprogress://rapido, fijos, calendario, inicio.
            switch url.host() {
            case CloudConfig.callbackHost:
                // Enlace mágico del correo: entra a la cuenta.
                tab = .ajustes
                Task { await CloudAccount.shared.handle(url: url) }
            case "rapido": router.pending = true
            case "calendario": tab = .calendario
            case "fijos":
                tab = .inicio
                router.openFixed = true
            default: tab = .inicio
            }
        }
        .sheet(isPresented: $router.pending) {
            QuickAddView()
                .environment(undo)
                .presentationCornerRadius(Radius.hoja)
        }
        // Sincroniza unos segundos después de cada cambio guardado (si hay cuenta).
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            CloudAccount.shared.scheduleSync()
        }
        // Código de recuperación recién creado: se muestra una vez.
        .sheet(item: Binding(get: { CloudAccount.shared.recoveryPrompt }, set: { CloudAccount.shared.recoveryPrompt = $0 })) { prompt in
            RecoveryCodeView(code: prompt.code)
        }
        // Otro iPhone entró con tu correo y espera tu aprobación.
        .alert("¿Apruebas tu otro dispositivo?",
               isPresented: Binding(get: { CloudAccount.shared.approvalPrompt != nil },
                                    set: { if !$0 { CloudAccount.shared.approvalPrompt = nil } }),
               presenting: CloudAccount.shared.approvalPrompt) { device in
            Button("Aprobar") { Task { await CloudAccount.shared.approve(device) } }
            Button("Ahora no", role: .cancel) { CloudAccount.shared.dismissApproval(device) }
        } message: { device in
            Text("\(device.name ?? "Un iPhone") entró con tu correo. Si fuiste tú, apruébalo para que pueda leer tus datos cifrados.")
        }
        // Permiso de avisos en el momento justo: después de crear el primer pago fijo o del onboarding con fijos.
        .alert("¿Te aviso antes de cada pago?", isPresented: $alertsAsk.pending) {
            Button("Sí, avísame") {
                Task { await alertsAsk.accept(context: context) }
            }
            Button("Ahora no", role: .cancel) { alertsAsk.decline() }
        } message: {
            Text("Te mando una notificación unos días antes de cada pago fijo. Lo cambias cuando quieras en Ajustes › Avisos.")
        }
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                let active = item == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = item }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .symbolVariant(active ? .fill : .none)
                        Text(item.title).appFont(.pestana).fontWeight(active ? .semibold : .medium)
                    }
                    .foregroundStyle(active ? Palette.brasaTinta : Palette.texto2)
                    .frame(maxWidth: .infinity, minHeight: Size.toqueMinimo)
                    .background {
                        if active { Capsule().fill(Palette.vidrioSeleccion) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(Spacing.s2)
        .frame(height: Size.barra)
        .glassBackground(Capsule())
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
