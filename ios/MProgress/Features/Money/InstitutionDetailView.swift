import SwiftUI
import SwiftData

/// Detalle de banco (pantalla 32): total, cuentas, cajitas con rendimiento y tarjetas.
struct InstitutionDetailView: View {
    let institutionId: UUID

    var body: some View {
        WalletQuery { wallet in
            if let institution = wallet.institutions.first(where: { $0.id == institutionId }) {
                InstitutionDetailContent(institution: institution, wallet: wallet)
            } else {
                Text("Este banco ya no existe.").appFont(.cuerpo).foregroundStyle(Palette.texto2)
            }
        }
        .background(Palette.fondo.ignoresSafeArea())
    }
}

private struct InstitutionDetailContent: View {
    let institution: Institution
    let wallet: WalletSnapshot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo
    @AppStorage("dinero.ocultarSaldos") private var hideBalances = false

    @State private var adding: ProductKind?
    @State private var editing: Product?
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmsDelete = false

    private var products: [Product] { wallet.products(of: institution) }
    /// El grupo Efectivo: solo tiene efectivos (o se llama Efectivo y aún está vacío).
    private var isCashGroup: Bool {
        products.isEmpty ? institution.name == "Efectivo" : products.allSatisfy { $0.kind == .efectivo }
    }
    private var currency: Currency { wallet.currency }

