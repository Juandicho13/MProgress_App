import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct AddPlanTests {
    let ahora = fecha(2026, 11, 5, 22)

    @Test("Puntual de hoy: solo el movimiento")
    func puntualHoy() {
        let plan = AddPlan.decide(cycle: .puntual, date: fecha(2026, 11, 5, 8), now: ahora, calendar: bogota)
        #expect(plan.entryDate != nil)
        #expect(plan.recurringNext == nil)
    }

    @Test("Puntual futuro: pago pendiente, sin movimiento")
    func puntualFuturo() {
        let plan = AddPlan.decide(cycle: .puntual, date: fecha(2026, 11, 20), now: ahora, calendar: bogota)
        #expect(plan.entryDate == nil)
        #expect(plan.recurringNext.map(dia) == "2026-11-20")
    }

    @Test("Mensual de hoy: movimiento y el fijo desde el próximo mes")
    func mensualHoy() {
        let plan = AddPlan.decide(cycle: .mensual, date: fecha(2026, 11, 5, 9), now: ahora, calendar: bogota)
        #expect(plan.entryDate.map(dia) == "2026-11-05")
        #expect(plan.recurringNext.map(dia) == "2026-12-05")
    }

    @Test("Mensual con fecha vieja: el fijo salta hasta después de hoy")
    func mensualViejo() {
        let plan = AddPlan.decide(cycle: .mensual, date: fecha(2026, 8, 10), now: ahora, calendar: bogota)
        #expect(plan.entryDate.map(dia) == "2026-08-10")
        #expect(plan.recurringNext.map(dia) == "2026-11-10")
    }

    @Test("Semanal futuro: solo el fijo")
    func semanalFuturo() {
        let plan = AddPlan.decide(cycle: .semanal, date: fecha(2026, 11, 9), now: ahora, calendar: bogota)
        #expect(plan.entryDate == nil)
        #expect(plan.recurringNext.map(dia) == "2026-11-09")
    }

    @Test("Textos de vencimiento")
    func textos() {
        #expect(DueText.describe(fecha(2026, 11, 5, 23), now: ahora, calendar: bogota) == "Hoy")
        #expect(DueText.describe(fecha(2026, 11, 6), now: ahora, calendar: bogota) == "Mañana")
        #expect(DueText.describe(fecha(2026, 11, 11), now: ahora, calendar: bogota) == "En 6 días")
        #expect(DueText.describe(fecha(2026, 11, 3), now: ahora, calendar: bogota) == "Hace 2 días")
        #expect(DueText.describe(fecha(2026, 11, 4), now: ahora, calendar: bogota) == "Ayer")
        #expect(DueText.shortDate(fecha(2026, 12, 1), calendar: bogota, now: ahora) == "1 dic")
        #expect(DueText.shortDate(fecha(2027, 1, 8), calendar: bogota, now: ahora) == "8 ene 2027")
        #expect(DueText.monthName(ahora, calendar: bogota) == "noviembre")
    }
}
