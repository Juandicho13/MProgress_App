import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct PlanningStoreTests {
    let container: ModelContainer
    let space: Space
    let store: PlanningStore
    let ledger: LedgerStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        store = PlanningStore(context: container.mainContext)
        ledger = LedgerStore(context: container.mainContext, calendar: bogota)
    }

    @Test("Un solo aviso por pago fijo, con límites de 0 a 14 días")
    func avisos() throws {
        let renta = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Renta", amountMinor: pesos(2_275_000), cycle: .mensual, nextDate: fecha(2026, 11, 15))
        try store.setReminder(spaceId: space.id, recurringId: renta.id, daysBefore: 3, atMinutes: 540, sameDay: true)
        try store.setReminder(spaceId: space.id, recurringId: renta.id, daysBefore: 30, atMinutes: 2000, sameDay: false)
        let avisos = try store.reminders(spaceId: space.id)
        #expect(avisos.count == 1)
        #expect(avisos[0].daysBefore == 14)
        #expect(avisos[0].atMinutes == 1439)
        #expect(avisos[0].rule.sameDay == false)
        try store.removeReminder(for: renta.id)
        #expect(try store.reminders(spaceId: space.id).isEmpty)
    }

    @Test("Un límite por categoría y avisos al cruzar el 80 %")
    func limites() throws {
        let categoria = try #require(try ledger.categories(spaceId: space.id).first)
        try store.setBudget(spaceId: space.id, categoryId: categoria.id, limitMinor: pesos(100_000))
        try store.setBudget(spaceId: space.id, categoryId: categoria.id, limitMinor: pesos(200_000))
        try store.setBudget(spaceId: space.id, categoryId: nil, limitMinor: pesos(1_000_000))
        #expect(try store.budgets(spaceId: space.id).count == 2)

        let primero = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(100_000), name: "A", categoryId: categoria.id)
        #expect(try store.budgetCrossings(spaceId: space.id, newEntry: primero, calendar: bogota).isEmpty)
        let segundo = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(70_000), name: "B", categoryId: categoria.id)
        let cruces = try store.budgetCrossings(spaceId: space.id, newEntry: segundo, calendar: bogota)
        #expect(cruces.map(\.budget.categoryId) == [categoria.id])
        #expect(cruces.first?.level == .cerca)
        let ingreso = try ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: pesos(9_000_000), name: "Sueldo")
        #expect(try store.budgetCrossings(spaceId: space.id, newEntry: ingreso, calendar: bogota).isEmpty)
    }

    @Test("Metas con aportes y retiros")
    func metas() throws {
        let viaje = try store.addGoal(spaceId: space.id, name: " Viaje ", targetMinor: pesos(5_000_000))
        try store.contribute(to: viaje, amountMinor: pesos(300_000))
        try store.contribute(to: viaje, amountMinor: -pesos(50_000))
        let aportes = try store.contributions(spaceId: space.id)
        let progreso = SavingsMath.progress(goal: viaje.record, contributions: aportes.map { (goalId: $0.goalId, amountMinor: $0.amountMinor) },
                                            productBalance: nil, now: .now, calendar: bogota)
        #expect(viaje.name == "Viaje")
        #expect(progreso.savedMinor == pesos(250_000))
        try store.deleteGoal(viaje)
        #expect(try store.goals(spaceId: space.id).isEmpty)
    }
}
