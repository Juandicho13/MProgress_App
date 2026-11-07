import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct HomeChecksTests {
    private func ingreso(_ name: String, _ minor: Int64, active: Bool = true) -> RecurringRecord {
        let next = fecha(2026, 11, 30)
        return RecurringRecord(kind: .ingreso, name: name, amountMinor: minor, cycle: .mensual, nextDate: next,
                               anchor: CycleAnchor(date: next, calendar: bogota), active: active)
    }

    @Test("Un sueldo de menos de 1.000 unidades se pregunta, salvo si ya se confirmó")
    func sueldoSospechoso() {
        let raro = ingreso("Sueldo", pesos(2))
        let bien = ingreso("Arriendo cobrado", pesos(1_500_000))
        let borde = ingreso("Intereses", pesos(1_000))
        let pausado = ingreso("Bono", pesos(5), active: false)
        var gasto = ingreso("Café", pesos(3))
        gasto.kind = .gasto
        let lista = [raro, bien, borde, pausado, gasto]
        #expect(IncomeCheck.suspicious(lista, currency: .cop, dismissed: []).map(\.id) == [raro.id])
        #expect(IncomeCheck.suspicious(lista, currency: .cop, dismissed: [raro.id]).isEmpty)
        // En pesos chilenos no hay centavos: 999 es sospechoso.
        #expect(IncomeCheck.suspicious([ingreso("Sueldo", 999)], currency: .clp, dismissed: []).count == 1)
    }

    @Test("Textos de la tarjeta del sueldo")
    func textos() {
        #expect(IncomeCheck.question(name: "Sueldo", amountMinor: pesos(2), currency: .cop) == "¿Tu sueldo es $ 2?")
        #expect(IncomeCheck.question(name: "SENA apoyo", amountMinor: pesos(2), currency: .cop) == "¿Tu SENA apoyo es $ 2?")
        #expect(IncomeCheck.fixTitle(amountMinor: pesos(2), factor: 1_000, currency: .cop) == "Es $ 2.000")
        #expect(IncomeCheck.fixTitle(amountMinor: pesos(2), factor: 1_000_000, currency: .cop) == "Es $ 2.000.000")
    }

    @Test("Los ingresos confirmados se guardan y se leen igual")
    func guardar() {
        let a = UUID(), b = UUID()
        let stored = IncomeCheck.stored([a, b])
        #expect(IncomeCheck.dismissed(from: stored) == [a, b])
        #expect(IncomeCheck.dismissed(from: "") == [])
        #expect(IncomeCheck.dismissed(from: "no-es-uuid,\(a.uuidString)") == [a])
    }

    @Test("Próximos cargos: 3 cerrados, hasta 20 abiertos")
    func plegar() {
        let items = Array(1...25)
        #expect(UpcomingFold.visible(items, expanded: false) == [1, 2, 3])
        #expect(UpcomingFold.visible(items, expanded: true).count == 20)
        #expect(UpcomingFold.toggleTitle(total: 3, expanded: false) == nil)
        #expect(UpcomingFold.toggleTitle(total: 5, expanded: false) == "Ver todos (5)")
        #expect(UpcomingFold.toggleTitle(total: 5, expanded: true) == "Ver menos")
    }
}
