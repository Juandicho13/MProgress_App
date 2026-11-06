import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct FixedTests {
    @Test("Peso al mes de cada ciclo")
    func equivalente() {
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(120_000), cycle: .mensual) == pesos(120_000))
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(12_000), cycle: .semanal) == pesos(52_000))
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(1_200_000), cycle: .anual) == pesos(100_000))
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(36_000), cycle: .cadaDias(15)) == pesos(73_000))
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(500_000), cycle: .puntual) == 0)
    }

    @Test("Totales: pausados aparte y los sin fecha sí suman")
    func totales() {
        let totals = FixedMath.totals([
            (kind: .gasto, amountMinor: pesos(2_000_000), cycle: .mensual, active: true, dateUnset: false),
            (kind: .gasto, amountMinor: pesos(45_500), cycle: .mensual, active: true, dateUnset: true),
            (kind: .gasto, amountMinor: pesos(16_900), cycle: .mensual, active: false, dateUnset: false),
            (kind: .ingreso, amountMinor: pesos(3_000_000), cycle: .mensual, active: true, dateUnset: false),
        ])
        #expect(totals.expenseMinor == pesos(2_045_500))
        #expect(totals.incomeMinor == pesos(3_000_000))
        #expect(totals.withoutDate == 1)
        #expect(totals.paused == 1)
    }

    @Test("Texto del ciclo")
    func texto() {
        #expect(FixedMath.scheduleText(cycle: .mensual, nextDate: fecha(2026, 11, 5), dateUnset: false, calendar: bogota) == "Mensual · el 5")
        #expect(FixedMath.scheduleText(cycle: .mensual, nextDate: fecha(2026, 11, 5), dateUnset: true, calendar: bogota) == "Mensual · sin fecha")
        #expect(FixedMath.scheduleText(cycle: .semanal, nextDate: fecha(2026, 11, 5), dateUnset: false, calendar: bogota) == "Semanal")
    }
}
