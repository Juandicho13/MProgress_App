import SwiftUI
import SwiftData

/// Transferir entre productos o pagar una tarjeta (F06-05). No cuenta como gasto ni como ingreso.
struct TransferView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoCenter.self) private var undo

    let wallet: WalletSnapshot
    @State private var fromId: UUID?
    @State private var toId: UUID?
    @State private var amount: AmountInput
    @State private var date = Date.now
    @State private var errorText: String?

    init(wallet: WalletSnapshot, from: UUID? = nil, to: UUID? = nil) {
        self.wallet = wallet
        let options = wallet.products.filter { $0.kind != .debito }
        _fromId = State(initialValue: from ?? options.first { $0.kind == .cuenta }?.id ?? options.first?.id)
        _toId = State(initialValue: to ?? options.first { $0.kind == .credito }?.id ?? options.dropFirst().first?.id)
        _amount = State(initialValue: AmountInput(currency: wallet.currency))
    }

    private var options: [Product] { wallet.products.filter { $0.kind != .debito } }
    private var to: Product? { options.first { $0.id == toId } }
    private var canSave: Bool { fromId != nil && toId != nil && fromId != toId && amount.money.minor > 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
                Spacer()
                Text(to?.kind == .credito ? "Pagar tarjeta" : "Transferir").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Spacer()
                CircleIconButton(systemImage: "checkmark", label: "Guardar", filled: true) { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)

            ScrollView {
                VStack(spacing: Spacing.s5) {
                    AmountDisplay(input: amount)
                    Card(padding: Spacing.s2) {
                        VStack(spacing: 0) {
                            productPicker("Desde", selection: $fromId)
                            Divider().overlay(Palette.linea)
                            productPicker("Hacia", selection: $toId)
                            Divider().overlay(Palette.linea)
                            DatePicker(selection: $date, displayedComponents: .date) {
                                Text("Fecha").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                            }
                            .tint(Palette.brasa)
                            .padding(.horizontal, Spacing.s2)
                            .frame(minHeight: 56)
                        }
                    }
                    if fromId != nil && fromId == toId {
                        Text("Elige dos productos distintos.").appFont(.cuerpo2).foregroundStyle(Palette.peligro)
                    }
                    Text("Mover plata entre tus productos no cuenta como gasto ni como ingreso.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            NumericKeypad(input: $amount)
                .padding(.horizontal, Spacing.margen)
                .padding(.bottom, Spacing.s2)
        }
        .background(Palette.superficie2.ignoresSafeArea())
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func productPicker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(selection: selection) {
            ForEach(options) { product in
                Text(label(product)).tag(UUID?.some(product.id))
            }
        } label: {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
        }
        .tint(Palette.texto2)
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
    }

    private func label(_ product: Product) -> String {
        let bank = wallet.institution(of: product)?.name
        let name = product.last4.map { "\(product.name) ·· \($0)" } ?? product.name
        return [name, bank].compactMap { $0 }.joined(separator: " · ")
    }

    private func save() {
        guard let from = options.first(where: { $0.id == fromId }), let to, let space = wallet.space else { return }
        let store = MoneyStore(context: context)
        do {
            let transfer = try store.transfer(spaceId: space.id, from: from, to: to, amountMinor: amount.money.minor, on: date)
            dismiss()
            undo.show(to.kind == .credito ? "Pagaste \(to.name)" : "Moviste plata a \(to.name)") {
                transfer.deletedAt = .now
                transfer.touch()
                try? context.save()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
