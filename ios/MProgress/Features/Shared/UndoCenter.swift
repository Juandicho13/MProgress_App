import SwiftUI
import Observation

/// Aviso corto con "Deshacer" que aparece sobre la barra de pestañas (F04-02).
/// Se cierra solo a los 5 segundos o al tocar Deshacer. RootView lo pone con `.environment(_:)`.
@MainActor
@Observable
final class UndoCenter {
    struct Notice: Identifiable {
        let id = UUID()
        let message: String
        let undo: (@MainActor () -> Void)?
    }

    private(set) var notice: Notice?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, undo: (@MainActor () -> Void)? = nil) {
        let notice = Notice(message: message, undo: undo)
        self.notice = notice
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if self?.notice?.id == notice.id { self?.notice = nil }
        }
    }

    func performUndo() {
        notice?.undo?()
        dismiss()
    }

    func dismiss() {
        hideTask?.cancel()
        notice = nil
    }
}

/// El aviso en sí. Con VoiceOver se anuncia al aparecer.
struct UndoToast: View {
    let center: UndoCenter

    var body: some View {
        if let notice = center.notice {
            HStack(spacing: Spacing.s3) {
                Text(notice.message)
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto1)
                    .lineLimit(2)
                Spacer(minLength: Spacing.s2)
                if notice.undo != nil {
                    Button("Deshacer") { center.performUndo() }
                        .appFont(.titulo3)
                        .foregroundStyle(Palette.brasaTinta)
                        .frame(minHeight: Size.toqueMinimo)
                }
            }
            .padding(.horizontal, Spacing.s4)
            .frame(minHeight: 56)
            .glassBackground(RoundedRectangle(cornerRadius: Radius.boton, style: .continuous))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear { AccessibilityNotification.Announcement(notice.message).post() }
            .id(notice.id)
        }
    }
}
