import AppIntents
import SwiftData

/// Fuente que manda el atajo.
enum CaptureSource: String, AppEnum {
    case applePay, sms, manual

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Fuente"
    static let caseDisplayRepresentations: [CaptureSource: DisplayRepresentation] = [
        .applePay: "Apple Pay",
        .sms: "SMS",
        .manual: "Manual",
    ]

    var entrySource: EntrySource {
        switch self {
        case .applePay: .applePay
        case .sms: .sms
        case .manual: .manual
        }
    }
}

/// "Registrar gasto" (F08-01): lo llama el atajo de Wallet con el monto, el comercio y la tarjeta.
struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar gasto"
    static let description = IntentDescription("Registra un gasto en MProgress. Lo usa el atajo de Wallet al pagar con Apple Pay.")
    static let openAppWhenRun = false

    @Parameter(title: "Monto")
    var amount: Double

    @Parameter(title: "Comercio")
    var merchant: String?

    /// Wallet entrega el nombre de la tarjeta; de ahí sacamos los últimos 4 si vienen.
    @Parameter(title: "Tarjeta o últimos 4")
    var card: String?

    @Parameter(title: "Fuente", default: .applePay)
    var source: CaptureSource

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar \(\.$amount) en \(\.$merchant)") {
            \.$card
            \.$source
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try Persistence.shared()
        let currency = Currency.cop
        let minor = Int64((amount * Double(currency.minorPerUnit)).rounded())
        guard minor > 0 else { return .result(dialog: "El monto tiene que ser mayor que cero.") }
        (source == .sms ? AutoSetup.sms : AutoSetup.applePay).mark()
        let last4 = card.flatMap { SmsParser.last4(in: "*\($0.filter(\.isNumber).suffix(4))") }
        let merchantName = merchant?.trimmingCharacters(in: .whitespaces).nilIfEmpty.map(SmsParser.prettify)
        let charge = ParsedCharge(kind: .gasto, amountMinor: minor, merchant: merchantName, last4: last4, bank: nil)
        let outcome = try AutoCaptureStore(context: container.mainContext).record(charge, source: source.entrySource)
        let text = Money(minor: minor, currency: currency).formatted()
        switch outcome {
        case .saved:
            return .result(dialog: "Listo: \(text)\(merchantName.map { " en \($0)" } ?? "").")
        case .duplicate:
            return .result(dialog: "Ese pago de \(text) ya estaba registrado.")
        }
    }
}

/// "Leer SMS del banco" (F08-03): el atajo de Mensajes manda el texto y la app lo entiende.
struct LogSmsIntent: AppIntent {
    static let title: LocalizedStringResource = "Leer SMS del banco"
    static let description = IntentDescription("Lee un SMS de compra o de plata recibida y lo registra. Si no está seguro, lo deja para revisar.")
    static let openAppWhenRun = false

    @Parameter(title: "Texto del SMS")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AutoSetup.sms.mark()
        guard let charge = SmsParser.parse(text) else {
            return .result(dialog: "Ese mensaje no parece una compra ni un pago.")
        }
        let container = try Persistence.shared()
        let outcome = try AutoCaptureStore(context: container.mainContext).record(charge, source: .sms)
        let money = Money(minor: charge.amountMinor, currency: .cop).formatted()
        switch outcome {
        case .saved(let entry):
            return .result(dialog: entry.needsReview ? "Guardé \(money). Revísalo en MProgress." : "Listo: \(money) en \(entry.name).")
        case .duplicate:
            return .result(dialog: "Ese pago de \(money) ya estaba registrado.")
        }
    }
}

/// "Registro rápido": abre la app lista para escribir el monto. Es el que se pone en el doble toque atrás.
struct QuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Registro rápido"
    static let description = IntentDescription("Abre MProgress para anotar un gasto o un ingreso: monto, si entra o sale y de dónde.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AutoSetup.dobleToque.mark()
        QuickAddRouter.shared.pending = true
        return .result()
    }
}

struct MProgressShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickAddIntent(), phrases: ["Registro rápido en \(.applicationName)", "Anotar en \(.applicationName)"],
                    shortTitle: "Registro rápido", systemImageName: "hand.tap")
        AppShortcut(intent: LogExpenseIntent(), phrases: ["Registrar gasto en \(.applicationName)", "Anotar gasto en \(.applicationName)"],
                    shortTitle: "Registrar gasto", systemImageName: "plus.circle")
        AppShortcut(intent: LogSmsIntent(), phrases: ["Leer SMS del banco con \(.applicationName)"],
                    shortTitle: "Leer SMS", systemImageName: "message")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
