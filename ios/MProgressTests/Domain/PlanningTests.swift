import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct ReminderPlannerTests {
    let renta = RecurringRecord(kind: .gasto, name: "Renta", amountMinor: pesos(2_275_000), cycle: .mensual,
                                nextDate: fecha(2026, 11, 15), anchor: CycleAnchor(day: 15, month: 11))

    @Test("Avisa 3 días antes a la hora pedida y el mismo día")
    func diasAntes() {
        let regla = ReminderRule(recurringId: renta.id, daysBefore: 3, atMinutes: 540, sameDay: true)
        let plan = ReminderPlanner.plan(recurring: [renta], rules: [regla], currency: .cop, now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 40)
        #expect(plan.count == 4)
        #expect(dia(plan[0].fireDate) == "2026-11-12")
        #expect(bogota.component(.hour, from: plan[0].fireDate) == 9)
        #expect(plan[0].body == "Renta vence en 3 días · $ 2.275.000")
        #expect(dia(plan[1].fireDate) == "2026-11-15")
        #expect(plan[1].body.hasPrefix("Renta vence hoy"))
        #expect(dia(plan[2].fireDate) == "2026-12-12")
        #expect(Set(plan.map(\.id)).count == 4)
    }

    @Test("No programa avisos ya pasados ni de pagos sin regla o pausados")
    func filtra() {
        let regla = ReminderRule(recurringId: renta.id, daysBefore: 7, atMinutes: 540, sameDay: false)
        var pausado = renta
        pausado.id = UUID()
        pausado.active = false
        let plan = ReminderPlanner.plan(recurring: [renta, pausado], rules: [regla, ReminderRule(recurringId: pausado.id, daysBefore: 1, atMinutes: 0, sameDay: false)],
                                        currency: .cop, now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 30)
        #expect(plan.map { dia($0.fireDate) } == ["2026-12-08"])
    }

    @Test("Avisa los pagos de tarjeta con su regla")
    func tarjetas() {
        let oro = ProductRecord(kind: .credito, name: "Oro", balanceMinor: 0, balanceAt: fecha(2026, 11, 1), dueDay: 20)
        let plan = ReminderPlanner.plan(recurring: [], rules: [], cards: [oro], cardRule: (daysBefore: 2, atMinutes: 480),
                                        currency: .cop, now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 45)
        #expect(plan.map { dia($0.fireDate) } == ["2026-11-18", "2026-12-18"])
        #expect(plan[0].title == "Pago de Oro")
    }

    @Test("Textos de hora y de días")
    func textos() {
        #expect(ReminderPlanner.timeText(540) == "9:00 a. m.")
        #expect(ReminderPlanner.timeText(0) == "12:00 a. m.")
        #expect(ReminderPlanner.timeText(19 * 60 + 30) == "7:30 p. m.")
        #expect(ReminderPlanner.body(name: "Sueldo", kind: .ingreso, amount: "$ 1", days: 1) == "Sueldo llega mañana · $ 1")
    }
}

struct BudgetMathTests {
    let mercado = UUID()
    let salidas = UUID()

    var gastos: [EntryRecord] {
        [
            EntryRecord(kind: .gasto, amountMinor: pesos(420_000), occurredAt: fecha(2026, 11, 3), name: "Éxito", categoryId: mercado),
            EntryRecord(kind: .gasto, amountMinor: pesos(265_000), occurredAt: fecha(2026, 11, 5), name: "Bar", categoryId: salidas),
            EntryRecord(kind: .gasto, amountMinor: pesos(15_000), occurredAt: fecha(2026, 11, 6), name: "Taxi"),
            EntryRecord(kind: .gasto, amountMinor: pesos(99_000), occurredAt: fecha(2026, 10, 6), name: "Viejo", categoryId: salidas),
            EntryRecord(kind: .ingreso, amountMinor: pesos(9_000_000), occurredAt: fecha(2026, 11, 1), name: "Sueldo"),
        ]
    }

