import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct OnboardingPlanTests {
    let ahora = fecha(2026, 11, 5, 22)

    @Test("Si el sueldo ya llegó este mes, se registra y el fijo empieza el próximo")
    func sueldoYaPagado() {
        let plan = OnboardingPlan.salaryPlan(payday: 1, now: ahora, calendar: bogota)
        #expect(plan.registerOn.map(dia) == "2026-11-01")
        #expect(dia(plan.nextDate) == "2026-12-01")
    }

    @Test("Si el sueldo llega hoy, cuenta como pagado")
    func sueldoHoy() {
        let plan = OnboardingPlan.salaryPlan(payday: 5, now: ahora, calendar: bogota)
        #expect(plan.registerOn.map(dia) == "2026-11-05")
        #expect(dia(plan.nextDate) == "2026-12-05")
    }

    @Test("Si el sueldo todavía no llega, queda pendiente este mes")
    func sueldoPendiente() {
        let plan = OnboardingPlan.salaryPlan(payday: 30, now: ahora, calendar: bogota)
        #expect(plan.registerOn == nil)
        #expect(dia(plan.nextDate) == "2026-11-30")
    }

    @Test("Día 30 en febrero cae el último día")
    func sueldoFebrero() {
        let plan = OnboardingPlan.salaryPlan(payday: 30, now: fecha(2027, 2, 10), calendar: bogota)
        #expect(dia(plan.nextDate) == "2027-02-28")
    }

    @Test("Próxima fecha de un fijo: este mes si no ha pasado, si no el siguiente")
    func proximaFecha() {
        #expect(dia(OnboardingPlan.nextDate(day: 6, from: ahora, calendar: bogota)) == "2026-11-06")
        #expect(dia(OnboardingPlan.nextDate(day: 5, from: ahora, calendar: bogota)) == "2026-11-05")
        #expect(dia(OnboardingPlan.nextDate(day: 1, from: ahora, calendar: bogota)) == "2026-12-01")
        #expect(dia(OnboardingPlan.nextDate(day: 31, from: fecha(2026, 11, 20), calendar: bogota)) == "2026-11-30")
    }

    @Test("Las sugerencias tienen ids únicos y montos positivos")
    func sugerencias() {
        let ids = FixedSuggestion.defaults.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(FixedSuggestion.defaults.allSatisfy { $0.units > 0 && (1...31).contains($0.day) })
        #expect(Interest.allCases.count == 8)
        #expect(Interest.defaultSelection.count == 5)
    }
}
