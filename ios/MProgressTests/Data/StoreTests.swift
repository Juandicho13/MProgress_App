import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct StoreTests {
    let container: ModelContainer
    let personal: Space
    let ledger: LedgerStore
    let money: MoneyStore
    let user = UUID()

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        personal = try Seed.runIfNeeded(context: container.mainContext, localUser: user)
        ledger = LedgerStore(context: container.mainContext, calendar: bogota)
        money = MoneyStore(context: container.mainContext)
    }

    @Test("La semilla crea Personal y 15 categorías una sola vez")
    func semilla() throws {
        try Seed.runIfNeeded(context: container.mainContext, localUser: user)
        let spaces = try container.mainContext.fetch(FetchDescriptor<Space>())
        let categories = try container.mainContext.fetch(FetchDescriptor<SpendCategory>())
        #expect(spaces.count == 1)
        #expect(spaces.first?.name == "Personal")
        #expect(categories.count == 15)
        #expect(try ledger.categories(spaceId: personal.id).first?.name == "Entretenimiento")
    }

    @Test("Agregar un gasto lo deja pendiente de sincronizar")
    func agregar() throws {
        let entry = try ledger.addEntry(spaceId: personal.id, kind: .gasto, amountMinor: pesos(84_300), name: "Mercado", occurredAt: fecha(2026, 11, 3))
        #expect(entry.syncState == .pending)
        #expect(try ledger.entries(spaceId: personal.id).count == 1)
    }

    @Test("Borrar es suave y se puede deshacer")
    func borrarYDeshacer() throws {
        let entry = try ledger.addEntry(spaceId: personal.id, kind: .gasto, amountMinor: pesos(10_000), name: "Taxi")
        try ledger.softDelete(entry)
        #expect(entry.isRemoved)
        #expect(try ledger.entries(spaceId: personal.id).isEmpty)
        try ledger.restore(entry)
        #expect(try ledger.entries(spaceId: personal.id).count == 1)
    }

    @Test("Marcar pagado crea el movimiento y mueve la fecha al siguiente mes")
    func marcarPagado() throws {
        let gym = try ledger.addRecurring(spaceId: personal.id, kind: .gasto, name: "Gimnasio", amountMinor: pesos(119_900), cycle: .mensual, nextDate: fecha(2026, 11, 6))
        let entry = try ledger.markPaid(gym, on: fecha(2026, 11, 6))
        #expect(entry.recurringId == gym.id)
        #expect(dia(gym.nextDate) == "2026-12-06")
        #expect(gym.active)
    }

    @Test("Un pago puntual queda inactivo al pagarlo")
    func puntualPagado() throws {
        let item = try ledger.addRecurring(spaceId: personal.id, kind: .gasto, name: "Matrícula", amountMinor: pesos(500_000), cycle: .puntual, nextDate: fecha(2026, 11, 20))
        try ledger.markPaid(item, on: fecha(2026, 11, 20))
        #expect(!item.active)
    }

    @Test("El resumen del mes usa lo guardado")
    func resumen() throws {
        try ledger.addEntry(spaceId: personal.id, kind: .ingreso, amountMinor: pesos(2_200_000), name: "Sueldo", occurredAt: fecha(2026, 11, 1))
        try ledger.addEntry(spaceId: personal.id, kind: .gasto, amountMinor: pesos(179_000), name: "Varios", occurredAt: fecha(2026, 11, 2))
        try ledger.addRecurring(spaceId: personal.id, kind: .gasto, name: "Gimnasio", amountMinor: pesos(119_900), cycle: .mensual, nextDate: fecha(2026, 11, 6))
        let summary = try ledger.monthSummary(spaceId: personal.id, now: fecha(2026, 11, 5, 10))
        #expect(summary.remainingMinor == pesos(1_901_100))
    }

    @Test("Solo se guardan los últimos 4 dígitos válidos")
    func ultimos4() throws {
        #expect(MoneyStore.cleanLast4("4417") == "4417")
        #expect(MoneyStore.cleanLast4("·· 4417") == "4417")
        #expect(MoneyStore.cleanLast4("4532 1234 5678 4417") == nil)
        #expect(MoneyStore.cleanLast4("44") == nil)
    }

    @Test("Pagar la tarjeta con la cuenta baja la deuda y el saldo")
    func pagarTarjeta() throws {
        let banco = try money.addInstitution(spaceId: personal.id, name: "Bancolombia")
        let cuenta = try money.addProduct(spaceId: personal.id, institutionId: banco.id, kind: .cuenta, name: "Ahorros", balanceMinor: pesos(500_000))
        let tarjeta = try money.addProduct(spaceId: personal.id, institutionId: banco.id, kind: .credito, name: "Oro", balanceMinor: pesos(1_000_000), last4: "4417")
        try money.transfer(spaceId: personal.id, from: cuenta, to: tarjeta, amountMinor: pesos(300_000), on: .now.addingTimeInterval(5))
        let products = try money.products(spaceId: personal.id).map(\.record)
        let transfers = try money.transfers(spaceId: personal.id).map(\.record)
        #expect(MoneyCalculator.currentBalance(of: tarjeta.record, products: products, entries: [], transfers: transfers) == pesos(700_000))
        #expect(MoneyCalculator.currentBalance(of: cuenta.record, products: products, entries: [], transfers: transfers) == pesos(200_000))
    }
}
