import SwiftUI
import SwiftData

/// Datos de Mi dinero ya calculados, para no repetir consultas en cada pantalla.
@MainActor
struct WalletSnapshot {
    let space: Space?
    let institutions: [Institution]
    let products: [Product]
    let entries: [Entry]
    let transfers: [Transfer]

    var currency: Currency { space?.currency ?? .cop }
    var productRecords: [ProductRecord] { products.map(\.record) }
    var entryRecords: [EntryRecord] { entries.map(\.record) }
    var transferRecords: [TransferRecord] { transfers.map(\.record) }

    func products(of institution: Institution) -> [Product] {
        products.filter { $0.institutionId == institution.id }
    }

    func balance(_ product: Product) -> Int64 {
        MoneyCalculator.currentBalance(of: product.record, products: productRecords, entries: entryRecords, transfers: transferRecords)
    }

    func totals(_ institution: Institution) -> InstitutionTotals {
        WalletMath.totals(of: products(of: institution).map(\.record), allProducts: productRecords, entries: entryRecords, transfers: transferRecords)
    }

    func institution(of product: Product) -> Institution? {
        institutions.first { $0.id == product.institutionId }
    }
}

/// Lee de SwiftData lo que necesita Mi dinero y arma el WalletSnapshot del espacio personal.
struct WalletQuery<Content: View>: View {
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Institution> { $0.deletedAt == nil }, sort: \Institution.createdAt) private var institutions: [Institution]
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }, sort: \Product.createdAt) private var products: [Product]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }) private var entries: [Entry]
    @Query(filter: #Predicate<Transfer> { $0.deletedAt == nil }) private var transfers: [Transfer]

    @ViewBuilder let content: (WalletSnapshot) -> Content

    var body: some View {
        let space = spaces.first { $0.kindRaw == "personal" } ?? spaces.first
        let id = space?.id
        content(WalletSnapshot(
            space: space,
            institutions: institutions.filter { $0.spaceId == id },
            products: products.filter { $0.spaceId == id },
            entries: entries.filter { $0.spaceId == id },
            transfers: transfers.filter { $0.spaceId == id }
        ))
    }
}

/// Mi dinero (pantalla 31) y Mi dinero vacío (pantalla 40).
struct MoneyView: View {
    var body: some View {
        NavigationStack {
            WalletQuery { wallet in
                MoneyContent(wallet: wallet)
            }
            .background(Palette.fondo.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                InstitutionDetailView(institutionId: id)
            }
        }
    }
}

private struct MoneyContent: View {
    let wallet: WalletSnapshot
    @Environment(\.calendar) private var calendar
    @AppStorage("dinero.ocultarSaldos") private var hideBalances = false
    @State private var addingBank = false
    @State private var transferring = false

