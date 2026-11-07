import SwiftUI
import SwiftData

/// Puntos y millas dentro de Mi dinero: saldo, valor aproximado y vencimiento.
struct RewardsSection: View {
    let wallet: WalletSnapshot
    var hideBalances = false

    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<RewardProgram> { $0.deletedAt == nil }, sort: \RewardProgram.createdAt) private var allRewards: [RewardProgram]
    @State private var editing: RewardProgram?
    @State private var adding = false

    private var rewards: [RewardProgram] { allRewards.filter { $0.spaceId == wallet.space?.id } }

    var body: some View {
        let rewards = self.rewards
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack {
                SectionLabel(text: "Puntos y millas")
                Spacer()
                Button("+ Agregar") { adding = true }
                    .appFont(.etiqueta)
                    .foregroundStyle(Palette.brasaTinta)
                    .frame(minHeight: Size.toqueMinimo)
            }
            if rewards.isEmpty {
                Button { adding = true } label: {
                    Card {
                        ListRow(tile: IconTile(content: .symbol("star.circle"), tint: Palette.oroVelo, foreground: Palette.oro),
                                title: "Agrega tus puntos", subtitle: "Puntos Colombia, LifeMiles y más") {
                            Image(systemName: "plus").foregroundStyle(Palette.texto2)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Card(padding: Spacing.s3) {
                    VStack(spacing: Spacing.s2) {
                        ForEach(rewards) { reward in
                            Button { editing = reward } label: { row(reward) }.buttonStyle(.plain)
                        }
                        let total = RewardMath.totalValueMinor(rewards.map(\.record), currency: wallet.currency)
                        if total > 0 && !hideBalances {
                            Divider().overlay(Palette.linea)
                            HStack {
                                Text("Valen aprox.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                                Spacer()
                                Text(Money(minor: total, currency: wallet.currency).formatted()).appFont(.cifraPequena).foregroundStyle(Palette.oro)
                            }
                        }
                    }
                }
            }
        }
        // Siempre a pantalla completa: sin tamaño explícito la hoja podía abrir como una franja con solo el título.
        .sheet(isPresented: $adding) {
            RewardFormView(reward: nil, wallet: wallet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editing) { reward in
            RewardFormView(reward: reward, wallet: wallet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func row(_ reward: RewardProgram) -> some View {
        let record = reward.record
        // La tarjeta que acumula aquí (desde su ficha) o la que se eligió en el programa.
        let earning = wallet.products.first { $0.rewardProgramId == reward.id && $0.pointsPerThousand != nil }
        let card = earning ?? wallet.products.first { $0.id == reward.productId }
        var subtitle = [reward.kind.title, card.map { c in c.last4.map { "\(c.name) ·· \($0)" } ?? c.name }].compactMap { $0 }.joined(separator: " · ")
        if let rate = earning?.pointsPerThousand {
            subtitle += " · " + RewardMath.rateText(pointsPerThousand: rate, kind: reward.kind, currency: wallet.currency)
        }
        if let expiry = RewardMath.expiryText(record, now: .now, calendar: calendar) { subtitle += " · \(expiry)" }
        let value = RewardMath.estimatedValueMinor(record, currency: wallet.currency)
        return ListRow(tile: InstitutionStyle.tile(name: reward.name, hex: reward.colorHex), title: reward.name, subtitle: subtitle) {
            VStack(alignment: .trailing, spacing: 2) {
                HideableAmount(text: RewardMath.balanceText(record), hidden: hideBalances)
                    .appFont(.cifraPequena)
                    .foregroundStyle(Palette.texto1)
                if let value, !hideBalances {
                    Text("≈ \(Money(minor: value, currency: wallet.currency).formatted())").appFont(.leyenda).foregroundStyle(Palette.oro)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para actualizar el saldo")
    }
}

/// Agregar o actualizar un programa de puntos o millas.
struct RewardFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let reward: RewardProgram?
    let wallet: WalletSnapshot

    @State private var name: String
    @State private var kind: RewardKind
    @State private var balanceText: String
    @State private var valueText: String
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var productId: UUID?
    @State private var colorHex: String?
    @State private var confirmsDelete = false
    @State private var errorText: String?

    init(reward: RewardProgram?, wallet: WalletSnapshot) {
        self.reward = reward
        self.wallet = wallet
        _name = State(initialValue: reward?.name ?? "")
        _kind = State(initialValue: reward?.kind ?? .puntos)
        _balanceText = State(initialValue: reward.map { Money.groupThousands($0.balance) } ?? "")
        _valueText = State(initialValue: reward?.valuePerPoint.map { "\($0)".replacingOccurrences(of: ".", with: ",") } ?? "")
        _hasExpiry = State(initialValue: reward?.expiresAt != nil)
        _expiresAt = State(initialValue: reward?.expiresAt ?? Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now)
        _productId = State(initialValue: reward?.productId)
        _colorHex = State(initialValue: reward?.colorHex)
    }

    private var balance: Int64 { Int64(balanceText.filter(\.isNumber)) ?? 0 }
    private var value: Decimal? { Decimal(string: valueText.replacingOccurrences(of: ",", with: ".")) }
    private var cards: [Product] { wallet.products.filter { $0.kind == .credito || $0.kind == .debito } }

    var body: some View {
        NavigationStack {
            Form {
                if reward == nil {
                    Section {
                        FlowChips(items: RewardMath.suggestions.map(\.name)) { pick in
                            guard let suggestion = RewardMath.suggestions.first(where: { $0.name == pick }) else { return }
                            name = pick == "Otro" ? "" : pick
                            kind = suggestion.kind
                            colorHex = suggestion.hex
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section {
                    TextField("Nombre del programa", text: $name)
                    Picker("Tipo", selection: $kind) {
                        ForEach(RewardKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Saldo de \(kind.unit)", text: $balanceText)
                        .keyboardType(.numberPad)
                        .onChange(of: balanceText) { _, text in
                            let digits = String(text.filter(\.isNumber).prefix(12))
                            let formatted = digits.isEmpty ? "" : Money.groupThousands(Int64(digits) ?? 0)
                            if formatted != text { balanceText = formatted }
                        }
                }
                Section {
                    TextField("¿Cuánto vale cada uno? (\(wallet.currency.symbol))", text: $valueText)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("Opcional. Con ese valor te mostramos cuánta plata son tus \(kind.unit). Lo encuentras en la app del programa.")
                }
                Section {
                    Toggle("Tienen vencimiento", isOn: $hasExpiry).tint(Palette.brasa)
                    if hasExpiry {
                        DatePicker("Vencen", selection: $expiresAt, displayedComponents: .date).tint(Palette.brasa)
                    }
                    if !cards.isEmpty {
                        Picker("Los acumulo con", selection: $productId) {
                            Text("Ninguna").tag(UUID?.none)
                            ForEach(cards) { card in
                                Text(card.last4.map { "\(card.name) ·· \($0)" } ?? card.name).tag(UUID?.some(card.id))
                            }
                        }
                    }
                }
                if reward != nil {
                    Button("Borrar", role: .destructive) { confirmsDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle(reward == nil ? "Puntos o millas" : "Actualizar saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("¿Borrar \(name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let reward { try? MoneyStore(context: context).softDelete(reward) }
                    dismiss()
                }
            }
            .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func save() {
        guard let space = wallet.space else { return }
        do {
            try MoneyStore(context: context).saveReward(reward, spaceId: space.id, name: name, kind: kind, balance: balance,
                                                        valuePerPoint: value, expiresAt: hasExpiry ? expiresAt : nil,
                                                        productId: productId, colorHex: colorHex ?? InstitutionStyle.palette[2])
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
