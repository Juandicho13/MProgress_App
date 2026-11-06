import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct BackupServiceTests {
    @Test("Restaurar en un iPhone limpio deja todo igual")
    func restaurarLimpio() throws {
        let origin = try Persistence.makeContainer(inMemory: true)
        let context = origin.mainContext
        let space = try Seed.runIfNeeded(context: context, localUser: UUID())
        let ledger = LedgerStore(context: context, calendar: bogota)
        let money = MoneyStore(context: context)
        let planning = PlanningStore(context: context)

        let bank = try money.addInstitution(spaceId: space.id, name: "Nu", colorHex: "A68CFF")
        let cajita = try money.addProduct(spaceId: space.id, institutionId: bank.id, kind: .bolsillo, name: "Emergencias",
                                          balanceMinor: pesos(1_500_000), rateEA: Decimal(string: "8.25"))
        let cuenta = try money.addProduct(spaceId: space.id, institutionId: bank.id, kind: .cuenta, name: "Cuenta", balanceMinor: pesos(600_000))
        try money.transfer(spaceId: space.id, from: cuenta, to: cajita, amountMinor: pesos(100_000))
        let renta = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Renta", amountMinor: pesos(2_275_000), cycle: .mensual, nextDate: fecha(2026, 12, 1))
        try planning.setReminder(spaceId: space.id, recurringId: renta.id, daysBefore: 3, atMinutes: 540, sameDay: false)
        let gasto = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(84_300), name: "Mercado", productId: cuenta.id, notes: "Semana")
        let borrado = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(1_000), name: "Error")
        try ledger.softDelete(borrado)
        try planning.setBudget(spaceId: space.id, categoryId: nil, limitMinor: pesos(1_500_000))
        let meta = try planning.addGoal(spaceId: space.id, name: "Viaje", targetMinor: pesos(5_000_000), targetDate: fecha(2027, 6, 1))
        try planning.contribute(to: meta, amountMinor: pesos(300_000))

        let data = try BackupCodec.encode(BackupService.snapshot(context: context))

        let target = try Persistence.makeContainer(inMemory: true)
        _ = try Seed.runIfNeeded(context: target.mainContext, localUser: UUID())
        try BackupService.restore(BackupService.read(data), context: target.mainContext)
        let restored = target.mainContext

        #expect(try restored.fetch(FetchDescriptor<Space>()).map(\.id) == [space.id])
        let entries = try LedgerStore(context: restored).entries(spaceId: space.id)
        #expect(entries.map(\.id) == [gasto.id])
        #expect(entries.first?.notes == "Semana")
        #expect(try restored.fetch(FetchDescriptor<Entry>()).count == 2)
        let products = try MoneyStore(context: restored).products(spaceId: space.id)
        #expect(products.first { $0.id == cajita.id }?.rateEA == Decimal(string: "8.25"))
        #expect(try MoneyStore(context: restored).transfers(spaceId: space.id).count == 1)
        let fijos = try LedgerStore(context: restored).recurring(spaceId: space.id)
        #expect(fijos.first?.anchorDay == 1)
        #expect(try PlanningStore(context: restored).reminders(spaceId: space.id).first?.sameDay == false)
        #expect(try PlanningStore(context: restored).budgets(spaceId: space.id).count == 1)
        #expect(try PlanningStore(context: restored).contributions(spaceId: space.id).first?.amountMinor == pesos(300_000))
        #expect(try restored.fetch(FetchDescriptor<SpendCategory>()).count == 15)

        let again = try BackupCodec.encode(BackupService.snapshot(context: restored, now: BackupCodec.decode(data).createdAt))
        let first = try BackupCodec.decode(data)
        var second = try BackupCodec.decode(again)
        second.createdAt = first.createdAt
        #expect(Set(first.entries.map(\.id)) == Set(second.entries.map(\.id)))
        #expect(first.products.map(\.balanceMinor).sorted() == second.products.map(\.balanceMinor).sorted())
    }
}
