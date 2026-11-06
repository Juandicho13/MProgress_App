import SwiftUI
import SwiftData

/// ¿Con qué pagaste? (pantalla 34): tarjeta, cuenta o efectivo, y la forma de pago de la tarjeta.
struct PayWithSheet: View {
    @Binding var productId: UUID?
    @Binding var method: PayMethod?
    var kind: EntryKind = .gasto

    var body: some View {
        WalletQuery { wallet in
            PayWithContent(wallet: wallet, productId: $productId, method: $method, kind: kind)
        }
    }
}

private struct PayWithContent: View {
    let wallet: WalletSnapshot
    @Binding var productId: UUID?
    @Binding var method: PayMethod?
    let kind: EntryKind

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var tab: WalletMath.PayTab = .tarjeta

    private var items: [Product] { wallet.products.filter { tab.kinds.contains($0.kind) } }
    private var selected: Product? { wallet.products.first { $0.id == productId } }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(kind == .ingreso ? "¿A dónde llegó?" : "¿Con qué pagaste?")
                .appFont(.titulo2)
                .foregroundStyle(Palette.texto1)
                .padding(.top, Spacing.s6)
            SegmentedPill(options: WalletMath.PayTab.allCases.map { (value: $0, title: $0.title) }, selection: $tab)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    if items.isEmpty {
                        emptyTab
                    } else {
                        Card(padding: Spacing.s3) {
                            VStack(spacing: Spacing.s2) {
                                ForEach(items) { product in
                                    Button { pick(product) } label: {
                                        ListRow(tile: IconTile(content: .symbol(InstitutionStyle.symbol(product.kind))),
                                                title: product.last4.map { "\(product.name) ·· \($0)" } ?? product.name,
                                                subtitle: subtitle(product)) {
                                            if product.id == productId {
                                                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.brasaTinta)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(product.id == productId ? [.isSelected] : [])
                                }
                            }
                        }
                    }
                    if let selected, selected.kind == .credito || selected.kind == .debito {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            Text("Forma de pago").appFont(.leyenda).foregroundStyle(Palette.texto2)
                            SegmentedPill(options: PayMethod.allCases.map { (value: Optional($0), title: $0.title) }, selection: $method)
                        }
                    }
                    if productId != nil {
                        Button("Quitar") {
                            productId = nil
                            method = nil
                        }
                        .appFont(.etiqueta)
                        .foregroundStyle(Palette.texto2)
                        .frame(minHeight: Size.toqueMinimo)
                    }
                }
            }
            Button("Listo") { dismiss() }.buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s2)
        .background(Palette.superficie2.ignoresSafeArea())
        .onAppear {
            if let selected { tab = WalletMath.PayTab.of(selected.kind) }
        }
    }

    @ViewBuilder
    private var emptyTab: some View {
        switch tab {
        case .efectivo:
            Card {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("Aún no tienes billetera de efectivo.").appFont(.cuerpo).foregroundStyle(Palette.texto2)
                    Button("Usar efectivo") {
                        if let space = wallet.space, let cash = try? MoneyStore(context: context).cash(spaceId: space.id) {
                            pick(cash)
                        }
                    }
                    .buttonStyle(.secondary)
                }
            }
        default:
            Card {
                Text("Agrega tus bancos y tarjetas en la pestaña Dinero para elegirlos aquí.")
                    .appFont(.cuerpo)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }

    private func subtitle(_ product: Product) -> String {
        let bank = wallet.institution(of: product)?.name ?? ""
        switch product.kind {
        case .debito, .credito: return product.inWallet ? "\(bank) · Apple Pay" : bank
        default: return bank
        }
    }

    private func pick(_ product: Product) {
        productId = product.id
        let isCard = product.kind == .credito || product.kind == .debito
        if isCard {
            if method == nil { method = product.inWallet ? .applePay : .fisica }
        } else {
            method = nil
        }
    }
}
