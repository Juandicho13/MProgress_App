import Foundation
import SwiftData
import Testing
@testable import MProgress

/// Quién te debe con SwiftData (solo Xcode): saldos de la cuenta elegida, abonos, borrar con Deshacer y respaldo.
@MainActor
struct DebtStoreTests {
    let container: ModelContainer
    let space: Space
    let money: MoneyStore
    let store: DebtStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        money = MoneyStore(context: container.mainContext)
        store = DebtStore(context: container.mainContext)
    }

    private func balance(_ product: Product) throws -> Int64 {
        let products = try money.products(spaceId: space.id).map(\.record)
        let transfers = try money.transfers(spaceId: space.id).map(\.record)
        return MoneyCalculator.currentBalance(of: product.record, products: products, entries: [], transfers: transfers)
    }

    @Test("Prestar desde una cuenta baja su saldo; el abono lo sube y no pasa de lo que falta")
    func prestar() throws {
        let bank = try money.addInstitution(spaceId: space.id, name: "Bancolombia")
        let cuenta = try money.addProduct(spaceId: space.id, institutionId: bank.id, draft: .init(kind: .cuenta, name: "Ahorros", balanceMinor: pesos(1_000_000)),
                                          now: fecha(2026, 11, 1))
        let debt = try store.save(nil, spaceId: space.id, person: "  Ana  María ", direction: .meDebe, amountMinor: pesos(300_000),
                                  date: fecha(2026, 11, 2), dueDate: fecha(2026, 11, 15), note: " Almuerzo ", productId: cuenta.id)
        #expect(debt.person == "Ana María")
        #expect(debt.notes == "Almuerzo")
        #expect(debt.transferId != nil)
        #expect(try balance(cuenta) == pesos(700_000))
        try store.addPayment(to: debt, amountMinor: pesos(100_000), date: fecha(2026, 11, 3), productId: cuenta.id)
        #expect(try balance(cuenta) == pesos(800_000))
        let rest = try store.addPayment(to: debt, amountMinor: pesos(900_000), date: fecha(2026, 11, 4), productId: nil)
        #expect(rest?.amountMinor == pesos(200_000))
        #expect(try store.addPayment(to: debt, amountMinor: 1, date: fecha(2026, 11, 4), productId: nil) == nil)
        #expect(try store.remaining(debt) == 0)
        #expect(debt.syncState == .pending)
    }

    @Test("Borrar la deuda quita abonos y transferencias; Deshacer las devuelve")
    func borrar() throws {
        let bank = try money.addInstitution(spaceId: space.id, name: "Nu")
        let cuenta = try money.addProduct(spaceId: space.id, institutionId: bank.id, draft: .init(kind: .cuenta, name: "Cuenta", balanceMinor: pesos(500_000)),
                                          now: fecha(2026, 11, 1))
        let debt = try store.save(nil, spaceId: space.id, person: "Carlos", direction: .leDebo, amountMinor: pesos(80_000),
                                  date: fecha(2026, 11, 2), dueDate: nil, note: nil, productId: cuenta.id)
        try store.addPayment(to: debt, amountMinor: pesos(30_000), date: fecha(2026, 11, 3), productId: cuenta.id)
        #expect(try balance(cuenta) == pesos(550_000))
        let removed = try store.delete(debt)
        #expect(try store.debts(spaceId: space.id).isEmpty)
        #expect(try balance(cuenta) == pesos(500_000))
        try store.restore(debt, payments: removed)
        #expect(try balance(cuenta) == pesos(550_000))
        #expect(try store.payments(spaceId: space.id).count == 1)
    }

    @Test("El respaldo lleva deudas y abonos")
    func respaldo() throws {
        let debt = try store.save(nil, spaceId: space.id, person: "Ana", direction: .meDebe, amountMinor: pesos(50_000),
                                  date: fecha(2026, 11, 2), dueDate: nil, note: "Taxi", productId: nil)
        try store.addPayment(to: debt, amountMinor: pesos(20_000), date: fecha(2026, 11, 3), productId: nil)
        let snapshot = try BackupService.snapshot(context: container.mainContext)
        #expect(snapshot.debts?.count == 1)
        #expect(snapshot.debts?.first?.directionRaw == "me_debe")
        #expect(snapshot.debtPayments?.count == 1)
        let data = try BackupCodec.encode(snapshot)
        try BackupService.restore(try BackupCodec.decode(data), context: container.mainContext)
        let back = try store.debts(spaceId: space.id)
        #expect(back.count == 1)
        #expect(try store.remaining(back[0]) == pesos(30_000))
    }
}
