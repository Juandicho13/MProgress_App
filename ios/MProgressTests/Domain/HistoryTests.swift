import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct HistoryTests {
    let comida = UUID()

    var movimientos: [EntryRecord] {
        [
            EntryRecord(kind: .ingreso, amountMinor: pesos(3_000_000), occurredAt: fecha(2026, 11, 1), name: "Sueldo"),
            EntryRecord(kind: .gasto, amountMinor: pesos(84_300), occurredAt: fecha(2026, 11, 3, 13), name: "Mercado Éxito", categoryId: comida),
            EntryRecord(kind: .gasto, amountMinor: pesos(18_000), occurredAt: fecha(2026, 11, 3, 20), name: "Taxi"),
            EntryRecord(kind: .gasto, amountMinor: pesos(45_500), occurredAt: fecha(2026, 10, 28), name: "Netflix"),
        ]
    }

    @Test("Agrupa por mes, el más nuevo primero, con totales")
    func meses() {
        let meses = HistoryMath.months(movimientos, calendar: bogota)
        #expect(meses.count == 2)
        #expect(dia(meses[0].start) == "2026-11-01")
        #expect(meses[0].incomeMinor == pesos(3_000_000))
        #expect(meses[0].spentMinor == pesos(102_300))
        #expect(meses[0].netMinor == pesos(2_897_700))
        #expect(meses[0].entries.map(\.name) == ["Taxi", "Mercado Éxito", "Sueldo"])
        #expect(meses[1].spentMinor == pesos(45_500))
    }

    @Test("Agrupa por día con el neto del día")
    func dias() {
        let dias = HistoryMath.days(movimientos, calendar: bogota)
        #expect(dias.map { dia($0.day) } == ["2026-11-03", "2026-11-01", "2026-10-28"])
        #expect(dias[0].netMinor == -pesos(102_300))
    }

    @Test("Busca sin tildes, por categoría, notas y monto")
    func buscar() {
        let base = movimientos
        #expect(HistoryMath.filter(base, query: "exito").map(\.name) == ["Mercado Éxito"])
        #expect(HistoryMath.filter(base, query: "COMIDA", categoryName: { $0 == comida ? "Comida" : nil }).count == 1)
        #expect(HistoryMath.filter(base, query: "18.000").map(\.name) == ["Taxi"])
        let notas = [base[2].id: "Al aeropuerto"]
        #expect(HistoryMath.filter(base, query: "aeropuerto", notes: notas).map(\.name) == ["Taxi"])
        #expect(HistoryMath.filter(base, query: "  ").count == 4)
        #expect(HistoryMath.filter(base, query: "taxi netflix").isEmpty)
    }
}

struct CalendarMathTests {
    var lunes: Calendar {
        var calendar = bogota
        calendar.firstWeekday = 2
        return calendar
    }

    @Test("La cuadrícula de noviembre 2026 empieza el domingo 1 (semana desde el lunes)")
    func cuadricula() {
        let celdas = CalendarMath.grid(month: fecha(2026, 11, 15), calendar: lunes)
        #expect(celdas.prefix(6).allSatisfy { $0 == nil })
        #expect(celdas[6].map(dia) == "2026-11-01")
        #expect(celdas.count % 7 == 0)
        #expect(celdas.compactMap { $0 }.count == 30)
        #expect(CalendarMath.weekdaySymbols(calendar: lunes) == ["L", "M", "M", "J", "V", "S", "D"])
    }

    @Test("Los días muestran movimientos y cobros repetidos del mes")
    func dias() {
        let semanal = RecurringRecord(kind: .gasto, name: "Gimnasio", amountMinor: pesos(20_000), cycle: .semanal,
                                      nextDate: fecha(2026, 11, 6), anchor: CycleAnchor(day: 6, month: 11))
        let sueldo = RecurringRecord(kind: .ingreso, name: "Sueldo", amountMinor: pesos(3_000_000), cycle: .mensual,
                                     nextDate: fecha(2026, 12, 1), anchor: CycleAnchor(day: 1, month: 11))
        let pausado = RecurringRecord(kind: .gasto, name: "Spotify", amountMinor: pesos(16_900), cycle: .mensual,
                                      nextDate: fecha(2026, 11, 10), anchor: CycleAnchor(day: 10, month: 11), active: false)
        let taxi = EntryRecord(kind: .gasto, amountMinor: pesos(18_000), occurredAt: fecha(2026, 11, 3), name: "Taxi")
        let viejo = EntryRecord(kind: .gasto, amountMinor: pesos(1_000), occurredAt: fecha(2026, 10, 31), name: "Viejo")

        let dias = CalendarMath.days(month: fecha(2026, 11, 1), entries: [taxi, viejo], recurring: [semanal, sueldo, pausado],
                                     now: fecha(2026, 11, 5), calendar: bogota)
        let conCobro = dias.filter { $0.value.hasCharge }.keys.map(dia).sorted()
        #expect(conCobro == ["2026-11-06", "2026-11-13", "2026-11-20", "2026-11-27"])
        #expect(dias[bogota.startOfDay(for: fecha(2026, 11, 3))]?.hasExpense == true)
        #expect(dias.count == 5)
        #expect(CalendarMath.pendingMinor(dias) == pesos(80_000))
        #expect(dias[bogota.startOfDay(for: fecha(2026, 11, 6))]?.charges.first?.urgency == .pronto)
    }

    @Test("Moverse de mes cae siempre en el día 1")
    func moverMes() {
        #expect(dia(CalendarMath.add(months: 1, to: fecha(2026, 1, 31), calendar: bogota)) == "2026-02-01")
        #expect(dia(CalendarMath.add(months: -1, to: fecha(2026, 1, 15), calendar: bogota)) == "2025-12-01")
    }
}
