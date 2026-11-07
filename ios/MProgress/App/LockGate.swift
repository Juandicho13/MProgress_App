import SwiftUI
import LocalAuthentication

/// Bloqueo con Face ID al abrir (F09-05). Tapa la app al salir y pide la cara (o el código) al volver.
/// Con "Bloquear" en Ajustes (como WhatsApp) solo la pide si estuvo fuera al menos ese tiempo; al abrirla en frío, siempre.
/// Fuera de la app siempre queda tapada, así el selector de apps nunca muestra los montos.
struct LockGate: ViewModifier {
    static let enabledKey = "seguridad.faceID"

    @AppStorage(LockGate.enabledKey) private var enabled = false
    @AppStorage(LockDelay.storageKey) private var delaySeconds = LockDelay.inmediatamente.seconds
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = UserDefaults.standard.bool(forKey: LockGate.enabledKey)
    @State private var covered = false
    /// Cuándo se fue a segundo plano, con un reloj que sigue contando con el teléfono dormido.
    @State private var backgroundedAt: ContinuousClock.Instant?
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && locked {
                    lockScreen.transition(.opacity)
                } else if enabled && covered {
                    privacyCover
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if enabled {
                        covered = true
                        if backgroundedAt == nil { backgroundedAt = .now }
                    }
                case .active:
                    covered = false
                    if enabled, let start = backgroundedAt {
                        let gone = start.duration(to: .now).components
                        let elapsed = Double(gone.seconds) + Double(gone.attoseconds) / 1e18
                        if LockTimeout.requiresAuth(elapsedSeconds: elapsed, delay: LockDelay.from(seconds: delaySeconds)) { locked = true }
                    }
                    backgroundedAt = nil
                    if enabled && locked { unlock() }
                default:
                    break
                }
            }
            .onChange(of: enabled) { _, on in
                // Al prenderlo se confirma que la cara funciona; si no, se apaga.
                if on { verifyToEnable() } else { locked = false }
            }
            .task { if enabled && locked { unlock() } }
    }

    private var lockScreen: some View {
        ZStack {
            Palette.fondo.ignoresSafeArea()
            VStack(spacing: Spacing.s5) {
                IconTile(content: .symbol("lock.fill"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta, size: 72, circle: true)
                Text("MProgress está bloqueada").appFont(.titulo2).foregroundStyle(Palette.texto1)
                if failed {
                    Text("No pudimos reconocerte.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                }
                Button("Desbloquear") { unlock() }.buttonStyle(.primary).frame(maxWidth: 240)
            }
            .padding(Spacing.margen)
        }
        .accessibilityElement(children: .contain)
    }

    /// Lo que se ve en el selector de apps mientras no hace falta desbloquear.
    private var privacyCover: some View {
        ZStack {
            Palette.fondo.ignoresSafeArea()
            IconTile(content: .symbol("lock.fill"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta, size: 72, circle: true)
        }
        .accessibilityHidden(true)
    }

    private func unlock() {
        Task { @MainActor in
            let context = LAContext()
            context.localizedFallbackTitle = "Usar código"
            do {
                let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Abre tus finanzas")
                withAnimation(.snappy) { locked = !ok }
                failed = !ok
            } catch {
                failed = true
            }
        }
    }

    private func verifyToEnable() {
        Task { @MainActor in
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                enabled = false
                return
            }
            let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Activa el bloqueo de MProgress")) ?? false
            if !ok { enabled = false }
            locked = false
        }
    }
}

extension View {
    func lockGate() -> some View { modifier(LockGate()) }
}