    @Test("Estado por límite: total primero y niveles al 80 y 100 %")
    func estados() {
        let total = BudgetRecord(categoryId: nil, limitMinor: pesos(1_500_000))
        let m = BudgetRecord(categoryId: mercado, limitMinor: pesos(500_000))
        let s = BudgetRecord(categoryId: salidas, limitMinor: pesos(250_000))
        let estados = BudgetMath.statuses(budgets: [m, s, total], entries: gastos, now: fecha(2026, 11, 10), calendar: bogota)
        #expect(estados.map(\.budget.categoryId) == [nil, salidas, mercado])
        #expect(estados[0].spentMinor == pesos(700_000))
        #expect(estados[0].level == .bien)
        #expect(estados[1].level == .superado)
        #expect(estados[1].remainingMinor == -pesos(15_000))
        #expect(estados[2].level == .cerca)
    }

    @Test("Lo que queda por día cuenta hoy")
    func porDia() {
        // 10 de noviembre: quedan 21 días contando hoy.
        #expect(BudgetMath.dailyAllowance(remainingMinor: pesos(210_000), now: fecha(2026, 11, 10), calendar: bogota) == pesos(10_000))
        #expect(BudgetMath.dailyAllowance(remainingMinor: -5, now: fecha(2026, 11, 10), calendar: bogota) == 0)
    }

    @Test("Solo se avisa cuando se cruza un umbral")
    func cruces() {
        let m = BudgetRecord(categoryId: mercado, limitMinor: pesos(500_000))
        let antes = BudgetMath.statuses(budgets: [m], entries: gastos, now: fecha(2026, 11, 10), calendar: bogota)
        let otro = EntryRecord(kind: .gasto, amountMinor: pesos(100_000), occurredAt: fecha(2026, 11, 9), name: "D1", categoryId: mercado)
        let despues = BudgetMath.statuses(budgets: [m], entries: gastos + [otro], now: fecha(2026, 11, 10), calendar: bogota)
        #expect(BudgetMath.crossings(before: antes, after: despues).map(\.level) == [.superado])
        #expect(BudgetMath.crossings(before: despues, after: despues).isEmpty)
    }
}

struct SavingsMathTests {
    @Test("Progreso con aportes, con cajita ligada y aporte mensual necesario")
    func progreso() {
        let viaje = GoalRecord(name: "Viaje", targetMinor: pesos(5_000_000), targetDate: fecha(2027, 6, 1))
        let aportes = [(goalId: viaje.id, amountMinor: pesos(2_400_000)), (goalId: UUID(), amountMinor: pesos(1))]
        let p = SavingsMath.progress(goal: viaje, contributions: aportes, productBalance: nil, now: fecha(2026, 11, 10), calendar: bogota)
        #expect(p.savedMinor == pesos(2_400_000))
        #expect(abs(p.ratio - 0.48) < 0.0001)
        #expect(p.missingMinor == pesos(2_600_000))
        #expect(p.monthlyNeededMinor == pesos(325_000))

        let ligada = SavingsMath.progress(goal: viaje, contributions: aportes, productBalance: pesos(6_000_000), now: fecha(2026, 11, 10), calendar: bogota)
        #expect(ligada.ratio == 1)
        #expect(ligada.monthlyNeededMinor == nil)
    }

    @Test("Meses que quedan y lo ahorrado este mes")
    func meses() {
        #expect(SavingsMath.monthsBetween(fecha(2026, 11, 10), fecha(2027, 6, 1), calendar: bogota) == 8)
        #expect(SavingsMath.monthsBetween(fecha(2026, 11, 10), fecha(2026, 10, 1), calendar: bogota) == 0)
        let aportes = [(occurredAt: fecha(2026, 11, 2), amountMinor: pesos(300_000)), (occurredAt: fecha(2026, 10, 2), amountMinor: pesos(1))]
        #expect(SavingsMath.savedThisMonth(aportes, now: fecha(2026, 11, 10), calendar: bogota) == pesos(300_000))
    }
}
