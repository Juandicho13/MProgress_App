import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct QuickNamesTests {
    private let mercado = UUID(uuidString: "0A000000-0000-4000-8000-000000000006")!
    private let salidas = UUID(uuidString: "0A000000-0000-4000-8000-000000000008")!

    private func gasto(_ name: String, _ day: Int, category: UUID? = nil, recurring: UUID? = nil) -> EntryRecord {
        EntryRecord(kind: .gasto, amountMinor: pesos(10_000), occurredAt: fecha(2026, 11, day), name: name,
                    categoryId: category, recurringId: recurring)
    }

    @Test("Los más usados primero; empate, el más reciente")
    func ranking() {
        let entries = [
            gasto("Taxi", 1), gasto("almuerzo", 2, category: salidas), gasto("Almuerzo", 3), gasto("Mercado", 4, category: mercado),
            gasto("Taxi", 5), gasto("Almuerzo", 6), gasto("Café", 7),
        ]
        let names = QuickNames.recent(entries, kind: .gasto)
        #expect(names.map(\.name) == ["Almuerzo", "Taxi", "Café", "Mercado"])
        // La categoría es la última que se le puso a ese nombre.
        #expect(names[0].categoryId == salidas)
        #expect(names[3].categoryId == mercado)
    }

    @Test("Sin nombres por defecto, pagos fijos ni el otro tipo; máximo 6")
    func filtros() {
        var entries = [gasto("Gasto rápido", 1), gasto("gasto", 1), gasto("  ", 1), gasto("Netflix", 2, recurring: UUID())]
        entries.append(EntryRecord(kind: .ingreso, amountMinor: pesos(5), occurredAt: fecha(2026, 11, 3), name: "Venta"))
        #expect(QuickNames.recent(entries, kind: .gasto).isEmpty)
        #expect(QuickNames.recent(entries, kind: .ingreso).map(\.name) == ["Venta"])
        let many = (1...9).map { gasto("Cosa \($0)", $0) }
        #expect(QuickNames.recent(many, kind: .gasto).count == QuickNames.limit)
        #expect(QuickNames.recent(many, kind: .gasto).first?.name == "Cosa 9")
    }

    @Test("Mientras escribes quedan las que empiezan igual y la categoría viaja con el nombre")
    func escribir() {
        let names = [QuickName(name: "Almuerzo", categoryId: salidas), QuickName(name: "Arriendo", categoryId: nil), QuickName(name: "Taxi", categoryId: nil)]
        #expect(QuickNames.matching(names, typed: "").count == 3)
        #expect(QuickNames.matching(names, typed: "a").map(\.name) == ["Almuerzo", "Arriendo"])
        #expect(QuickNames.matching(names, typed: "ALMUÉR").map(\.name) == ["Almuerzo"])
        #expect(QuickNames.matching(names, typed: "almuerzo").isEmpty)
        #expect(QuickNames.categoryId(for: "almuerzo ", in: names) == salidas)
        #expect(QuickNames.categoryId(for: "Otro", in: names) == nil)
    }

    @Test("Sin nombre queda el de siempre")
    func nombrePorDefecto() {
        #expect(QuickAddMath.name(kind: .gasto, concept: "") == "Gasto rápido")
        #expect(QuickAddMath.name(kind: .ingreso, concept: nil) == "Ingreso rápido")
        #expect(QuickAddMath.name(kind: .gasto, concept: " almuerzo ") == "Almuerzo")
    }
}
