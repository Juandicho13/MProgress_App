import SwiftUI
import SwiftData

/// Agregar a un banco (pantalla 33): cuenta, débito, crédito, bolsillo o cajita; en el grupo Efectivo, un efectivo con
/// nombre propio. También edita. Las tarjetas pueden acumular puntos o millas en un programa.
/// Solo guarda los últimos 4 dígitos de las tarjetas, nunca el número completo.
struct ProductFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<RewardProgram> { $0.deletedAt == nil }, sort: \RewardProgram.createdAt) private var allRewards: [RewardProgram]

    let spaceId: UUID
    let institution: Institution
    let wallet: WalletSnapshot
    private let editing: Product?

    @State private var draft: MoneyStore.ProductDraft
    @State private var balance: Int64
    @State private var limit: Int64
    @State private var last4: String
    @State private var rateText: String
    @State private var pointsText: String
    @State private var confirmsDelete = false
    @State private var errorText: String?

    private let startBalance: Int64

    init(spaceId: UUID, institution: Institution, kind: ProductKind, wallet: WalletSnapshot) {
        self.spaceId = spaceId
        self.institution = institution
        self.wallet = wallet
        self.editing = nil
        var draft = MoneyStore.ProductDraft()
        draft.kind = kind
        draft.inWallet = kind == .credito || kind == .debito
        draft.parentProductId = wallet.products(of: institution).first { $0.kind == .cuenta }?.id
        if kind == .efectivo {
            draft.name = WalletMath.nextCashName(existing: wallet.products.filter { $0.kind == .efectivo }.map(\.name))
        }
        _draft = State(initialValue: draft)
        _balance = State(initialValue: 0)
        _limit = State(initialValue: 0)
        _last4 = State(initialValue: "")
        _rateText = State(initialValue: "")
        _pointsText = State(initialValue: "")
        startBalance = 0
    }

    init(spaceId: UUID, institution: Institution, editing product: Product, wallet: WalletSnapshot) {
        self.spaceId = spaceId
        self.institution = institution
        self.wallet = wallet
        self.editing = product
        let current = wallet.balance(product)
        var draft = MoneyStore.ProductDraft()
        draft.kind = product.kind
        draft.name = product.name
        draft.cutDay = product.cutDay
        draft.dueDay = product.dueDay
        draft.remindPayment = product.dueDay != nil
        draft.parentProductId = product.parentProductId
        draft.inWallet = product.inWallet
        draft.hidden = product.hidden
        draft.rewardProgramId = product.rewardProgramId
        draft.pointsPerThousand = product.pointsPerThousand
        _draft = State(initialValue: draft)
        _balance = State(initialValue: current)
        _limit = State(initialValue: product.creditLimitMinor ?? 0)
        _last4 = State(initialValue: product.last4 ?? "")
        _rateText = State(initialValue: product.rateEA.map { "\($0)".replacingOccurrences(of: ".", with: ",") } ?? "")
        _pointsText = State(initialValue: product.pointsPerThousand.map { "\($0)".replacingOccurrences(of: ".", with: ",") } ?? "")
        startBalance = current
    }

    private var isCard: Bool { draft.kind == .credito || draft.kind == .debito }
    private var last4Valid: Bool { last4.isEmpty || MoneyStore.cleanLast4(last4) != nil }
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && last4Valid }
    private var accounts: [Product] { wallet.products.filter { $0.kind == .cuenta } }
    private var rewards: [RewardProgram] { allRewards.filter { $0.spaceId == spaceId } }
    private var pointsPerThousand: Decimal? { Decimal(string: pointsText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
                Spacer()
                Text(editing == nil ? "Agregar a \(institution.name)" : "Editar").appFont(.titulo3).foregroundStyle(Palette.texto1).lineLimit(1)
                Spacer()
                CircleIconButton(systemImage: "checkmark", label: "Guardar", filled: true) { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    if editing == nil && draft.kind != .efectivo { kindPicker }
                    field("Nombre") {
                        TextField(placeholder, text: $draft.name)
                            .appFont(.cuerpo)
                            .foregroundStyle(Palette.texto1)
                            .textInputAutocapitalization(.words)
                    }
                    amounts
                    options
                    if isCard { rewardsCard }
                    Text("Solo guardamos los últimos 4 dígitos para reconocer la tarjeta. Nunca el número completo.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                    if editing != nil {
                        Button("Borrar \(kindName.lowercased())") { confirmsDelete = true }.buttonStyle(.destructive)
                    }
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.superficie2.ignoresSafeArea())
        .confirmationDialog("¿Borrar \(draft.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { delete() }
        } message: {
            Text("Los movimientos pagados con esto se quedan, sin producto.")
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: Partes

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            SectionLabel(text: "¿Qué es?")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s2), GridItem(.flexible(), spacing: Spacing.s2)], spacing: Spacing.s2) {
                kindTile(.cuenta, "Cuenta", "Ahorros o corriente")
                kindTile(.debito, "Tarjeta débito", "Ligada a una cuenta")
                kindTile(.credito, "Tarjeta crédito", "Cupo, corte y pago")
                kindTile(.bolsillo, "Bolsillo", "Apartada en tu cuenta")
                kindTile(.cajita, "Cajita", "Ahorro aparte que rinde")
            }
        }
    }

    private func kindTile(_ kind: ProductKind, _ title: String, _ subtitle: String) -> some View {
        let selected = draft.kind == kind
        return Button {
            draft.kind = kind
            draft.inWallet = kind == .credito || kind == .debito
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text(subtitle).appFont(.leyenda).foregroundStyle(Palette.texto2)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, Spacing.s3)
            .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(selected ? Palette.brasaVelo : Palette.superficie3))
            .overlay(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).stroke(selected ? Palette.brasa : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var amounts: some View {
        switch draft.kind {
        case .credito:
            HStack(alignment: .top, spacing: Spacing.s3) {
                last4Field
                MoneyField(title: "Cupo", minor: $limit, currency: wallet.currency)
            }
            MoneyField(title: "Deuda de hoy", minor: $balance, currency: wallet.currency)
        case .debito:
            last4Field
        case .bolsillo, .cajita:
            HStack(alignment: .top, spacing: Spacing.s3) {
                MoneyField(title: "Saldo de hoy", minor: $balance, currency: wallet.currency)
                field("Tasa E.A. (%)") {
                    TextField("0", text: $rateText)
                        .keyboardType(.decimalPad)
                        .appFont(.cifraPequena)
                        .foregroundStyle(Palette.texto1)
                }
                .frame(maxWidth: 130)
            }
        case .cuenta, .efectivo:
            MoneyField(title: "Saldo de hoy", minor: $balance, currency: wallet.currency)
        }
    }

    private var last4Field: some View {
        field("Últimos 4") {
            TextField("0000", text: $last4)
                .keyboardType(.numberPad)
                .appFont(.cifraPequena)
                .foregroundStyle(last4Valid ? Palette.texto1 : Palette.peligro)
                .onChange(of: last4) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(4))
                    if digits != value { last4 = digits }
                }
        }
        .accessibilityHint("Solo los últimos 4 dígitos de la tarjeta")
    }

    @ViewBuilder
    private var options: some View {
        if isCard || draft.kind != .efectivo {
            Card(padding: Spacing.s2) {
                VStack(spacing: 0) {
                    if draft.kind == .credito {
                        dayPicker("Día de corte", selection: $draft.cutDay)
                        Divider().overlay(Palette.linea)
                        dayPicker("Día de pago", selection: $draft.dueDay)
                        Divider().overlay(Palette.linea)
                    }
                    if draft.kind == .debito {
                        Picker(selection: $draft.parentProductId) {
                            Text("Ninguna").tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(UUID?.some(account.id))
                            }
                        } label: {
                            Text("Cuenta que paga").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                        }
                        .tint(Palette.texto2)
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                        Divider().overlay(Palette.linea)
                    }
                    if isCard {
                        toggle("Está en Apple Pay", isOn: $draft.inWallet)
                        Divider().overlay(Palette.linea)
                    }
                    if draft.kind == .credito {
                        toggle("Recordar el pago de la tarjeta", isOn: $draft.remindPayment)
                        Divider().overlay(Palette.linea)
                    }
                    toggle("Ocultar saldo en Inicio", isOn: $draft.hidden)
                }
            }
        }
    }

    /// Puntos o millas que da la tarjeta: en qué programa y cuántos por cada 1.000 gastados.
    @ViewBuilder
    private var rewardsCard: some View {
        SectionLabel(text: "Puntos o millas")
        if rewards.isEmpty {
            Text("Agrega tu programa en Dinero › Puntos y millas para que esta tarjeta sume puntos sola con cada gasto.")
                .appFont(.leyenda)
                .foregroundStyle(Palette.texto2)
        } else {
            Card(padding: Spacing.s2) {
                VStack(spacing: 0) {
                    Picker(selection: $draft.rewardProgramId) {
                        Text("Ninguno").tag(UUID?.none)
                        ForEach(rewards) { reward in
                            Text(reward.name).tag(UUID?.some(reward.id))
                        }
                    } label: {
                        Text("Acumula en").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    }
                    .tint(Palette.texto2)
                    .padding(.horizontal, Spacing.s2)
                    .frame(minHeight: 56)
                    if draft.rewardProgramId != nil {
                        Divider().overlay(Palette.linea)
                        HStack {
                            Text("Por cada \(Money(units: 1000, currency: wallet.currency).formatted())").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                            Spacer()
                            TextField("0", text: $pointsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .appFont(.cifraPequena)
                                .foregroundStyle(Palette.texto1)
                                .frame(maxWidth: 90)
                            Text(selectedRewardUnit).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                        }
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                    }
                }
            }
            if draft.rewardProgramId != nil {
                Text("Cada gasto con esta tarjeta suma sus puntos al programa y al borrarlo se restan. Lo encuentras en el reglamento de tu tarjeta.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }

    private var selectedRewardUnit: String {
        rewards.first { $0.id == draft.rewardProgramId }?.kind.unit ?? "puntos"
    }

    private func dayPicker(_ title: String, selection: Binding<Int?>) -> some View {
        Picker(selection: selection) {
            Text("Sin definir").tag(Int?.none)
            ForEach(1...31, id: \.self) { day in Text("\(day)").tag(Int?.some(day)) }
        } label: {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
        }
        .tint(Palette.texto2)
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
        }
        .tint(Palette.brasa)
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text(title).appFont(.leyenda).foregroundStyle(Palette.texto2)
            content()
                .padding(.horizontal, Spacing.s4)
                .frame(minHeight: Size.toqueMinimo)
                .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
        }
    }

    private var placeholder: String {
        switch draft.kind {
        case .cuenta: "Ahorros"
        case .debito: "Débito"
        case .credito: "Crédito Oro"
        case .bolsillo: "Arriendo, Mercado"
        case .cajita: "Emergencias, Viaje"
        case .efectivo: "Billetera, Casa, Alcancía"
        }
    }

    private var kindName: String {
        switch draft.kind {
        case .cuenta: "Cuenta"
        case .debito, .credito: "Tarjeta"
        case .bolsillo: "Bolsillo"
        case .cajita: "Cajita"
        case .efectivo: "Efectivo"
        }
    }

    // MARK: Guardar

    private func save() {
        var final = draft
        final.balanceMinor = draft.kind == .debito ? 0 : balance
        final.last4 = last4.isEmpty ? nil : last4
        final.creditLimitMinor = limit > 0 ? limit : nil
        final.rateEA = Decimal(string: rateText.replacingOccurrences(of: ",", with: "."))
        final.pointsPerThousand = pointsPerThousand
        let store = MoneyStore(context: context)
        do {
            if let editing {
                try store.update(editing, draft: final, currentBalanceMinor: startBalance)
            } else {
                try store.addProduct(spaceId: spaceId, institutionId: institution.id, draft: final)
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        guard let editing else { return }
        let store = MoneyStore(context: context)
        let name = editing.name
        do {
            try store.softDelete(editing)
            dismiss()
            undo.show("Borraste \(name)") {
                editing.deletedAt = nil
                editing.touch()
                try? context.save()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
