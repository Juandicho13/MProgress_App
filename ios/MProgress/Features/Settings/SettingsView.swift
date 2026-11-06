import SwiftUI
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
}

enum SettingsRoute: Hashable {
    case apariencia, moneda, icono, respaldo, avisos, novedades
}

/// Ajustes (pantalla 13): General, Datos e Información, con la firma al pie.
struct SettingsView: View {
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @AppStorage(LockGate.enabledKey) private var faceID = false
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.oscuro.rawValue
    @AppStorage(GlassLevel.storageKey) private var glassRaw = GlassLevel.normal.rawValue
    @AppStorage(AlertSettings.daysBeforeKey) private var daysBefore = 3
    @AppStorage(BackupService.lastBackupKey) private var lastBackup: Double = 0
    @AppStorage(AppIconChoice.storageKey) private var iconRaw = AppIconChoice.brasa.rawValue
    @AppStorage(OnboardingModel.doneKey) private var onboardingDone = true
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
                            Text("Sin cuenta").appFont(.titulo3).foregroundStyle(Palette.texto1)
                            Text("Todo se guarda en este iPhone").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
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
                        divider
                        link("Moneda", value: space.map { "\($0.currency.code) \($0.currency.symbol)" } ?? "COP $", route: .moneda)
                        divider
                        link("Apariencia", value: "\(AppTheme(rawValue: themeRaw)?.title ?? "Oscuro") · vidrio \((GlassLevel(rawValue: glassRaw) ?? .normal).title.lowercased())", route: .apariencia)
                        divider
                        link("Ícono de la app", value: AppIconChoice(rawValue: iconRaw)?.title ?? "Brasa", route: .icono)
                    }

                    SectionLabel(text: "Datos")
                    group {
                        link("Respaldo y dispositivos", value: lastBackupText, route: .respaldo)
                        divider
                        row("Espacios compartidos", value: "Pronto")
                        divider
                        link("Avisos", value: daysBefore == 0 ? "El mismo día" : "\(daysBefore) días antes", route: .avisos)
                    }

                    SectionLabel(text: "Información")
                    group {
                        link("Novedades", value: AppInfo.version, route: .novedades)
                        divider
                        // Falta el correo de soporte: Juan lo define antes de publicar.
                        row("Escríbeme", value: "Pronto")
                    }

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
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .apariencia: AppearanceView()
                case .moneda: CurrencyView()
                case .icono: AppIconView()
                case .respaldo: BackupView()
                case .avisos: AlertsView()
                case .novedades: WhatsNewView()
                }
            }
        }
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
