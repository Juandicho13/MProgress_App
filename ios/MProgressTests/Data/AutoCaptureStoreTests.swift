import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct AutoCaptureStoreTests {
    let container: ModelContainer
    let space: Space
    let capture: AutoCaptureStore
    let card: Product

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        capture = AutoCaptureStore(context: container.mainContext, calendar: bogota)
        let money = MoneyStore(context: container.mainContext)
        let bank = try money.addInstitution(spaceId: space.id, name: "Bancolombia")
        card = try money.addProduct(spaceId: space.id, institutionId: bank.id, kind: .credito, name: "Oro", last4: "4417")
    }

    @Test("Un SMS completo se guarda con su tarjeta y sin revisar")
    func smsCompleto() throws {
        let charge = try #require(SmsParser.parse("Bancolombia: Compra por $84.300,00 en EXITO con T.Cred *4417."))
        guard case .saved(let entry) = try capture.record(charge, source: .sms) else { Issue.record("debía guardarse"); return }
        #expect(entry.productId == card.id)
        #expect(entry.name == "Exito")
        #expect(entry.sourceRaw == "sms")
        #expect(!entry.needsReview)
    }

    @Test("Sin tarjeta conocida queda para revisar")
    func tarjetaDesconocida() throws {
        let charge = ParsedCharge(kind: .gasto, amountMinor: pesos(12_000), merchant: "Café", last4: "9999", bank: nil)
        guard case .saved(let entry) = try capture.record(charge, source: .sms) else { Issue.record("debía guardarse"); return }
        #expect(entry.productId == nil)
        #expect(entry.needsReview)
    }

    @Test("Apple Pay y el SMS del mismo pago no se duplican")
    func duplicado() throws {
        let now = Date.now
        let applePay = ParsedCharge(kind: .gasto, amountMinor: pesos(45_500), merchant: nil, last4: "4417", bank: nil)
        guard case .saved(let first) = try capture.record(applePay, source: .applePay, now: now) else { Issue.record("debía guardarse"); return }
        #expect(first.methodRaw == "applePay")
        let sms = ParsedCharge(kind: .gasto, amountMinor: pesos(45_500), merchant: "Netflix", last4: "4417", bank: "Nu")
        guard case .duplicate(let same) = try capture.record(sms, source: .sms, now: now.addingTimeInterval(30)) else { Issue.record("debía ser duplicado"); return }
        #expect(same.id == first.id)
        #expect(same.name == "Netflix")
        #expect(try LedgerStore(context: container.mainContext).entries(spaceId: space.id).count == 1)
        #expect(try capture.recent().count == 1)
    }

    @Test("Editar un detectado lo marca como revisado")
    func revisar() throws {
        let charge = ParsedCharge(kind: .gasto, amountMinor: pesos(18_000), merchant: "Taxi", last4: nil, bank: nil)
        guard case .saved(let entry) = try capture.record(charge, source: .sms) else { Issue.record("debía guardarse"); return }
        #expect(entry.needsReview)
        let model = AddEntryModel(editing: entry)
        model.productId = card.id
        try model.save(context: container.mainContext, spaceId: space.id, calendar: bogota)
        #expect(!entry.needsReview)
    }

    @Test("Un recibo crea un borrador con nombre y monto")
    func recibo() throws {
        let model = AddEntryModel(prefillName: "Supermercado La 14", amountMinor: pesos(9_996), source: .recibo)
        #expect(model.canSave)
        let entry = try model.save(context: container.mainContext, spaceId: space.id, calendar: bogota)
        #expect(entry?.sourceRaw == "recibo")
        #expect(entry?.amountMinor == pesos(9_996))
    }
}
