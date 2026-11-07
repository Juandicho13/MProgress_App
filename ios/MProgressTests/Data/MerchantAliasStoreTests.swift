import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct MerchantAliasStoreTests {
    let container: ModelContainer
    let space: Space
    let capture: AutoCaptureStore
    let aliases: MerchantAliasStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        capture = AutoCaptureStore(context: container.mainContext, calendar: bogota)
        aliases = MerchantAliasStore(context: container.mainContext)
    }

    private func categoryId() throws -> UUID {
        try #require(try container.mainContext.fetch(FetchDescriptor<SpendCategory>()).first?.id)
    }

    @Test("Renombrar un SMS aprende el comercio y el siguiente pago llega con ese nombre y categoría")
    func aprendeDeUnSms() throws {
        let category = try categoryId()
        let first = ParsedCharge(kind: .gasto, amountMinor: pesos(32_000), merchant: "Pepepollo Sas 123", last4: nil, bank: nil)
        guard case .saved(let entry) = try capture.record(first, source: .sms, now: fecha(2026, 11, 2, 13)) else { Issue.record("debía guardarse"); return }
        let model = AddEntryModel(editing: entry)
        model.name = "El Corral"
        model.categoryId = category
        try model.save(context: container.mainContext, spaceId: space.id, calendar: bogota)
        let rules = aliases.rules(spaceId: space.id)
        #expect(rules.count == 1)
        #expect(rules.first?.key == "PEPEPOLLO")

        let second = ParsedCharge(kind: .gasto, amountMinor: pesos(41_000), merchant: "PEPEPOLLO SAS 456", last4: nil, bank: nil)
        guard case .saved(let next) = try capture.record(second, source: .sms, now: fecha(2026, 11, 5, 13)) else { Issue.record("debía guardarse"); return }
        #expect(next.name == "El Corral")
        #expect(next.categoryId == category)
        #expect(next.merchant == "PEPEPOLLO SAS 456")
    }

    @Test("Un movimiento manual no aprende nada")
    func manualNoAprende() throws {
        let model = AddEntryModel()
        model.name = "Mercado"
        model.amount = AmountInput(minor: pesos(10_000), currency: .cop)
        try model.save(context: container.mainContext, spaceId: space.id, calendar: bogota)
        #expect(aliases.rules(spaceId: space.id).isEmpty)
    }

    @Test("Un recibo renombrado aprende y guardar lo mismo no cambia la regla")
    func reciboYSinCambios() throws {
        let model = AddEntryModel(prefillName: "Farmatodo Sas", amountMinor: pesos(9_900), source: .recibo)
        model.name = "Droguería"
        let entry = try #require(try model.save(context: container.mainContext, spaceId: space.id, calendar: bogota))
        #expect(entry.merchant == "Farmatodo Sas")
        let alias = try #require(try aliases.aliases(spaceId: space.id).first)
        #expect(alias.merchantKey == "FARMATODO")
        let stamp = alias.updatedAt
        try aliases.save(MerchantAliasRule(key: "FARMATODO", name: "Droguería", categoryId: nil), spaceId: space.id, now: stamp.addingTimeInterval(60))
        #expect(alias.updatedAt == stamp)
    }

    @Test("Borrar y deshacer una regla; borrada ya no se usa")
    func borrar() throws {
        let alias = try aliases.save(MerchantAliasRule(key: "EXITO", name: "Éxito", categoryId: nil), spaceId: space.id)
        try aliases.delete(alias)
        #expect(aliases.match("EXITO CALLE 80", spaceId: space.id) == nil)
        try aliases.restore(alias)
        #expect(aliases.match("EXITO CALLE 80", spaceId: space.id)?.name == "Éxito")
    }

    @Test("Marcar pagado guarda lo que se pagó y el fijo conserva su monto")
    func marcarPagadoConOtroValor() throws {
        let ledger = LedgerStore(context: container.mainContext, calendar: bogota)
        let item = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Energía", amountMinor: pesos(120_000),
                                           cycle: .cadaMeses(2), nextDate: fecha(2026, 11, 10))
        let entry = try ledger.markPaid(item, on: fecha(2026, 11, 10), amountMinor: pesos(98_500))
        #expect(entry.amountMinor == pesos(98_500))
        #expect(item.amountMinor == pesos(120_000))
        #expect(item.intervalMonths == 2)
        #expect(dia(item.nextDate) == "2027-01-10")
    }

    @Test("El respaldo lleva los nombres de comercios y los meses del pago fijo")
    func respaldo() throws {
        _ = try aliases.save(MerchantAliasRule(key: "PEPEPOLLO", name: "El Corral", categoryId: nil), spaceId: space.id)
        _ = try LedgerStore(context: container.mainContext, calendar: bogota).addRecurring(
            spaceId: space.id, kind: .gasto, name: "Seguro", amountMinor: pesos(300_000), cycle: .cadaMeses(3), nextDate: fecha(2026, 12, 1))
        let snapshot = try BackupService.snapshot(context: container.mainContext)
        let decoded = try BackupCodec.decode(try BackupCodec.encode(snapshot))
        #expect(decoded.merchantAliases?.first?.key == "PEPEPOLLO")
        #expect(decoded.recurring.first { $0.name == "Seguro" }?.intervalMonths == 3)
        try BackupService.restore(decoded, context: container.mainContext)
        let restored = try container.mainContext.fetch(FetchDescriptor<Recurring>()).first { $0.name == "Seguro" }
        #expect(restored?.cycle == .cadaMeses(3))
        #expect(aliases.match("Pepepollo 9", spaceId: space.id)?.name == "El Corral")
    }
}
