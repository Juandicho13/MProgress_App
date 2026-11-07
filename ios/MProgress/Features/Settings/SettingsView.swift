import SwiftUI
import UIKit
import SwiftData

/// Tema de la app (pantalla 5). Oscuro por defecto, como IronProgress.
enum AppTheme: String, CaseIterable, Identifiable {
    case oscuro, claro, sistema
    static let storageKey = "apariencia.tema"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .oscuro: "Oscuro"
        case .claro: "Claro"
        case .sistema: "Sistema"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .oscuro: .dark
        case .claro: .light
        case .sistema: nil
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .oscuro: .dark
        case .claro: .light
        case .sistema: .unspecified
        }
    }

    /// Aplica el tema a todas las ventanas abiertas, hojas incluidas.
    @MainActor
    static func apply(_ raw: String) {
        let style = (AppTheme(rawValue: raw) ?? .oscuro).interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows { window.overrideUserInterfaceStyle = style }
        }
    }
}

enum SettingsRoute: Hashable {
    case diseno, moneda, respaldo, avisos, novedades, cuenta, comercios, automatico
}

/// Ajustes (pantalla 13): General, Datos e Información, con la firma al pie.
struct SettingsView: View {
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<MerchantAlias> { $0.deletedAt == nil }) private var merchantAliases: [MerchantAlias]
    @AppStorage(LockGate.enabledKey) private var faceID = false
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.oscuro.rawValue
    @AppStorage(GlassLevel.storageKey) private var glassRaw = GlassLevel.normal.rawValue
    @AppStorage(AlertSettings.daysBeforeKey) private var daysBefore = 3
    @AppStorage(AlertSettings.enabledKey) private var alertsEnabled = true
    @AppStorage(AlertSettings.atMinutesKey) private var alertsMinutes = 540
    @AppStorage(BackupService.lastBackupKey) private var lastBackup: Double = 0
    @AppStorage(AppIconChoice.storageKey) private var iconRaw = AppIconChoice.trazo.rawValue
    @AppStorage(OnboardingModel.doneKey) private var onboardingDone = true
    @AppStorage(Guide.dismissedKey) private var guideHidden = false
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @State private var confirmsErase = false
    @State private var eraseError: String?
    @State private var erasing = false
    private var cloud: CloudAccount { .shared }
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AutoSetup.dobleToque.storageKey) private var backTapAt: Double = 0
    @AppStorage(AutoSetup.applePay.storageKey) private var applePayAt: Double = 0
    @AppStorage(AutoSetup.sms.storageKey) private var smsAt: Double = 0
    /// Igual que el paso de Primeros pasos: alguno de los atajos ya funciona.
    private var autoConfigured: Bool { backTapAt > 0 || applePayAt > 0 || smsAt > 0 }
    @Environment(\.calendar) private var calendar

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Ajustes").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    HStack(spacing: Spacing.s3) {
                        Avatar(name: "Mi cuenta", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cloud.email ?? "Sin cuenta").appFont(.titulo3).foregroundStyle(Palette.texto1).lineLimit(1)
                            Text(cloud.isSignedIn ? "Cifrado y sincronizado con tu cuenta" : "Todo se guarda en este iPhone")
                                .appFont(.cuerpo2)
                                .foregroundStyle(Palette.texto2)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    SectionLabel(text: "General")
                    group {
                        Toggle(isOn: $faceID) {
                            Text("Bloqueo con Face ID").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                        }
                        .tint(Palette.brasa)
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                        if faceID {
                            divider
                            LockDelayRow()
                        }
                        divider
                        link("Moneda", value: space.map { "\($0.currency.code) \($0.currency.symbol)" } ?? "COP $", route: .moneda)
                        divider
                        link("Diseño", value: AccentPresets.summary(theme: AppTheme(rawValue: themeRaw)?.title ?? "Oscuro",
                                                                    glass: (GlassLevel(rawValue: glassRaw) ?? .normal).title,
                                                                    icon: (AppIconChoice(rawValue: iconRaw) ?? .trazo).symbolTitle,
                                                                    accentId: LiveColors.shared.accentId, incomeId: LiveColors.shared.incomeId),
                             route: .diseno)
                        divider
                        link("Registro automático", value: autoConfigured ? "Configurado" : "Sin configurar", route: .automatico)
                    }

                    SectionLabel(text: "Datos")
                    group {
                        link("Respaldo y dispositivos", value: lastBackupText, route: .respaldo)
                        divider
                        row("Espacios compartidos", value: "Pronto")
                        divider
                        link("Avisos", value: AlertSettings.summary(enabled: alertsEnabled, daysBefore: daysBefore, atMinutes: alertsMinutes), route: .avisos)
                        divider
                        link("Nombres de comercios", value: merchantAliasesText, route: .comercios)
                    }

                    SectionLabel(text: "Información")
                    group {
                        link("Novedades", value: AppInfo.version, route: .novedades)
                        divider
                        // Falta el correo de soporte: Juan lo define antes de publicar.
                        row("Escríbeme", value: "Pronto")
                        // Primeros pasos ocultos con la X en Inicio: aquí se vuelven a mostrar.
                        if guideHidden {
                            divider
                            Button {
                                guideHidden = false
                                undo?.show("Los primeros pasos vuelven a Inicio")
                            } label: { rowContent(Guide.settingsTitle, value: Guide.settingsValue) }
                                .buttonStyle(.plain)
                        }
                    }

                    SectionLabel(text: "Cuenta")
                    group {
                        link("Cuenta y nube", value: cloud.isSignedIn ? cloud.status.title : "Crear o entrar", route: .cuenta)
                        divider
                        Button(role: .destructive) { confirmsErase = true } label: {
                            HStack {
                                Text("Borrar cuenta y datos").appFont(.cuerpo).foregroundStyle(Palette.peligro)
                                Spacer()
                                Image(systemName: "trash").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.peligro)
                            }
                            .padding(.horizontal, Spacing.s2)
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text(cloud.isSignedIn
                         ? "Borra tu cuenta en la nube con todo lo que tiene, y tus movimientos, bancos, pagos fijos, metas, respaldos y ajustes de este iPhone. No se puede deshacer."
                         : "Borra tus movimientos, bancos, pagos fijos, metas, respaldos y ajustes de este iPhone. No se puede deshacer.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)

                    #if DEBUG
                    Button("Volver a ver el onboarding") { onboardingDone = false }
                        .appFont(.etiqueta)
                        .foregroundStyle(Palette.texto2)
                        .frame(minHeight: Size.toqueMinimo)
                    #endif

                    SignatureFooter()
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.top, Spacing.s4)
                .padding(.bottom, Spacing.s8)
            }
            .scrollIndicators(.hidden)
            .background(Palette.fondo.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("¿Borrar tu cuenta y todos tus datos?", isPresented: $confirmsErase, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { erase() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(cloud.isSignedIn
                     ? "Se borra tu cuenta en la nube y todo lo que hay en este iPhone, también los respaldos. La app vuelve al inicio como nueva."
                     : "Se borra todo lo que hay en este iPhone, también los respaldos. La app vuelve al inicio como nueva.")
            }
            .alert("No se pudo borrar", isPresented: Binding(get: { eraseError != nil }, set: { if !$0 { eraseError = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(eraseError ?? "")
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .diseno: DesignView()
                case .moneda: CurrencyView()
                case .respaldo: BackupView()
                case .avisos: AlertsView()
                case .novedades: WhatsNewView()
                case .cuenta: AccountView()
                case .comercios: MerchantAliasesView()
                case .automatico: AutoCaptureView()
                }
            }
        }
    }

    private func erase() {
        guard !erasing else { return }
        erasing = true
        Task {
            defer { erasing = false }
            // Primero la cuenta en la nube (función delete_my_account); si no se puede, no se borra nada.
            if cloud.isSignedIn {
                do {
                    try await cloud.deleteRemoteAccount()
                } catch {
                    eraseError = "No se pudo borrar tu cuenta en la nube. Revisa tu conexión e intenta de nuevo."
                    return
                }
            }
            do {
                try AccountEraser.eraseAll(context: modelContext)
                faceID = false
                themeRaw = AppTheme.oscuro.rawValue
                onboardingDone = false
            } catch {
                eraseError = "Intenta de nuevo. Si sigue pasando, reinicia la app."
            }
        }
    }

    /// "Ninguno", "1 comercio", "3 comercios".
    private var merchantAliasesText: String {
        let count = merchantAliases.filter { $0.spaceId == space?.id }.count
        return count == 0 ? "Ninguno" : "\(count) \(count == 1 ? "comercio" : "comercios")"
    }

    private var lastBackupText: String {
        guard lastBackup > 0 else { return "Nunca" }
        return DueText.describe(Date(timeIntervalSinceReferenceDate: lastBackup), now: .now, calendar: calendar)
    }

    private var divider: some View { Divider().overlay(Palette.linea) }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Card(padding: Spacing.s2) { VStack(spacing: 0) { content() } }
    }

    private func link(_ title: String, value: String?, route: SettingsRoute) -> some View {
        NavigationLink(value: route) { rowContent(title, value: value) }
            .buttonStyle(.plain)
    }

    private func row(_ title: String, value: String?) -> some View {
        rowContent(title, value: value, chevron: false).opacity(0.6)
    }

    private func rowContent(_ title: String, value: String?, chevron: Bool = true) -> some View {
        HStack {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer()
            if let value { Text(value).appFont(.cuerpo2).foregroundStyle(Palette.texto2).lineLimit(1) }
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.texto2)
            }
        }
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

enum AppInfo {
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return short
    }
}
