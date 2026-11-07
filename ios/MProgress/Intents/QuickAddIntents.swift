import AppIntents
import SwiftData
import Foundation

/// Ajuste del registro rápido: abrir la app (como antes) en vez de anotar sin abrirla.
enum QuickAddSettings {
    static let opensAppKey = "rapido.abrirApp"
    static var opensApp: Bool { UserDefaults.standard.bool(forKey: opensAppKey) }
}

/// Gasto o ingreso, para preguntarlo con el cuadro del sistema y para la frase "Anota un gasto en MProgress".
enum QuickKind: String, AppEnum {
    case gasto, ingreso

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tipo"
    static let caseDisplayRepresentations: [QuickKind: DisplayRepresentation] = [
        .gasto: "Gasto",
        .ingreso: "Ingreso",
    ]

    var entryKind: EntryKind { self == .ingreso ? .ingreso : .gasto }
}

/// Cuenta, tarjeta o efectivo que se ofrece en "¿De dónde sale?". Solo nombre y últimos 4.
struct QuickProductEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cuenta o tarjeta"
    static let defaultQuery = QuickProductQuery()
    /// Elegirlo deja el movimiento sin producto.
    static let unselected = QuickProductEntity(id: "sin-elegir", title: "Sin elegir", subtitle: "Lo decides después")

    let id: String
    let title: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
}

struct QuickProductQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [QuickProductEntity] {
        let all = QuickAddRunner.productOptions(for: nil) + [.unselected]
        return all.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [QuickProductEntity] {
        QuickAddRunner.productOptions(for: nil)
    }
}

/// Un nombre de los que más usas ("Almuerzo", "Taxi") para "¿En qué?". El id es el nombre.
struct QuickNameEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "En qué"
    static let defaultQuery = QuickNameQuery()
    /// Elegirlo deja el nombre de siempre ("Gasto rápido" o "Ingreso rápido").
    static let unnamed = QuickNameEntity(id: "sin-nombre", title: "Sin nombre")

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct QuickNameQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [QuickNameEntity] {
        let all = QuickAddRunner.nameOptions(for: .gasto) + QuickAddRunner.nameOptions(for: .ingreso) + [.unnamed]
        return all.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [QuickNameEntity] {
        QuickAddRunner.nameOptions(for: .gasto)
    }
}

