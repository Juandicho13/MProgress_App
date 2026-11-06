import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct AddEntryTests {
    let container: ModelContainer
    let space: Space

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    }

    private func modelo(_ nombre: String, _ teclas: [String], ciclo: AddEntryModel.CycleChoice, fecha: Date) -> AddEntryModel {
        let model = AddEntryModel(kind: .gasto, cycle: ciclo)
        model.name = "  \(nombre) "
        for key in teclas { model.amount.press(key) }
        model.date = fecha
        return model
    }

    @Test("No se puede guardar sin nombre o sin monto")
    func validacion() {
        let model = AddEntryModel()
        #expect(!model.canSave)
        model.name = "Taxi"
        #expect(!model.canSave)
        model.amount.press("5")
        #expect(model.canSave)
    }

    @Test("Un gasto puntual de hoy crea solo el movimiento, con el nombre limpio")
    func puntual() throws {
        let model = modelo("Taxi", ["1", "8", "0", "0", "0"], ciclo: .puntual, fecha: fecha(2026, 11, 5, 10))
        let entry = try model.save(context: container.mainContext, spaceId: space.id, now: fecha(2026, 11, 5, 22), calendar: bogota)
        #expect(entry?.name == "Taxi")
        #expect(entry?.amountMinor == pesos(18_000))
        #expect(try container.mainContext.fetch(FetchDescriptor<Recurring>()).isEmpty)
    }

    @Test("Un mensual de hoy crea el movimiento y el fijo enlazados")
    func mensualHoy() throws {
        let model = modelo("Netflix", ["4", "5", "5", "0", "0"], ciclo: .mensual, fecha: fecha(2026, 11, 5, 9))
        let entry = try model.save(context: container.mainContext, spaceId: space.id, now: fecha(2026, 11, 5, 22), calendar: bogota)
        let recurring = try container.mainContext.fetch(FetchDescriptor<Recurring>())
        #expect(recurring.count == 1)
        #expect(entry?.recurringId == recurring.first?.id)
        #expect(recurring.first.map { dia($0.nextDate) } == "2026-12-05")
    }

    @Test("Un mensual futuro crea solo el fijo")
    func mensualFuturo() throws {
        let model = modelo("Renta", ["2", "2", "7", "5", "0", "0", "0"], ciclo: .mensual, fecha: fecha(2026, 12, 1))
        let entry = try model.save(context: container.mainContext, spaceId: space.id, now: fecha(2026, 11, 5, 22), calendar: bogota)
        #expect(entry == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<Recurring>()).count == 1)
    }

    @Test("El resumen del ciclo describe el cobro")
    func resumenCiclo() {
        let model = AddEntryModel(cycle: .mensual)
        model.date = fecha(2026, 11, 8)
        #expect(model.cycleSummary(calendar: bogota) == "Mensual · el 8 de cada mes")
        model.cycleChoice = .otra
        model.everyDays = 10
        #expect(model.cycleSummary(calendar: bogota) == "Cada 10 días")
    }
}
