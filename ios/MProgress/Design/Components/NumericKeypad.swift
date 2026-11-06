import SwiftUI

/// Teclado numérico propio (onboarding y Agregar). Escribe sobre un `AmountInput`.
struct NumericKeypad: View {
    @Binding var input: AmountInput

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [",", "0", "⌫"]]

    var body: some View {
        VStack(spacing: Spacing.s2) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Spacing.s2) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        let isComma = key == ","
        let disabled = isComma && !input.allowsDecimals
        Button {
            if key == "⌫" {
                input.deleteLast()
            } else {
                input.press(key)
            }
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.backward").font(.system(size: 20, weight: .medium))
                } else {
                    Text(key).font(.system(size: 24, weight: .medium))
                }
            }
            .foregroundStyle(Palette.texto1)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Radius.boton, style: .continuous)
                    .fill(key == "⌫" || isComma ? Color.clear : Palette.superficie3)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0 : 1)
        .accessibilityLabel(key == "⌫" ? "Borrar" : (isComma ? "Coma decimal" : key))
    }
}

/// Monto grande que se está escribiendo: "$ 45.500".
struct AmountDisplay: View {
    let input: AmountInput
    /// Seleccionado: el teclado escribe aquí. Se ve con borde brasa y cursor.
    var active = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var caretOn = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
            Text(input.currency.symbol)
                .appFont(.cifraGrande)
                .foregroundStyle(active ? Palette.brasaTinta : Palette.texto2)
            Text(input.display)
                .appFont(.cifraHeroe)
                .foregroundStyle(input.text.isEmpty ? Palette.texto2 : Palette.texto1)
                .contentTransition(.numericText())
                .animation(.snappy, value: input.text)
            if active {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Palette.brasa)
                    .frame(width: 3, height: 44)
                    .opacity(caretOn ? 1 : 0)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.vertical, Spacing.s3)
        .padding(.horizontal, Spacing.s4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous)
                .fill(active ? Palette.brasaVelo : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous)
                .stroke(active ? Palette.brasa : Palette.linea, lineWidth: active ? 2 : 1)
        )
        .animation(.snappy, value: active)
        .task(id: active) {
            caretOn = true
            guard active, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(550))
                caretOn.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monto, \(input.money.formatted())")
        .accessibilityAddTraits(active ? [.isSelected] : [])
        .accessibilityHint(active ? "" : "Toca para escribir el monto")
    }
}
