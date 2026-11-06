import SwiftUI
import SwiftData

/// Registro automático (pantalla 35): fuentes, últimos detectados con Revisar o Guardado y cómo se lee un SMS.
struct AutoCaptureView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }, sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil }) private var products: [Product]
    @Query(filter: #Predicate<Institution> { $0.deletedAt == nil }) private var institutions: [Institution]

    @State private var reviewing: Entry?
    @State private var guide: Guide?
    @State private var showsBackTap = false
    @AppStorage(AutoSetup.dobleToque.storageKey) private var backTapAt: Double = 0
    @AppStorage(AutoSetup.applePay.storageKey) private var applePayAt: Double = 0
    @AppStorage(AutoSetup.sms.storageKey) private var smsAt: Double = 0
    @State private var sample = "Bancolombia: Compraste $84.300 en EXITO con tu T.Cred *4417. 05/11 13:22"

    enum Guide: String, Identifiable {
        case applePay, sms
        var id: String { rawValue }
    }

    private var detected: [Entry] {
        Array(allEntries.filter { $0.sourceRaw != EntrySource.manual.rawValue && $0.sourceRaw != EntrySource.recibo.rawValue }.prefix(15))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Pagas y queda anotado").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                    Text("Elige cómo quieres que la app se entere de tus pagos.").appFont(.cuerpo).foregroundStyle(Palette.texto2)
                }
                SectionLabel(text: "Fuentes")
                Card(padding: Spacing.s3) {
                    VStack(spacing: Spacing.s2) {
                        sourceRow("Apple Pay", "Atajo de Wallet · comercio, monto y tarjeta", "creditcard.fill", Palette.brasa, source: .applePay) { guide = .applePay }
                        sourceRow("Mensajes del banco", "Atajo de Mensajes lee el SMS y lo envía", "message", Palette.superficie3, source: .sms) { guide = .sms }
                        Button { showsBackTap = true } label: {
                            ListRow(tile: IconTile(content: .symbol("hand.tap")), title: "Doble toque atrás",
                                    subtitle: "Toca dos veces el iPhone y anotas al instante") {
                                status(backTapAt > 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        ListRow(tile: IconTile(content: .symbol("envelope")), title: "Correos de compra", subtitle: "Próximamente") { EmptyView() }
                            .opacity(0.6)
                    }
                }
                if !detected.isEmpty {
                    SectionLabel(text: "Últimos detectados")
                    Card(padding: Spacing.s3) {
                        VStack(spacing: Spacing.s2) {
                            ForEach(detected) { entry in
                                Button { reviewing = entry } label: { detectedRow(entry) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                sampleCard
                Button("Configurar paso a paso") { guide = .applePay }.buttonStyle(.secondary)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Registro automático")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reviewing) { entry in
            AddEntryView(editing: entry)
        }
        .sheet(isPresented: $showsBackTap) { BackTapGuideView() }
        .sheet(item: $guide) { guide in
            ShortcutGuideView(guide: guide)
        }
    }

    private func sourceRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, source: EntrySource, action: @escaping () -> Void) -> some View {
        let marked = source == .applePay ? applePayAt > 0 : smsAt > 0
        let active = marked || allEntries.contains { $0.sourceRaw == source.rawValue }
        return Button(action: action) {
            ListRow(tile: IconTile(content: .symbol(symbol), tint: tint, foreground: tint == Palette.brasa ? Palette.sobreBrasa : Palette.texto1),
                    title: title, subtitle: subtitle) {
                status(active)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Toca para ver cómo configurarlo")
    }

    private func status(_ configured: Bool) -> some View {
        HStack(spacing: 4) {
            if configured { Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold)) }
            Text(configured ? "Configurado" : "Configurar").appFont(.etiqueta)
        }
        .foregroundStyle(configured ? Palette.exito : Palette.brasaTinta)
    }

    private func detectedRow(_ entry: Entry) -> some View {
        let product = products.first { $0.id == entry.productId }
        let bank = product.flatMap { p in institutions.first { $0.id == p.institutionId }?.name }
        let source = EntrySource(rawValue: entry.sourceRaw)?.title ?? ""
        let card = product.map { p in [p.kind == .credito ? "Crédito" : p.kind == .debito ? "Débito" : p.name, p.last4.map { "·· \($0)" }].compactMap { $0 }.joined(separator: " ") }
        return ListRow(tile: IconTile(content: .symbol("creditcard")),
                       title: "\(entry.name) · \(Money(minor: entry.amountMinor, currency: .cop).formatted())",
                       subtitle: [source + (bank.map { " \($0)" } ?? ""), card].compactMap { $0 }.joined(separator: " · ")) {
            Text(entry.needsReview ? "Revisar" : "Guardado").appFont(.etiqueta).foregroundStyle(entry.needsReview ? Palette.oro : Palette.exito)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.needsReview ? "Toca para revisarlo" : "Toca para editarlo")
    }

    private var sampleCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Así se lee un SMS").appFont(.leyenda).foregroundStyle(Palette.texto2)
                TextField("Pega un SMS de tu banco", text: $sample, axis: .vertical)
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto1)
                    .lineLimit(2...5)
                    .padding(Spacing.s3)
                    .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                if let parsed = SmsParser.parse(sample) {
                    Text(highlighted(parsed)).appFont(.cuerpo)
                    Text(parsed.needsReview ? "Quedaría para revisar: falta \(parsed.merchant == nil ? "el comercio" : "la tarjeta")." : "Se guardaría solo.")
                        .appFont(.leyenda)
                        .foregroundStyle(parsed.needsReview ? Palette.oro : Palette.exito)
                } else {
                    Text("Este texto no parece una compra ni un pago.").appFont(.leyenda).foregroundStyle(Palette.texto2)
                }
            }
        }
    }

    /// "Compraste $84.300 en EXITO con tu T.Cred *4417" con el monto, el comercio y la tarjeta resaltados.
    private func highlighted(_ parsed: ParsedCharge) -> AttributedString {
        var text = AttributedString(parsed.kind == .ingreso ? "Recibiste " : "Pagaste ")
        text.foregroundColor = Palette.texto1
        var amount = AttributedString(Money(minor: parsed.amountMinor, currency: .cop).formatted())
        amount.foregroundColor = Palette.brasa
        text += amount
        if let merchant = parsed.merchant {
            var prefix = AttributedString(" en ")
            prefix.foregroundColor = Palette.texto1
            var name = AttributedString(merchant)
            name.foregroundColor = Palette.hielo
            text += prefix + name
        }
        if let last4 = parsed.last4 {
            var prefix = AttributedString(" con la tarjeta ")
            prefix.foregroundColor = Palette.texto1
            var card = AttributedString("*\(last4)")
            card.foregroundColor = Palette.oro
            text += prefix + card
        }
        return text
    }
}

/// Guía paso a paso para crear los atajos (F08-02 y F08-03).
private struct ShortcutGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State var guide: AutoCaptureView.Guide

    private var steps: [(String, String)] {
        switch guide {
        case .applePay:
            [("Abre Atajos", "Ve a la pestaña Automatización y toca el botón +."),
             ("Elige Transacción", "En la lista busca Wallet › Transacción. Marca tus tarjetas y \"Ejecutar de inmediato\"."),
             ("Agrega Registrar gasto", "Busca la acción \"Registrar gasto\" de MProgress."),
             ("Conecta los datos", "Monto: Importe de la transacción. Comercio: Comerciante. Tarjeta: Nombre de la tarjeta. Fuente: Apple Pay."),
             ("Listo", "La próxima vez que pagues con Apple Pay, el gasto aparece solo con su tarjeta.")]
        case .sms:
            [("Abre Atajos", "Ve a Automatización y toca +."),
             ("Elige Mensaje", "Mensaje › \"El mensaje contiene\" y escribe una palabra de tu banco, por ejemplo \"Compra\" o \"Compraste\". Marca \"Ejecutar de inmediato\"."),
             ("Agrega Leer SMS del banco", "Busca la acción \"Leer SMS del banco\" de MProgress."),
             ("Pasa el mensaje", "En Texto del SMS elige \"Mensaje\" (el contenido)."),
             ("Listo", "Si la app no está segura de algo, lo deja en \"Revisar\" en esta pantalla.")]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    SegmentedPill(options: [(value: AutoCaptureView.Guide.applePay, title: "Apple Pay"), (value: .sms, title: "SMS")], selection: $guide)
                    ForEach(Array(steps.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: Spacing.s3) {
                            Text("\(item.offset + 1)")
                                .appFont(.titulo3)
                                .foregroundStyle(Palette.sobreBrasa)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Palette.brasa))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.element.0).appFont(.titulo3).foregroundStyle(Palette.texto1)
                                Text(item.element.1).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("No leemos tus mensajes por nuestra cuenta: solo los que tu atajo nos pasa. Nunca pedimos claves ni números completos.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                    if let url = URL(string: "shortcuts://") {
                        Link("Abrir Atajos", destination: url).buttonStyle(.primary)
                    }
                    let setup: AutoSetup = guide == .applePay ? .applePay : .sms
                    if setup.isConfigured {
                        Label("Configurado", systemImage: "checkmark.circle.fill")
                            .appFont(.etiqueta)
                            .foregroundStyle(Palette.exito)
                            .frame(maxWidth: .infinity, minHeight: Size.toqueMinimo)
                    } else {
                        Button("Ya lo configuré") { setup.mark(); dismiss() }.buttonStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Configurar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}
