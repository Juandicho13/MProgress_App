import SwiftUI
import LocalAuthentication

/// Bloqueo con Face ID al abrir (F09-05). Tapa la app al salir y pide la cara (o el código) al volver.
struct LockGate: ViewModifier {
    static let enabledKey = "seguridad.faceID"

    @AppStorage(LockGate.enabledKey) private var enabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = UserDefaults.standard.bool(forKey: LockGate.enabledKey)
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && locked {
                    lockScreen.transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if enabled { locked = true }
                case .active:
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
