import SwiftUI

/// Fila "Bloquear" de Ajustes, debajo de Bloqueo con Face ID: Inmediatamente, después de 30 segundos o de 1 minuto.
/// Se guarda en este dispositivo.
struct LockDelayRow: View {
    @AppStorage(LockDelay.storageKey) private var delaySeconds = LockDelay.inmediatamente.seconds

    private var delay: LockDelay { LockDelay.from(seconds: delaySeconds) }

    var body: some View {
        Menu {
            Picker("Bloquear", selection: $delaySeconds) {
                ForEach(LockDelay.allCases, id: \.self) { option in
                    Text(option.title).tag(option.seconds)
                }
            }
        } label: {
            HStack {
                Text("Bloquear").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Spacer()
                Text(delay.title).appFont(.cuerpo2).foregroundStyle(Palette.texto2).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.texto2)
            }
            .padding(.horizontal, Spacing.s2)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bloquear, \(delay.title)")
    }
}
