import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct HistoryStoreTests {
    let container: ModelContainer
    let space: Space
    let ledger: LedgerStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        ledger = LedgerStore(context: container.mainContext, calendar: bogota)
    }

    private func vivos() throws -> [Entry] {
        try ledger.entries(spaceId: space.id)
    }

    @Test("Editar cambia el movimiento y lo deja pendiente de sincronizar")
    func editar() throws {
        let entry = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(18_000), name: "Taxi", occurredAt: fecha(2026, 11, 3))
        entry.syncStateRaw = SyncState.synced.rawValue
        let model = AddEntryModel(editing: entry)
        #expect(model.isEditing)
        #expect(model.amount.display == "18.000")
        model.name = "Taxi aeropuerto"
        model.amount.deleteLast()
        model.notes = "  Vuelo  "
        try model.save(context: container.mainContext, spaceId: space.id, now: fecha(2026, 11, 5), calendar: bogota)
        #expect(entry.name == "Taxi aeropuerto")
        #expect(entry.amountMinor == pesos(1_800))
        #expect(entry.notes == "Vuelo")
        #expect(entry.syncStateRaw == SyncState.pending.rawValue)
        #expect(try vivos().count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<Recurring>()).isEmpty)
    }

    @Test("Duplicar copia el movimiento hoy sin enlazarlo al pago fijo")
    func duplicar() throws {
        let fijo = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Netflix", amountMinor: pesos(45_500), cycle: .mensual, nextDate: fecha(2026, 11, 5))
        let pagado = try ledger.markPaid(fijo, on: fecha(2026, 11, 5))
        pagado.notes = "Plan estándar"
        let copia = try ledger.duplicate(pagado, on: fecha(2026, 11, 6))
        #expect(copia.id != pagado.id)
        #expect(copia.recurringId == nil)
        #expect(copia.notes == "Plan estándar")
        #expect(dia(copia.occurredAt) == "2026-11-06")
        #expect(try vivos().count == 2)
    }

    @Test("Borrar y deshacer deja todo como estaba")
    func borrarDeshacer() throws {
        let entry = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(84_300), name: "Mercado")
        try ledger.softDelete(entry)
        #expect(try vivos().isEmpty)
        try ledger.restore(entry)
        #expect(try vivos().map(\.name) == ["Mercado"])
    }

    @Test("Marcar pagado desde el calendario mueve la fecha y deshacer la regresa")
    func pagarDeshacer() throws {
        let fijo = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Gimnasio", amountMinor: pesos(20_000), cycle: .semanal, nextDate: fecha(2026, 11, 6))
        let antes = fijo.nextDate
        let entry = try ledger.markPaid(fijo, on: fecha(2026, 11, 6))
        #expect(dia(fijo.nextDate) == "2026-11-13")

        let mes = CalendarMath.days(month: fecha(2026, 11, 1), entries: try vivos().map(\.record), recurring: [fijo.record],
                                    now: fecha(2026, 11, 6), calendar: bogota)
        #expect(mes[bogota.startOfDay(for: fecha(2026, 11, 6))]?.hasExpense == true)
        #expect(mes[bogota.startOfDay(for: fecha(2026, 11, 6))]?.hasCharge == false)

        try ledger.undoPaid(fijo, entry: entry, previousNext: antes, wasActive: true)
        #expect(dia(fijo.nextDate) == "2026-11-06")
        #expect(try vivos().isEmpty)
    }

    @Test("Un pago puntual marcado queda inactivo y deshacer lo reactiva")
    func puntualDeshacer() throws {
        let fijo = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "SOAT", amountMinor: pesos(500_000), cycle: .puntual, nextDate: fecha(2026, 11, 20))
        let entry = try ledger.markPaid(fijo, on: fecha(2026, 11, 6))
        #expect(!fijo.active)
        try ledger.undoPaid(fijo, entry: entry, previousNext: fecha(2026, 11, 20), wasActive: true)
        #expect(fijo.active)
    }
}

@MainActor
struct FixedStoreTests {
    @Test("Poner fecha a un fijo sin fecha lo vuelve a avisar")
    func ponerFecha() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        let ledger = LedgerStore(context: container.mainContext, calendar: bogota)
        let item = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Internet", amountMinor: pesos(95_000), cycle: .mensual, nextDate: fecha(2026, 12, 1))
        item.dateUnset = true
        #expect(BalanceCalculator.upcoming(recurring: [item.record], now: fecha(2026, 11, 20), calendar: bogota, kind: nil, limit: 10).isEmpty)

        try ledger.updateRecurring(item, kind: .gasto, name: "Internet Claro", amountMinor: pesos(99_000), cycle: .mensual,
                                   nextDate: fecha(2026, 11, 25), productId: nil, categoryId: nil, active: true)
        #expect(!item.dateUnset)
        #expect(item.anchorDay == 25)
        #expect(item.name == "Internet Claro")
        #expect(BalanceCalculator.upcoming(recurring: [item.record], now: fecha(2026, 11, 20), calendar: bogota, kind: nil, limit: 10).count == 1)
    }
}
