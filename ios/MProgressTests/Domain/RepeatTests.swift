import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct RepeatTests {
    private let quincena = Cycle.quincenal(.standard)
    private let ancla = CycleAnchor(day: 1, month: 1)

    private func siguiente(_ date: Date, _ cycle: Cycle) -> String? {
        CycleMath.next(after: date, cycle: cycle, anchor: ancla, calendar: bogota).map(dia)
    }

    private func otra(_ unit: RepeatUnit, _ count: String) -> RepeatDraft {
        var draft = RepeatDraft(choice: .otra)
        draft.unit = unit
        draft.countText = count
        return draft
    }

    @Test("Quincenal del 15 y último día: 15, 30, 15 y 31 de diciembre")
    func quincenaNoviembre() {
        #expect(siguiente(fecha(2026, 11, 7), quincena) == "2026-11-15")
        #expect(siguiente(fecha(2026, 11, 15), quincena) == "2026-11-30")
        #expect(siguiente(fecha(2026, 11, 30), quincena) == "2026-12-15")
        #expect(siguiente(fecha(2026, 12, 15), quincena) == "2026-12-31")
    }

    @Test("Quincenal en febrero cae el 28, o el 29 en bisiesto, y vuelve al 15 de marzo")
    func quincenaFebrero() {
        #expect(siguiente(fecha(2027, 2, 15), quincena) == "2027-02-28")
        #expect(siguiente(fecha(2027, 2, 28), quincena) == "2027-03-15")
        #expect(siguiente(fecha(2028, 2, 15), quincena) == "2028-02-29")
        let treinta = Cycle.quincenal(QuincenaDays(first: 15, second: 30))
        #expect(siguiente(fecha(2027, 2, 15), treinta) == "2027-02-28")
        #expect(siguiente(fecha(2027, 1, 15), treinta) == "2027-01-30")
        #expect(siguiente(fecha(2027, 1, 30), treinta) == "2027-02-15")
    }

    @Test("Quincenal de otros días: 5 y 20, y 28 y 10 en desorden")
    func quincenaOtrosDias() {
        let cinco = Cycle.quincenal(QuincenaDays(first: 5, second: 20))
        #expect(siguiente(fecha(2026, 11, 1), cinco) == "2026-11-05")
        #expect(siguiente(fecha(2026, 11, 12), cinco) == "2026-11-20")
        #expect(siguiente(fecha(2026, 11, 25), cinco) == "2026-12-05")
        let desorden = Cycle.quincenal(QuincenaDays(first: 28, second: 10))
        #expect(siguiente(fecha(2026, 11, 12), desorden) == "2026-11-28")
        #expect(siguiente(fecha(2026, 11, 28), desorden) == "2026-12-10")
    }

    @Test("Quincenal conserva la hora y cuenta dos veces en el mes")
    func quincenaDosVecesAlMes() {
        let next = CycleMath.next(after: fecha(2026, 11, 7, 18), cycle: quincena, anchor: ancla, calendar: bogota)!
        #expect(bogota.component(.hour, from: next) == 18)
        let fechas = CycleMath.occurrences(from: fecha(2026, 11, 15), through: fecha(2027, 1, 31, 23), cycle: quincena, anchor: ancla, calendar: bogota)
        #expect(fechas.map(dia) == ["2026-11-15", "2026-11-30", "2026-12-15", "2026-12-31", "2027-01-15", "2027-01-31"])
        #expect(FixedMath.monthlyEquivalent(amountMinor: pesos(2_000_000), cycle: quincena) == pesos(4_000_000))
    }

    @Test("Quincenal con cuotas y fecha final no cobra de más")
    func quincenaConFin() {
        let item = RecurringRecord(kind: .ingreso, name: "Sueldo", amountMinor: pesos(1_500_000), cycle: quincena, nextDate: fecha(2026, 11, 15),
                                   anchor: CycleAnchor(day: 15, month: 11), totalCount: 3, paidCount: 0)
        #expect(RecurringEnd.dates(of: item, through: fecha(2027, 6, 1), calendar: bogota).map(dia) == ["2026-11-15", "2026-11-30", "2026-12-15"])
        var conFecha = item
        conFecha.totalCount = nil
        conFecha.endDate = fecha(2026, 12, 20)
        #expect(RecurringEnd.dates(of: conFecha, through: fecha(2027, 6, 1), calendar: bogota).map(dia) == ["2026-11-15", "2026-11-30", "2026-12-15"])
        let pago = RecurringEnd.afterPayment(nextDate: fecha(2026, 11, 30), cycle: quincena, anchor: ancla, endDate: nil, totalCount: 3, paidCount: 2, calendar: bogota)
        #expect(dia(pago.nextDate!) == "2026-12-15")
        #expect(pago.finished)
    }

    @Test("Quincenal hoy anota el movimiento y deja el siguiente día")
    func quincenaAddPlan() {
        let plan = AddPlan.decide(cycle: quincena, date: fecha(2026, 11, 15), now: fecha(2026, 11, 15, 20), calendar: bogota)
        #expect(plan.entryDate.map(dia) == "2026-11-15")
        #expect(plan.recurringNext.map(dia) == "2026-11-30")
        #expect(dia(QuincenaMath.onOrAfter(fecha(2026, 11, 7), days: .standard, calendar: bogota)) == "2026-11-15")
        #expect(dia(QuincenaMath.onOrAfter(fecha(2026, 11, 30), days: .standard, calendar: bogota)) == "2026-11-30")
        #expect(dia(QuincenaMath.onOrAfter(fecha(2027, 2, 28), days: .standard, calendar: bogota)) == "2027-02-28")
    }

    @Test("Quincenal se guarda con sus dos días y los datos de antes siguen iguales")
    func quincenaGuardado() {
        let days = QuincenaDays(first: 5, second: 20)
        let cycle = Cycle.quincenal(days)
        #expect(cycle.rawValue == "quincenal")
        #expect(cycle.firstDay == 5)
        #expect(cycle.secondDay == 20)
        #expect(Cycle(rawValue: "quincenal", firstDay: 5, secondDay: 20) == cycle)
        #expect(Cycle(rawValue: "quincenal") == .quincenal(.standard))
        #expect(Cycle.mensual.firstDay == nil)
        #expect(Cycle(rawValue: "mensual", intervalMonths: 1) == .mensual)
    }

    @Test("Días de la quincena: textos, opciones y sugerencia")
    func quincenaDias() {
        #expect(QuincenaDays.standard.title == "15 y último día")
        #expect(QuincenaDays(first: 15, second: 30).title == "15 y 30")
        #expect(QuincenaDays(first: 28, second: 10).title == "10 y 28")
        #expect(QuincenaDays.secondChoices(first: 15) == [1, 2, 28, 29, 30, 31])
        #expect(QuincenaDays.secondChoices(first: 20).contains(31) == false)
        #expect(QuincenaDays.suggestedSecond(first: 5) == 20)
        #expect(QuincenaDays.suggestedSecond(first: 16) == 31)
        #expect(QuincenaDays.suggestedSecond(first: 25) == 10)
        #expect(QuincenaDays.standard.withFirst(5) == QuincenaDays(first: 5, second: 31))
        #expect(QuincenaDays.standard.withFirst(20) == QuincenaDays(first: 20, second: 5))
        #expect(QuincenaDays.standard.withFirst(40).first == 28)
        #expect(QuincenaDays.standard.withSecond(20) == .standard)
        #expect(QuincenaDays.standard.withSecond(30) == QuincenaDays(first: 15, second: 30))
        #expect(QuincenaDays.standard.isValid)
        #expect(!QuincenaDays(first: 15, second: 20).isValid)
    }

    @Test("Una vez se llama así en toda la app")
    func unaVez() {
        #expect(Cycle.puntual.title == "Una vez")
        #expect(RepeatChoice.allCases.map(\.title) == ["Una vez", "Semanal", "Quincenal", "Mensual", "Otra"])
        #expect(Cycle.quincenal(.standard).title == "Quincenal")
        #expect(Cycle.cadaDias(14).title == "Cada 2 semanas")
        #expect(Cycle.cadaMeses(24).title == "Cada 2 años")
        #expect(FixedMath.scheduleText(cycle: quincena, nextDate: fecha(2026, 11, 15), dateUnset: false, calendar: bogota) == "Quincenal · 15 y último día")
    }

    @Test("Otra: días, semanas, meses y años dan el ciclo justo")
    func otraMapeo() {
        #expect(otra(.dias, "10").cycle == .cadaDias(10))
        #expect(otra(.dias, "7").cycle == .semanal)
        #expect(otra(.dias, "15").cycle == .cadaDias(15))
        #expect(otra(.semanas, "1").cycle == .semanal)
        #expect(otra(.semanas, "2").cycle == .cadaDias(14))
        #expect(otra(.meses, "1").cycle == .mensual)
        #expect(otra(.meses, "3").cycle == .cadaMeses(3))
        #expect(otra(.meses, "12").cycle == .anual)
        #expect(otra(.anios, "1").cycle == .anual)
        #expect(otra(.anios, "2").cycle == .cadaMeses(24))
        #expect(RepeatDraft(choice: .unaVez).cycle == .puntual)
        #expect(RepeatDraft(choice: .semanal).cycle == .semanal)
        #expect(RepeatDraft(choice: .quincenal).cycle == .quincenal(.standard))
        #expect(RepeatDraft(choice: .mensual).cycle == .mensual)
    }

    @Test("Otra: valida el número con una pista y sugiere Quincenal para 15 días")
    func otraValidacion() {
        #expect(otra(.meses, "24").isValid)
        #expect(!otra(.meses, "25").isValid)
        #expect(otra(.meses, "25").hint == "Escribe de 1 a 24 meses")
        #expect(otra(.dias, "0").hint == "Escribe de 1 a 365 días")
        #expect(otra(.semanas, "53").hint == "Escribe de 1 a 52 semanas")
        #expect(otra(.anios, "3").hint == "Escribe de 1 a 2 años")
        #expect(!otra(.dias, "").isValid)
        #expect(otra(.dias, "366").cycle == .cadaDias(365))
        #expect(otra(.dias, "15").tip == "¿Quincenal? Usa Quincenal para 15 y 30")
        #expect(otra(.dias, "16").tip == nil)
        #expect(RepeatDraft(choice: .mensual).isValid)
    }

    @Test("Otra: atajos y resumen")
    func otraAtajos() {
        var draft = RepeatDraft(choice: .otra)
        #expect(draft.preset == .bimestral)
        draft.apply(.trimestral)
        #expect(draft.cycle == .cadaMeses(3))
        #expect(draft.preset == .trimestral)
        #expect(draft.title == "Trimestral")
        draft.apply(.anual)
        #expect(draft.cycle == .anual)
        #expect(RepeatPreset.allCases.map(\.title) == ["Cada 2 meses", "Trimestral", "Semestral", "Anual"])
        let tres = otra(.meses, "3")
        #expect(tres.summary(next: fecha(2027, 2, 7), calendar: bogota, now: fecha(2026, 11, 7)) == "Se repite cada 3 meses, el próximo es el 7 feb 2027")
        #expect(otra(.semanas, "1").summary(next: fecha(2026, 11, 14), calendar: bogota, now: fecha(2026, 11, 7)) == "Se repite cada semana, el próximo es el 14 nov")
        #expect(otra(.meses, "30").summary(next: nil, calendar: bogota, now: fecha(2026, 11, 7)) == nil)
        #expect(otra(.dias, "10").title == "Cada 10 días")
        #expect(otra(.anios, "2").title == "Cada 2 años")
    }

    @Test("Editar: cada ciclo guardado vuelve a su opción")
    func desdeCiclo() {
        for cycle in [Cycle.puntual, .semanal, .mensual, .anual, .cadaDias(10), .cadaDias(14), .cadaMeses(3), .cadaMeses(24), .quincenal(QuincenaDays(first: 5, second: 20))] {
            #expect(RepeatDraft(cycle: cycle).cycle == cycle)
        }
        #expect(RepeatDraft(cycle: .anual).choice == .otra)
        #expect(RepeatDraft(cycle: .cadaDias(14)).unit == .semanas)
        #expect(RepeatDraft(cycle: .cadaMeses(24)).unit == .anios)
    }
}