    var body: some View {
        let totals = wallet.totals(institution)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                totalCard(totals)
                if isCashGroup {
                    // Varios efectivos con nombre propio, cada uno con su saldo, agrupados bajo Efectivo.
                    section("Efectivo", kinds: [.efectivo])
                    Button("+ Efectivo") { adding = .efectivo }.buttonStyle(.secondary)
                    Text("Billetera, casa, alcancía: cada uno lleva su saldo. Para mover plata entre ellos usa Transferir en Mi dinero.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                } else {
                    section("Cuenta", kinds: [.cuenta, .efectivo])
                    section("Cajitas", kinds: [.bolsillo])
                    section("Tarjetas", kinds: [.credito, .debito])
                    if products.isEmpty {
                        Text("Agrega la cuenta, cajitas o tarjetas que tienes en \(institution.name).")
                            .appFont(.cuerpo)
                            .foregroundStyle(Palette.texto2)
                    }
                    HStack(spacing: Spacing.s3) {
                        Button("+ Cajita") { adding = .bolsillo }.buttonStyle(.secondary)
                        Button("+ Tarjeta") { adding = .credito }.buttonStyle(.secondary)
                    }
                    Button("+ Cuenta") { adding = .cuenta }.buttonStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(institution.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Cambiar nombre", systemImage: "pencil") {
                        newName = institution.name
                        renaming = true
                    }
                    Button(institution.hidden ? "Mostrar saldo" : "Ocultar saldo", systemImage: institution.hidden ? "eye" : "eye.slash") {
                        institution.hidden.toggle()
                        institution.touch()
                        try? context.save()
                    }
                    Divider()
                    Button("Borrar banco", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .sheet(item: $adding) { kind in
            if let space = wallet.space {
                ProductFormView(spaceId: space.id, institution: institution, kind: kind, wallet: wallet)
            }
        }
        .sheet(item: $editing) { product in
            if let space = wallet.space {
                ProductFormView(spaceId: space.id, institution: institution, editing: product, wallet: wallet)
            }
        }
        .alert("Nombre del banco", isPresented: $renaming) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                let clean = newName.trimmingCharacters(in: .whitespaces)
                guard !clean.isEmpty else { return }
                institution.name = clean
                institution.touch()
                try? context.save()
            }
        }
        .confirmationDialog("¿Borrar \(institution.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { delete() }
        } message: {
            Text("Se borran sus cuentas, cajitas y tarjetas. Tus movimientos se quedan.")
        }
    }

    private func totalCard(_ totals: InstitutionTotals) -> some View {
        let tint = InstitutionStyle.color(institution.colorHex)
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Total en \(institution.name)").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
            HideableAmount(text: Money(minor: totals.netMinor, currency: currency).formatted(), hidden: hideBalances || institution.hidden)
                .appFont(.cifraGrande)
                .foregroundStyle(Palette.texto1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if totals.monthlyYieldMinor > 0 && !(hideBalances || institution.hidden) {
                Text("Rinde aprox. \(Money(minor: totals.monthlyYieldMinor, currency: currency).formatted()) al mes")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.exito)
            }
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.35), Palette.superficie1], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func section(_ title: String, kinds: Set<ProductKind>) -> some View {
        let items = products.filter { kinds.contains($0.kind) }
        if !items.isEmpty {
            SectionLabel(text: title)
            Card(padding: Spacing.s3) {
                VStack(spacing: Spacing.s2) {
                    ForEach(items) { product in
                        Button { editing = product } label: { row(product) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ product: Product) -> some View {
        let balance = wallet.balance(product)
        var extra: String?
        var extraColor = Palette.exito
        switch product.kind {
        case .bolsillo:
            let yield = MoneyCalculator.monthlyYield(balanceMinor: balance, rateEA: product.rateEA)
            if yield > 0 { extra = "+ \(Money(minor: yield, currency: currency).formatted())" }
        case .credito:
            if let limit = product.creditLimitMinor {
                extra = "disponible \(Money(minor: max(0, limit - balance), currency: currency).formatted())"
                extraColor = Palette.texto2
            }
        default:
            break
        }
        return ProductRow(product: product, subtitle: subtitle(product), balance: product.kind == .debito ? nil : balance,
                          currency: currency, hideBalance: hideBalances || institution.hidden, extra: extra, extraColor: extraColor)
            .accessibilityHint("Toca para editar")
    }

    private func subtitle(_ product: Product) -> String {
        switch product.kind {
        case .cuenta: return "Disponible para gastar"
        case .efectivo: return "Efectivo"
        case .bolsillo:
            if let rate = product.rateEA { return "Rentabilidad \(rate.formatted(.number.precision(.fractionLength(0...2))))% E.A." }
            return "Sin rentabilidad"
        case .debito:
            let parent = wallet.products.first { $0.id == product.parentProductId }?.name
            let pay = product.inWallet ? "En Apple Pay" : "Física"
            return [pay, parent.map { "de \($0)" }].compactMap { $0 }.joined(separator: " · ")
        case .credito:
            var parts: [String] = []
            if let limit = product.creditLimitMinor { parts.append("Cupo \(Money(minor: limit, currency: currency).formatted())") }
            if let cut = product.cutDay { parts.append("corte día \(cut)") }
            if let due = product.dueDay {
                parts.append("pago \(DueText.describe(WalletMath.nextDueDate(day: due, now: .now, calendar: calendar), now: .now, calendar: calendar).lowercased())")
            }
            return parts.isEmpty ? "Tarjeta de crédito" : parts.joined(separator: " · ")
        }
    }

    private func delete() {
        let store = MoneyStore(context: context)
        let name = institution.name
        do {
            try store.softDelete(institution)
            dismiss()
            undo.show("Borraste \(name)")
        } catch {
            undo.show("No se pudo borrar \(name)")
        }
    }
}

extension ProductKind: Identifiable {
    var id: String { rawValue }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let store = MoneyStore(context: container.mainContext)
    let nu = try! store.addInstitution(spaceId: space.id, name: "Nu", colorHex: "A68CFF")
    try! store.addProduct(spaceId: space.id, institutionId: nu.id, kind: .cuenta, name: "Cuenta Nu", balanceMinor: 60_000_000)
    try! store.addProduct(spaceId: space.id, institutionId: nu.id, kind: .bolsillo, name: "Emergencias", balanceMinor: 150_000_000, rateEA: 8.25)
    try! store.addProduct(spaceId: space.id, institutionId: nu.id, kind: .credito, name: "Crédito Nu", balanceMinor: 100_000_000, last4: "2210")
    return NavigationStack { InstitutionDetailView(institutionId: nu.id) }
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}
