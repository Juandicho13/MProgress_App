import SwiftUI
import SwiftData

@main
struct MProgressApp: App {
    let container: ModelContainer
    @AppStorage(OnboardingModel.doneKey) private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.oscuro.rawValue

    init() {
        AppFont.register()
        do {
            container = try Persistence.shared()
            try Seed.runIfNeeded(context: container.mainContext, localUser: LocalIdentity.userId)
        } catch {
            fatalError("No se pudo abrir la base local: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingDone {
                    RootView()
                } else {
                    OnboardingView { onboardingDone = true }
                }
            }
            .preferredColorScheme((AppTheme(rawValue: themeRaw) ?? .oscuro).colorScheme)
            .lockGate()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Al volver a la app se rehacen los avisos: las fechas de los pagos fijos pudieron moverse.
            let container = container
            // Al salir o al volver se actualizan los widgets.
            if phase == .background || phase == .active {
                WidgetPublisher.publish(context: container.mainContext)
            }
            guard phase == .active else { return }
            Task { @MainActor in
                await NotificationScheduler.reschedule(context: container.mainContext)
                // Un respaldo cifrado al día, al volver a la app (F09-06).
                _ = try? BackupService.autoBackupIfNeeded(context: container.mainContext)
            }
        }
    }
}