    private var currency: Currency { wallet.currency }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                HStack {
                    Text("Mi dinero").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if !wallet.institutions.isEmpty {
                        CircleIconButton(systemImage: hideBalances ? "eye.slash" : "eye", label: hideBalances ? "Mostrar saldos" : "Ocultar saldos") {
                            hideBalances.toggle()
                        }
                    }
                }
                if wallet.institutions.isEmpty {
                    emptyState
                } else {
                    netWorthCard
                    HStack(spacing: Spacing.s3) {
                        Button("Transferir") { transferring = true }.buttonStyle(.secondary)
                            .disabled(WalletMath.transferable(wallet.productRecords).count < 2)
                        Button("+ Banco") { addingBank = true }.buttonStyle(.primary)
                    }
                    SectionLabel(text: "Bancos y billeteras")
                    banksCard
                    RewardsSection(wallet: wallet, hideBalances: hideBalances)
                    mostUsedSection
                }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $addingBank) {
            if let space = wallet.space { AddInstitutionView(spaceId: space.id) }
        }
        .sheet(isPresented: $transferring) {
            TransferView(wallet: wallet)
        }
    }

    private var netWorthCard: some View {
        let worth = MoneyCalculator.netWorth(products: wallet.productRecords, entries: wallet.entryRecords, transfers: wallet.transferRecords)
        let yield = wallet.institutions.reduce(Int64(0)) { $0 + wallet.totals($1).monthlyYieldMinor }
        return Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Patrimonio neto").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                HideableAmount(text: money(worth.net), hidden: hideBalances)
                    .appFont(.cifraGrande)
                    .foregroundStyle(worth.net < 0 ? Palette.peligro : Palette.texto1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: Spacing.s3) {
                    dot(Palette.hielo, "Tienes", worth.have)
                    dot(Palette.brasa, "Debes", worth.owe)
                }
                if yield > 0 && !hideBalances {
                    Text("Tus cajitas rentan \(money(yield)) este mes").appFont(.leyenda).foregroundStyle(Palette.exito)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func dot(_ color: Color, _ title: String, _ minor: Int64) -> some View {
        HStack(spacing: Spacing.s1) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(title) \(hideBalances ? "••••" : money(minor))").appFont(.leyenda).foregroundStyle(Palette.texto2)
        }
    }

    private var banksCard: some View {
        Card(padding: Spacing.s3) {
            VStack(spacing: Spacing.s2) {
                ForEach(wallet.institutions) { institution in
                    NavigationLink(value: institution.id) {
                        bankRow(institution)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bankRow(_ institution: Institution) -> some View {
        let totals = wallet.totals(institution)
        let kinds = wallet.products(of: institution).map(\.kind)
        return ListRow(tile: InstitutionStyle.tile(name: institution.name, hex: institution.colorHex),
                       title: institution.name, subtitle: WalletMath.subtitle(kinds: kinds)) {
            VStack(alignment: .trailing, spacing: 2) {
                HideableAmount(text: money(totals.haveMinor), hidden: hideBalances || institution.hidden)
                    .appFont(.cifraPequena)
                    .foregroundStyle(Palette.texto1)
                if !(hideBalances || institution.hidden) {
                    if totals.oweMinor > 0 {
                        Text("debes \(money(totals.oweMinor))").appFont(.leyenda).foregroundStyle(Palette.brasaTinta)
                    } else if totals.monthlyYieldMinor > 0 {
                        Text("+ \(money(totals.monthlyYieldMinor)) rendimiento").appFont(.leyenda).foregroundStyle(Palette.exito)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para ver sus cuentas y tarjetas")
    }

    @ViewBuilder
    private var mostUsedSection: some View {
        let methods = Dictionary(uniqueKeysWithValues: wallet.entries.compactMap { entry in
            entry.methodRaw.flatMap(PayMethod.init(rawValue:)).map { (entry.id, $0) }
        })
        if let used = WalletMath.mostUsed(entries: wallet.entryRecords, methods: methods, now: .now, calendar: calendar),
           let product = wallet.products.first(where: { $0.id == used.productId }) {
            SectionLabel(text: "Más usada este mes")
            Card(padding: Spacing.s3) {
                ProductRow(product: product,
                           subtitle: "\(used.count) \(used.count == 1 ? "pago" : "pagos")\(used.applePay > 0 ? " · \(used.applePay) con Apple Pay" : "")",
                           balance: nil, currency: currency)
                    .overlay(alignment: .trailing) {
                        Text(money(used.totalMinor)).appFont(.cifraPequena).foregroundStyle(Palette.texto1)
                    }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s5) {
            Spacer(minLength: Spacing.s8)
            HStack(spacing: Spacing.s2) {
                InstitutionStyle.tile(name: "Banco", hex: "F5C451", size: 52)
                InstitutionStyle.tile(name: "Nu", hex: "A68CFF", size: 52)
                InstitutionStyle.tile(name: "Efectivo", hex: "3A3F47", size: 52)
            }
            .accessibilityHidden(true)
            Text("¿De dónde sale tu plata?").appFont(.titulo2).foregroundStyle(Palette.texto1).multilineTextAlignment(.center)
            Text("Agrega tus bancos, tarjetas y bolsillos para saber con qué pagas y cuánto tienes en total.")
                .appFont(.cuerpo)
                .foregroundStyle(Palette.texto2)
                .multilineTextAlignment(.center)
            Button("Agregar banco o billetera") { addingBank = true }.buttonStyle(.primary)
            Spacer(minLength: Spacing.s8)
            Text("Solo los últimos 4 dígitos de cada tarjeta. Nunca te pedimos claves.")
                .appFont(.leyenda)
                .foregroundStyle(Palette.texto2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func money(_ minor: Int64) -> String { Money(minor: minor, currency: currency).formatted() }
}

#Preview("Con bancos") {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let store = MoneyStore(context: container.mainContext)
    let bank = try! store.addInstitution(spaceId: space.id, name: "Bancolombia", colorHex: "FDDA24")
    let nu = try! store.addInstitution(spaceId: space.id, name: "Nu", colorHex: "A68CFF")
    try! store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .cuenta, name: "Ahorros", balanceMinor: 882_000_000)
    try! store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .credito, name: "Crédito Oro", balanceMinor: 322_000_000, last4: "4417")
    try! store.addProduct(spaceId: space.id, institutionId: nu.id, kind: .bolsillo, name: "Emergencias", balanceMinor: 150_000_000, rateEA: 8.25)
    return MoneyView().modelContainer(container).environment(UndoCenter()).preferredColorScheme(.dark)
}

#Preview("Vacío") {
    let container = try! Persistence.makeContainer(inMemory: true)
    _ = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    return MoneyView().modelContainer(container).environment(UndoCenter()).preferredColorScheme(.dark)
}
