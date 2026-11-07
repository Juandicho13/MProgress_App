import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

@Suite("Límites y ahorro en Dinero")
struct PlanningSummaryTests {
    private func status(_ limit: Int64, _ spent: Int64) -> BudgetStatus {
        BudgetStatus(budget: BudgetRecord(categoryId: UUID(), limitMinor: limit), spentMinor: spent)
    }

    @Test("Límites: vacío, pasados, cerca y al día")
    func budgets() {
        #expect(PlanningSummary.budgets([]) == "Sin límites")
        #expect(PlanningSummary.budgets([status(100, 120), status(100, 10)]) == "2 límites · 1 pasado")
        #expect(PlanningSummary.budgets([status(100, 120), status(100, 100)]) == "2 límites · 2 pasados")
        #expect(PlanningSummary.budgets([status(100, 85)]) == "1 límite · 1 cerca")
        #expect(PlanningSummary.budgets([status(100, 10)]) == "1 límite · al día")
    }

    @Test("Metas: vacío, porcentaje redondeado hacia abajo y sin pasar de cada meta")
    func goals() {
        #expect(PlanningSummary.goals([]) == "Sin metas")
        let una = GoalProgress(goal: GoalRecord(name: "Viaje", targetMinor: 1000), savedMinor: 459)
        #expect(PlanningSummary.goals([una]) == "1 meta · 45%")
        let llena = GoalProgress(goal: GoalRecord(name: "Moto", targetMinor: 1000), savedMinor: 5000)
        #expect(PlanningSummary.goals([una, llena]) == "2 metas · 72%")
    }
}