/// "Registro rápido" (doble toque atrás, Siri, Atajos) sin abrir la app (PLAN_F12B Paso 3): pide el monto con
/// el cuadro del sistema, luego gasto o ingreso y de dónde sale o a dónde entra; guarda y muestra en la isla
/// dinámica "− $ 84.300 · te quedan $ 1.901.100" con Deshacer, que se cierra sola a los 8 segundos.
/// Con el ajuste "Abrir la app al anotar" hace lo de antes: abre MProgress en Registro rápido.
struct QuickAddIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Registro rápido"
    static let description = IntentDescription("Anota un gasto o un ingreso sin abrir MProgress: monto, si entra o sale y de dónde. Lo puedes deshacer desde la isla dinámica.")
    /// Corre en segundo plano; solo pasa al frente si la persona eligió abrir la app.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Monto")
    var amount: Double?

    @Parameter(title: "Tipo")
    var kind: QuickKind?

    @Parameter(title: "Cuenta o tarjeta")
    var product: QuickProductEntity?

    @Parameter(title: "Concepto")
    var concept: String?

    /// "¿En qué?" con los nombres que más usas; solo se pregunta si no llegó el concepto y hay nombres recientes.
    @Parameter(title: "En qué")
    var recentName: QuickNameEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Anotar \(\.$amount)") {
            \.$kind
            \.$product
            \.$concept
            \.$recentName
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AutoSetup.dobleToque.mark()

        // Comportamiento anterior, si la persona lo prefiere: abrir la app en Registro rápido.
        if QuickAddSettings.opensApp {
            let mode = systemContext.currentMode
            let inBackground = mode == .background
            if !inBackground || mode.canContinueInForeground {
                if inBackground { try await continueInForeground(nil, alwaysConfirm: false) }
                QuickAddRouter.shared.pending = true
                return .result(dialog: "Listo para anotar en MProgress.")
            }
        }

        let currency = QuickAddRunner.currency()
        var units = amount
        if units == nil { units = try await $amount.requestValue("¿Cuánto?") }
        guard let value = units, let minor = QuickAddMath.minor(fromUnits: value, currency: currency) else {
            return .result(dialog: "El monto tiene que ser mayor que cero.")
        }

        var chosenKind = kind
        if chosenKind == nil { chosenKind = try await $kind.requestValue("¿Es un gasto o un ingreso?") }
        let entryKind = (chosenKind ?? .gasto).entryKind

        var chosenProduct = product
        if chosenProduct == nil {
            let options = QuickAddRunner.productOptions(for: entryKind)
            if !options.isEmpty {
                let prompt: IntentDialog = entryKind == .gasto ? "¿De dónde sale?" : "¿A dónde entra?"
                chosenProduct = try await $product.requestDisambiguation(among: options + [QuickProductEntity.unselected], dialog: prompt)
            }
        }
        let productId = chosenProduct.flatMap { UUID(uuidString: $0.id) }

        var chosenConcept = concept?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if chosenConcept.isEmpty {
            var picked = recentName
            let options = QuickAddRunner.nameOptions(for: entryKind)
            if picked == nil, !options.isEmpty {
                picked = try await $recentName.requestDisambiguation(among: options + [QuickNameEntity.unnamed], dialog: "¿En qué?")
            }
            if let picked, picked.id != QuickNameEntity.unnamed.id { chosenConcept = picked.title }
        }

        let state = try QuickAddRunner.save(amountMinor: minor, kind: entryKind, productId: productId, concept: chosenConcept)
        if await QuickAddActivityController.show(state) {
            QuickAddBackgroundHold.closeLater(entryId: state.entryId)
        }
        return .result(dialog: "Anotado: \(QuickAddMath.liveLine(amountText: state.amountText, remainingText: state.remainingText)).")
    }
}

/// El registro rápido de siempre: abre la app lista para escribir el monto.
struct QuickAddInAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Registro rápido en la app"
    static let description = IntentDescription("Abre MProgress para anotar un gasto o un ingreso: monto, si entra o sale y de dónde.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AutoSetup.dobleToque.mark()
        QuickAddRouter.shared.pending = true
        return .result()
    }
}

/// Lo que hace el registro rápido con la base. Lo usan los intents y el Deshacer de la Live Activity.
@MainActor
enum QuickAddRunner {
    /// La app lo llama al arrancar para que el Deshacer de la isla dinámica pueda borrar en la base.
    static func installUndo() {
        QuickAddUndo.handler = { id in await undo(entryId: id) }
    }

    static func space(in context: ModelContext) -> Space? {
        let spaces = (try? context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil },
                                                                 sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return spaces.first { $0.kindRaw == "personal" } ?? spaces.first
    }

    static func currency() -> Currency {
        guard let container = try? Persistence.shared() else { return .cop }
        return space(in: container.mainContext)?.currency ?? .cop
    }

    /// Productos que se ofrecen: para un gasto, tarjetas, cuentas y efectivo; para un ingreso, cuentas, cajitas
    /// y efectivo. Con `kind` nil, todos.
    static func productOptions(for kind: EntryKind?) -> [QuickProductEntity] {
        guard let container = try? Persistence.shared() else { return [] }
        let context = container.mainContext
        guard let space = space(in: context) else { return [] }
        let money = MoneyStore(context: context)
        let institutions = (try? money.institutions(spaceId: space.id)) ?? []
        let products = (try? money.products(spaceId: space.id)) ?? []
        return products
            .filter { product in kind.map { QuickAddMath.offers(product.kind, for: $0) } ?? true }
            .map { product in
                let bank = institutions.first { $0.id == product.institutionId }?.name ?? product.kind.title
                let title = product.last4.map { "\(product.name) ·· \($0)" } ?? product.name
                return QuickProductEntity(id: product.id.uuidString, title: title, subtitle: bank)
            }
    }

