import SwiftUI

/// Monto ya puesto que se puede cambiar (Pagar tarjeta, Marcar pagado y Transferir): campo con borde y tinte,
/// lápiz y "Toca para cambiar el valor". Tocarlo abre el teclado numérico, que muestra quien lo usa.
struct EditableAmountField: View {
    let input: AmountInput
    /// El teclado escribe aquí: borde brasa y cursor.
    let editing: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var caretOn = true

    var body: some View {
        VStack(spacing: Spacing.s2) {
            Button(action: onTap) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                    Text(input.currency.symbol)
                        .appFont(.cifraGrande)
                        .foregroundStyle(editing ? Palette.brasaTinta : Palette.texto2)
                    Text(input.display)
                        .appFont(.cifraHeroe)
                        .foregroundStyle(input.text.isEmpty ? Palette.texto2 : Palette.texto1)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: input.text)
                    if editing {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Palette.brasa)
                            .frame(width: 3, height: 44)
                            .opacity(caretOn ? 1 : 0)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
                            .accessibilityHidden(true)
                    }
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.brasaTinta)
                        .accessibilityHidden(true)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.vertical, Spacing.s3)
                .padding(.horizontal, Spacing.s4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous)
                        .fill(editing ? Palette.brasaVelo : Palette.superficie3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous)
                        .stroke(editing ? Palette.brasa : Palette.brasa.opacity(0.45), lineWidth: editing ? 2 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Monto, \(input.money.formatted())")
            .accessibilityHint("Toca para cambiar el valor")
            .accessibilityAddTraits(editing ? [.isSelected] : [])
            Text(editing ? "Escribe el nuevo valor" : "Toca para cambiar el valor")
                .appFont(.leyenda)
                .foregroundStyle(editing ? Palette.brasaTinta : Palette.texto2)
        }
        .animation(.snappy, value: editing)
        .task(id: editing) {
            caretOn = true
            guard editing, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(550))
                caretOn.toggle()
            }
        }
    }
}
