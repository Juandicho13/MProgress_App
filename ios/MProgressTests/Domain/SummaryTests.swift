import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct SummaryTests {
    let deporte = UUID()
    let musica = UUID()
    let hoy = fecha(2026, 11, 10)

    var movimientos: [EntryRecord] {
        [
            EntryRecord(kind: .ingreso, amountMinor: pesos(2_200_000), occurredAt: fecha(2026, 11, 1), name: "Sueldo"),
            EntryRecord(kind: .gasto, amountMinor: pesos(119_900), occurredAt: fecha(2026, 11, 2), name: "Gimnasio", categoryId: deporte),
            EntryRecord(kind: .gasto, amountMinor: pesos(9_000), occurredAt: fecha(2026, 11, 8), name: "Spotify", categoryId: musica),
            EntryRecord(kind: .gasto, amountMinor: pesos(50_000), occurredAt: fecha(2026, 10, 1), name: "Tenis", categoryId: deporte),
            EntryRecord(kind: .gasto, amountMinor: pesos(30_000), occurredAt: fecha(2026, 10, 20), name: "Cine"),
            EntryRecord(kind: .gasto, amountMinor: pesos(100_000), occurredAt: fecha(2026, 9, 5), name: "Mercado"),
        ]
    }

    @Test("Los periodos cubren meses completos hasta el fin del mes actual")
    func periodos() {
        let tres = SummaryPeriod.meses(3).interval(now: hoy, calendar: bogota)
        #expect(dia(tres.start) == "2026-09-01")
        #expect(dia(tres.end) == "2026-12-01")
        #expect(dia(SummaryPeriod.esteMes.interval(now: hoy, calendar: bogota).start) == "2026-11-01")
        let libre = SummaryPeriod.personalizado(start: fecha(2026, 11, 5), end: fecha(2026, 10, 3)).interval(now: hoy, calendar: bogota)
        #expect(dia(libre.start) == "2026-10-03")
        #expect(dia(libre.end) == "2026-11-06")
    }

    @Test("Ingresos y gastos por mes, con meses vacíos y totales")
    func flujos() {
        let intervalo = SummaryPeriod.meses(6).interval(now: hoy, calendar: bogota)
        let flujos = SummaryMath.monthlyFlows(SummaryMath.filter(movimientos, in: intervalo), in: intervalo, calendar: bogota)
        #expect(flujos.count == 6)
        #expect(dia(flujos[0].month) == "2026-06-01")
        #expect(flujos[0].spentMinor == 0)
        #expect(flujos[5].incomeMinor == pesos(2_200_000))
        #expect(flujos[5].spentMinor == pesos(128_900))
        let totales = SummaryMath.totals(flujos)
        #expect(totales.spent == pesos(308_900))
        #expect(totales.net == pesos(1_891_100))
    }

    @Test("El filtro por categoría deja solo esos gastos")
    func filtroCategoria() {
        let intervalo = SummaryPeriod.meses(3).interval(now: hoy, calendar: bogota)
        let solo = SummaryMath.filter(movimientos, in: intervalo, categories: [deporte])
        #expect(solo.map(\.name).sorted() == ["Gimnasio", "Tenis"])
        #expect(SummaryMath.activeCategories(movimientos, in: intervalo) == [deporte, musica])
    }

    @Test("Gasto acumulado por día y comparación con el mes pasado")
    func acumulado() {
        let serie = SummaryMath.cumulative(movimientos, month: hoy, upTo: hoy, calendar: bogota)
        #expect(serie.count == 10)
        #expect(serie[0].cumulativeMinor == 0)
        #expect(serie[1].cumulativeMinor == pesos(119_900))
        #expect(serie[9].cumulativeMinor == pesos(128_900))
        #expect(SummaryMath.cumulative(movimientos, month: fecha(2026, 10, 1), calendar: bogota).count == 31)

        let frente = SummaryMath.versusLastMonth(movimientos, now: hoy, calendar: bogota)
        #expect(frente.lastMonth == pesos(50_000))
        #expect(frente.difference == pesos(78_900))
    }

    @Test("Meses por encima del normal")
    func encimaNormal() {
        let resultado = SummaryMath.monthsAboveNormal(movimientos, now: hoy, calendar: bogota)
        #expect(resultado?.counted == 2)
        #expect(resultado?.above == 1)
        #expect(SummaryMath.monthsAboveNormal([], now: hoy, calendar: bogota) == nil)
    }

    @Test("El mes que viene suma los pagos fijos activos programados")
    func mesQueViene() {
        let netflix = RecurringRecord(kind: .gasto, name: "Netflix", amountMinor: pesos(45_500), cycle: .mensual,
                                      nextDate: fecha(2026, 11, 20), anchor: CycleAnchor(day: 20, month: 11))
        let gym = RecurringRecord(kind: .gasto, name: "Gym", amountMinor: pesos(20_000), cycle: .semanal,
                                  nextDate: fecha(2026, 11, 13), anchor: CycleAnchor(day: 13, month: 11))
        let sueldo = RecurringRecord(kind: .ingreso, name: "Sueldo", amountMinor: pesos(2_200_000), cycle: .mensual,
                                     nextDate: fecha(2026, 12, 1), anchor: CycleAnchor(day: 1, month: 12))
        let pausado = RecurringRecord(kind: .gasto, name: "X", amountMinor: pesos(1), cycle: .mensual,
                                      nextDate: fecha(2026, 12, 2), anchor: CycleAnchor(day: 2, month: 12), active: false)
        let plan = SummaryMath.nextMonth([netflix, gym, sueldo, pausado], now: hoy, calendar: bogota)
        // Diciembre: Netflix el 20, Gym los viernes 4, 11, 18 y 25, Sueldo el 1.
        #expect(plan.expenseMinor == pesos(45_500 + 4 * 20_000))
        #expect(plan.incomeMinor == pesos(2_200_000))
        #expect(plan.count == 6)
    }
}
