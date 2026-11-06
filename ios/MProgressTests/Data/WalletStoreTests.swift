import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct WalletStoreTests {
    let container: ModelContainer
    let space: Space
    let store: MoneyStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        store = MoneyStore(context: container.mainContext)
    }

    @Test("Una tarjeta de crédito guarda solo 4 dígitos, cupo, corte y pago")
    func credito() throws {
        let bank = try store.addInstitution(spaceId: space.id, name: "Bancolombia")
        var draft = MoneyStore.ProductDraft(kind: .credito, name: "  Crédito Oro ", balanceMinor: pesos(1_000_000), last4: "4417",
                                            creditLimitMinor: pesos(15_400_000), cutDay: 5, dueDay: 40, rateEA: 3)
        let card = try store.addProduct(spaceId: space.id, institutionId: bank.id, draft: draft)
        #expect(card.name == "Crédito Oro")
        #expect(card.last4 == "4417")
        #expect(card.dueDay == 31)
        #expect(card.rateEA == nil)
        #expect(card.creditLimitMinor == pesos(15_400_000))

        draft.last4 = "4417 1234 5678 9012"
        draft.remindPayment = false
        let other = try store.addProduct(spaceId: space.id, institutionId: bank.id, draft: draft)
        #expect(other.last4 == nil)
        #expect(other.dueDay == nil)
    }

    @Test("Editar sin tocar el saldo no reinicia la fecha del saldo")
    func editarSaldo() throws {
        let bank = try store.addInstitution(spaceId: space.id, name: "Nu")
        let cuenta = try store.addProduct(spaceId: space.id, institutionId: bank.id,
                                          draft: .init(kind: .cuenta, name: "Cuenta", balanceMinor: pesos(500_000)), now: fecha(2026, 11, 1))
        let ledger = LedgerStore(context: container.mainContext, calendar: bogota)
        try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(100_000), name: "Mercado", occurredAt: fecha(2026, 11, 3), productId: cuenta.id)

        var draft = MoneyStore.ProductDraft(kind: .cuenta, name: "Cuenta Nu", balanceMinor: pesos(400_000))
        try store.update(cuenta, draft: draft, currentBalanceMinor: pesos(400_000), now: fecha(2026, 11, 5))
        #expect(cuenta.name == "Cuenta Nu")
        #expect(cuenta.balanceMinor == pesos(500_000))
        #expect(dia(cuenta.balanceAt) == "2026-11-01")

        draft.balanceMinor = pesos(450_000)
        try store.update(cuenta, draft: draft, currentBalanceMinor: pesos(400_000), now: fecha(2026, 11, 5))
        #expect(cuenta.balanceMinor == pesos(450_000))
        #expect(dia(cuenta.balanceAt) == "2026-11-05")
    }

    @Test("La billetera de efectivo se crea una sola vez")
    func efectivo() throws {
        let first = try store.cash(spaceId: space.id)
        let second = try store.cash(spaceId: space.id)
        #expect(first.id == second.id)
        #expect(try store.institutions(spaceId: space.id).map(\.name) == ["Efectivo"])
    }

    @Test("Borrar un banco borra sus productos")
    func borrarBanco() throws {
        let bank = try store.addInstitution(spaceId: space.id, name: "Nu")
        try store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .cuenta, name: "Cuenta")
        try store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .bolsillo, name: "Cajita")
        try store.softDelete(bank)
        #expect(try store.institutions(spaceId: space.id).isEmpty)
        #expect(try store.products(spaceId: space.id).isEmpty)
    }

    @Test("Agregar guarda con qué se pagó y su forma de pago")
    func pagarCon() throws {
        let bank = try store.addInstitution(spaceId: space.id, name: "Bancolombia")
        let card = try store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .credito, name: "Oro", last4: "4417")
        let model = AddEntryModel()
        model.name = "Café"
        model.amount.press("9")
        model.productId = card.id
        model.method = .applePay
        let entry = try model.save(context: container.mainContext, spaceId: space.id, now: .now, calendar: bogota)
        #expect(entry?.productId == card.id)
        #expect(entry?.methodRaw == "applePay")

        let edit = AddEntryModel(editing: try #require(entry))
        #expect(edit.method == .applePay)
        edit.method = .enLinea
        try edit.save(context: container.mainContext, spaceId: space.id, calendar: bogota)
        #expect(entry?.methodRaw == "enLinea")
    }

    @Test("Pagar la tarjeta con una transferencia baja la deuda y no es gasto")
    func pagarTarjeta() throws {
        let bank = try store.addInstitution(spaceId: space.id, name: "Bancolombia")
        let cuenta = try store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .cuenta, name: "Ahorros", balanceMinor: pesos(1_000_000))
        let card = try store.addProduct(spaceId: space.id, institutionId: bank.id, kind: .credito, name: "Oro", balanceMinor: pesos(300_000))
        try store.transfer(spaceId: space.id, from: cuenta, to: card, amountMinor: pesos(300_000), on: .now.addingTimeInterval(1))
        let products = try store.products(spaceId: space.id).map(\.record)
        let transfers = try store.transfers(spaceId: space.id).map(\.record)
        #expect(MoneyCalculator.currentBalance(of: card.record, products: products, entries: [], transfers: transfers) == 0)
        #expect(MoneyCalculator.currentBalance(of: cuenta.record, products: products, entries: [], transfers: transfers) == pesos(700_000))
        #expect(try LedgerStore(context: container.mainContext).entries(spaceId: space.id).isEmpty)
    }
}