    /// Los nombres que más usas en movimientos recientes de ese tipo (los mismos chips de la app).
    static func recentNames(for kind: EntryKind, in context: ModelContext) -> [QuickName] {
        guard let space = space(in: context) else { return [] }
        let spaceId = space.id
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.deletedAt == nil && $0.spaceId == spaceId },
                                                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        descriptor.fetchLimit = QuickNames.window * 2
        let entries = (try? context.fetch(descriptor)) ?? []
        return QuickNames.recent(entries.map(\.record), kind: kind)
    }

    static func nameOptions(for kind: EntryKind) -> [QuickNameEntity] {
        guard let container = try? Persistence.shared() else { return [] }
        return recentNames(for: kind, in: container.mainContext).map { QuickNameEntity(id: $0.name, title: $0.name) }
    }

    /// Guarda el movimiento y arma lo que muestra la Live Activity.
    static func save(amountMinor: Int64, kind: EntryKind, productId: UUID?, concept: String?,
                     now: Date = .now, calendar: Calendar = .current) throws -> QuickAddAttributes.ContentState {
        let container = try Persistence.shared()
        let context = container.mainContext
        guard let space = space(in: context) else { throw CocoaError(.coderValueNotFound) }
        let ledger = LedgerStore(context: context, calendar: calendar)
        let name = QuickAddMath.name(kind: kind, concept: concept)
        // Un nombre que ya usas trae la categoría que le pusiste la última vez.
        let categoryId = kind == .gasto ? QuickNames.categoryId(for: concept ?? "", in: recentNames(for: kind, in: context)) : nil
        let entry = try ledger.addEntry(spaceId: space.id, kind: kind, amountMinor: amountMinor, name: name, occurredAt: now,
                                        categoryId: categoryId, productId: productId, createdBy: LocalIdentity.userId)
        let summary = try ledger.monthSummary(spaceId: space.id, now: now)
        WidgetPublisher.publish(context: context)
        let currency = space.currency
        return QuickAddAttributes.ContentState(
            entryId: entry.id.uuidString,
            amountText: QuickAddMath.amountText(kind: kind, amountMinor: amountMinor, currency: currency),
            remainingText: QuickAddMath.remainingText(summary.remainingMinor, currency: currency),
            name: name,
            isIncome: kind == .ingreso,
            remainingIsNegative: summary.remainingMinor < 0
        )
    }

    /// Deshacer desde la isla dinámica: borra (suave) el movimiento y cierra la actividad.
    static func undo(entryId: UUID) async {
        if let container = try? Persistence.shared() {
            let context = container.mainContext
            let descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.id == entryId })
            if let entry = try? context.fetch(descriptor).first, entry.deletedAt == nil {
                try? LedgerStore(context: context).softDelete(entry)
                WidgetPublisher.publish(context: context)
            }
        }
        await QuickAddActivityController.markUndone(entryId.uuidString)
    }
}

struct MProgressShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickAddIntent(), phrases: [
            "Anota en \(.applicationName)",
            "Anota un \(\.$kind) en \(.applicationName)",
            "Registro rápido en \(.applicationName)",
            "Anotar en \(.applicationName)",
        ], shortTitle: "Registro rápido", systemImageName: "hand.tap")
        AppShortcut(intent: LogExpenseIntent(), phrases: ["Registrar gasto en \(.applicationName)", "Anotar gasto en \(.applicationName)"],
                    shortTitle: "Registrar gasto", systemImageName: "plus.circle")
        AppShortcut(intent: LogSmsIntent(), phrases: ["Leer SMS del banco con \(.applicationName)"],
                    shortTitle: "Leer SMS", systemImageName: "message")
    }
}
