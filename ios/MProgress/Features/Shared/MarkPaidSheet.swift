import SwiftUI

/// Marcar pagado (o recibido) un pago fijo con el monto a la vista: viene el planeado y se puede cambiar,
/// porque lo que se pagó de verdad puede ser otro valor. Se guarda lo que la persona escribió.
struct MarkPaidSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: Recurring
    let currency: Currency
    let onConfirm: (Int64) -> Void

    @State private var amount: AmountInput
    @State private var editing = false

    init(item: Recurring, currency: Currency, onConfirm: @escaping (Int64) -> Void) {
        self.item = item
        self.currency = currency
        self.onConfirm = onConfirm
        _amount = State(initialValue: AmountInput.prefilled(minor: item.amountMinor, currency: currency))
    }

    private var income: Bool { item.kind == .ingreso }
    private var canSave: Bool { amount.money.minor > 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
                Spacer()
                Text(income ? "Marcar recibido" : "Marcar pagado").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Spacer()
                CircleIconButton(systemImage: "checkmark", label: "Guardar", filled: true) { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)

            ScrollView {
                VStack(spacing: Spacing.s5) {
                    Text(item.name)
                        .appFont(.titulo2)
                        .foregroundStyle(Palette.texto1)
                        .multilineTextAlignment(.center)
                    EditableAmountField(input: amount, editing: editing) { editing = true }
                    if amount.money.minor != item.amountMinor {
                        Text("Planeado: \(Money(minor: item.amountMinor, currency: currency).formatted())")
                            .appFont(.cuerpo2)
                            .foregroundStyle(Palette.texto2)
                    }
                    Text(income ? "Se registra hoy lo que te llegó y pasa al siguiente pago." : "Se registra hoy lo que pagaste y pasa al siguiente cobro.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                        .multilineTextAlignment(.center)
                    Button(income ? "Marcar recibido" : "Marcar pagado") { save() }
                        .buttonStyle(.primary)
                        .disabled(!canSave)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            if editing {
                NumericKeypad(input: $amount)
                    .padding(.horizontal, Spacing.margen)
                    .padding(.bottom, Spacing.s2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: editing)
        .background(Palette.superficie2.ignoresSafeArea())
    }

    private func save() {
        guard canSave else { return }
        onConfirm(amount.money.minor)
        dismiss()
    }
}
