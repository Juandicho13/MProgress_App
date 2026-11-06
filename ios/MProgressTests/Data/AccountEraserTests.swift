import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct AccountEraserTests {
    @Test("Borrar cuenta deja la base como nueva: solo el espacio Personal y las categorías base")
    func borraTodo() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let space = try Seed.runIfNeeded(context: context, localUser: UUID())
        let ledger = LedgerStore(context: context, calendar: bogota)
        _ = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Renta", amountMinor: pesos(2_000_000), cycle: .mensual, nextDate: fecha(2026, 12, 1))
        context.insert(Institution(spaceId: space.id, name: "Bancolombia"))
        try context.save()
        UserDefaults.standard.set("claro", forKey: AppTheme.storageKey)

        try AccountEraser.eraseAll(context: context)

        #expect(try context.fetch(FetchDescriptor<Recurring>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Institution>()).isEmpty)
        let spaces = try context.fetch(FetchDescriptor<Space>())
        #expect(spaces.count == 1)
        #expect(spaces.first?.id != space.id)
        #expect(UserDefaults.standard.string(forKey: AppTheme.storageKey) == nil)
    }
}
