import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct MonthIntervalTests {
    private func siguiente(_ date: Date, _ cycle: Cycle, ancla: CycleAnchor) -> String? {
        CycleMath.next(after: date, cycle: cycle, anchor: ancla, calendar: bogota).map(dia)
    }

    private func fijo(_ cycle: Cycle, next: Date, ancla: CycleAnchor? = nil, endDate: Date? = nil, total: Int? = nil, paid: Int = 0) -> RecurringRecord {
        RecurringRecord(kind: .gasto, name: "Seguro", amountMinor: pesos(300_000), cycle: cycle, nextDate: next,
                        anchor: ancla ?? CycleAnchor(date: next, calendar: bogota), endDate: endDate, totalCount: total, paidCount: paid)
    }

    @Test("Cada 3 meses suma tres meses y conserva el día")
    func trimestral() {
        let ancla = CycleAnchor(day: 15, month: 1)
        #expect(siguiente(fecha(2026, 1, 15), .cadaMeses(3), ancla: ancla) == "2026-04-15")
        #expect(siguiente(fecha(2026, 11, 15), .cadaMeses(3), ancla: ancla) == "2027-02-15")
    }

    @Test("Del 31 de enero cada mes: 28 de febrero, luego vuelve al 31 de marzo")
    func finDeMesVuelveAlAncla() {
        let ancla = CycleAnchor(day: 31, month: 1)
        let fechas = CycleMath.occurrences(from: fecha(2026, 1, 31), through: fecha(2026, 5, 31, 23), cycle: .mensual, anchor: ancla, calendar: bogota)
        #expect(fechas.map(dia) == ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31"])
    }

    @Test("Del 31 de enero cada 2 meses en bisiesto: 31 mar, 31 may; y desde el 30 nov cae el 29 feb")
    func cadaDosMesesBisiesto() {
        let ancla = CycleAnchor(day: 31, month: 1)
        #expect(siguiente(fecha(2028, 1, 31), .cadaMeses(2), ancla: ancla) == "2028-03-31")
        #expect(siguiente(fecha(2027, 12, 31), .cadaMeses(2), ancla: ancla) == "2028-02-29")
        #expect(siguiente(fecha(2028, 2, 29), .cadaMeses(2), ancla: ancla) == "2028-04-30")
        #expect(siguiente(fecha(2028, 4, 30), .cadaMeses(2), ancla: ancla) == "2028-06-30")
        #expect(siguiente(fecha(2028, 6, 30), .cadaMeses(2), ancla: ancla) == "2028-08-31")
    }

    @Test("Semestral del 31 de agosto cae el 28 de febrero y vuelve al 31 de agosto")
    func semestral() {
        let ancla = CycleAnchor(day: 31, month: 8)
        #expect(siguiente(fecha(2026, 8, 31), .cadaMeses(6), ancla: ancla) == "2027-02-28")
        #expect(siguiente(fecha(2027, 2, 28), .cadaMeses(6), ancla: ancla) == "2027-08-31")
        #expect(siguiente(fecha(2027, 8, 31), .cadaMeses(6), ancla: ancla) == "2028-02-29")
    }

    @Test("Cada 24 meses pasa dos años y respeta el 29 de febrero")
    func cadaVeinticuatro() {
        let ancla = CycleAnchor(day: 29, month: 2)
        #expect(siguiente(fecha(2028, 2, 29), .cadaMeses(24), ancla: ancla) == "2030-02-28")
        #expect(siguiente(fecha(2030, 2, 28), .cadaMeses(24), ancla: ancla) == "2032-02-29")
    }

    @Test("1 mes es mensual, 12 es anual y se queda entre 1 y 24")
    func normaliza() {
        #expect(Cycle.months(1) == .mensual)
        #expect(Cycle.months(0) == .mensual)
        #expect(Cycle.months(12) == .anual)
        #expect(Cycle.months(3) == .cadaMeses(3))
        #expect(Cycle.months(99) == .cadaMeses(24))
        #expect(Cycle.months(3).intervalMonths == 3)
        #expect(Cycle.mensual.intervalMonths == 1)
        #expect(Cycle.semanal.intervalMonths == 1)
        #expect(Cycle.cadaMeses(3).isMonthly)
        #expect(!Cycle.anual.isMonthly)
    }

    @Test("Se guarda como mensual con sus meses y los datos viejos siguen siendo mensuales")
    func guardado() {
        #expect(Cycle.cadaMeses(6).rawValue == "mensual")
        #expect(Cycle(rawValue: "mensual", intervalMonths: 6) == .cadaMeses(6))
        #expect(Cycle(rawValue: "mensual") == .mensual)
        #expect(Cycle(rawValue: "mensual", intervalMonths: 1) == .mensual)
        #expect(Cycle(rawValue: "mensual", intervalMonths: nil) == .mensual)
        #expect(Cycle(rawValue: "anual", intervalMonths: 3) == .anual)
    }

    @Test("Opciones: mensual, cada 2 meses, trimestral, semestral, anual y cada N meses")
    func opciones() {
        #expect(MonthInterval.allCases.map(\.title) == ["Mensual", "Cada 2 meses", "Trimestral", "Semestral", "Anual", "Cada N meses"])
        #expect(MonthInterval.of(months: 3) == .trimestral)
        #expect(MonthInterval.of(months: 4) == .otro)
        #expect(MonthInterval.cycle(.trimestral, months: 9) == .cadaMeses(3))
        #expect(MonthInterval.cycle(.otro, months: 9) == .cadaMeses(9))
        #expect(MonthInterval.cycle(.anual, months: 9) == .anual)
        #expect(Cycle.cadaMeses(4).title == "Cada 4 meses")
        #expect(Cycle.cadaMeses(6).title == "Semestral")
        #expect(FixedMath.scheduleText(cycle: .cadaMeses(3), nextDate: fecha(2026, 12, 5), dateUnset: false, calendar: bogota) == "Trimestral · el 5")
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(300_000), cycle: .cadaMeses(3)) == pesos(100_000))
    }

    @Test("Un trimestral solo cuenta en los meses en que se cobra")
    func soloEnSusMeses() {
        let seguro = fijo(.cadaMeses(3), next: fecha(2026, 12, 10))
        let meses = Forecast.nextMonths(4, recurring: [seguro], now: fecha(2026, 11, 6), calendar: bogota)
        #expect(meses.map(\.fixedExpenseMinor) == [pesos(300_000), 0, 0, pesos(300_000)])
        let noviembre = BalanceCalculator.monthSummary(entries: [], recurring: [seguro], now: fecha(2026, 11, 6), calendar: bogota)
        #expect(noviembre.pendingFixedMinor == 0)
        let diciembre = BalanceCalculator.monthSummary(entries: [], recurring: [seguro], now: fecha(2026, 12, 2), calendar: bogota)
        #expect(diciembre.pendingFixedMinor == pesos(300_000))
    }

    @Test("Cada 2 meses con cuotas y con fecha final no cobra de más")
    func conFin() {
        let cuotas = fijo(.cadaMeses(2), next: fecha(2026, 11, 20), total: 3, paid: 1)
        let fechas = RecurringEnd.dates(of: cuotas, through: fecha(2027, 12, 31), calendar: bogota)
        #expect(fechas.map(dia) == ["2026-11-20", "2027-01-20"])
        let hasta = fijo(.cadaMeses(2), next: fecha(2026, 11, 20), endDate: fecha(2027, 3, 20))
        #expect(RecurringEnd.dates(of: hasta, through: fecha(2027, 12, 31), calendar: bogota).map(dia) == ["2026-11-20", "2027-01-20", "2027-03-20"])
        let pago = RecurringEnd.afterPayment(nextDate: fecha(2027, 3, 20), cycle: .cadaMeses(2), anchor: hasta.anchor, endDate: hasta.endDate,
                                             totalCount: nil, paidCount: 2, calendar: bogota)
        #expect(pago.nextDate.map(dia) == "2027-05-20")
        #expect(pago.finished)
    }

    @Test("Agregar un trimestral con fecha pasada salta al siguiente cobro")
    func agregarPasado() {
        let plan = AddPlan.decide(cycle: .cadaMeses(3), date: fecha(2026, 9, 6), now: fecha(2026, 11, 6), calendar: bogota)
        #expect(plan.entryDate.map(dia) == "2026-09-06")
        #expect(plan.recurringNext.map(dia) == "2026-12-06")
        #expect(plan.elapsed == 1)
    }

    @Test("Próximos cargos y calendario muestran el trimestral en su mes")
    func proximosYCalendario() {
        let seguro = fijo(.cadaMeses(3), next: fecha(2026, 11, 10))
        let proximos = BalanceCalculator.upcoming(recurring: [seguro], now: fecha(2026, 11, 6), calendar: bogota, kind: nil, limit: 5)
        #expect(proximos.map { dia($0.date) }.first == "2026-11-10")
        let diciembre = CalendarMath.days(month: fecha(2026, 12, 1), entries: [], recurring: [seguro], now: fecha(2026, 11, 6), calendar: bogota)
        #expect(diciembre.values.allSatisfy { $0.charges.isEmpty })
        let febrero = CalendarMath.days(month: fecha(2027, 2, 1), entries: [], recurring: [seguro], now: fecha(2026, 11, 6), calendar: bogota)
        #expect(febrero.values.contains { $0.hasCharge })
    }
}
