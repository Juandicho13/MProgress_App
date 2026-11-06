import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct CycleTests {
    private func siguiente(_ date: Date, _ cycle: Cycle, ancla: CycleAnchor? = nil) -> String? {
        let anchor = ancla ?? CycleAnchor(date: date, calendar: bogota)
        return CycleMath.next(after: date, cycle: cycle, anchor: anchor, calendar: bogota).map(dia)
    }

    @Test("Mensual normal suma un mes")
    func mensual() {
        #expect(siguiente(fecha(2026, 11, 8), .mensual) == "2026-12-08")
        #expect(siguiente(fecha(2026, 12, 8), .mensual) == "2027-01-08")
    }

    @Test("Mensual del 31 cae el 30 en abril y vuelve al 31 en mayo")
    func mensualFinDeMes() {
        let ancla = CycleAnchor(day: 31, month: 3)
        #expect(siguiente(fecha(2026, 3, 31), .mensual, ancla: ancla) == "2026-04-30")
        #expect(siguiente(fecha(2026, 4, 30), .mensual, ancla: ancla) == "2026-05-31")
    }

    @Test("Mensual del 31 de enero cae el 28 de febrero, y el 29 en bisiesto")
    func mensualFebrero() {
        let ancla = CycleAnchor(day: 31, month: 1)
        #expect(siguiente(fecha(2026, 1, 31), .mensual, ancla: ancla) == "2026-02-28")
        #expect(siguiente(fecha(2028, 1, 31), .mensual, ancla: ancla) == "2028-02-29")
        #expect(siguiente(fecha(2026, 2, 28), .mensual, ancla: ancla) == "2026-03-31")
    }

    @Test("Anual del 29 de febrero cae el 28 en años no bisiestos y vuelve al 29")
    func anualBisiesto() {
        let ancla = CycleAnchor(day: 29, month: 2)
        #expect(siguiente(fecha(2028, 2, 29), .anual, ancla: ancla) == "2029-02-28")
        #expect(siguiente(fecha(2031, 2, 28), .anual, ancla: ancla) == "2032-02-29")
    }

    @Test("Semanal suma 7 días y cada N días suma N")
    func semanalYCadaDias() {
        #expect(siguiente(fecha(2026, 12, 28), .semanal) == "2027-01-04")
        #expect(siguiente(fecha(2026, 11, 20), .cadaDias(15)) == "2026-12-05")
    }

    @Test("Puntual no se repite")
    func puntual() {
        #expect(siguiente(fecha(2026, 11, 8), .puntual) == nil)
        #expect(!Cycle.puntual.repeats)
        #expect(Cycle.mensual.repeats)
    }

    @Test("La hora se conserva al pasar de mes")
    func conservaHora() {
        let next = CycleMath.next(after: fecha(2026, 1, 15, 18), cycle: .mensual, anchor: CycleAnchor(day: 15, month: 1), calendar: bogota)!
        #expect(bogota.component(.hour, from: next) == 18)
    }

    @Test("Ocurrencias de un semanal dentro de un mes")
    func ocurrencias() {
        let dates = CycleMath.occurrences(from: fecha(2026, 11, 2), through: fecha(2026, 11, 30, 23), cycle: .semanal, anchor: CycleAnchor(day: 2, month: 11), calendar: bogota)
        #expect(dates.map(dia) == ["2026-11-02", "2026-11-09", "2026-11-16", "2026-11-23", "2026-11-30"])
    }

    @Test("El ciclo se guarda y se recupera como texto")
    func rawValue() {
        #expect(Cycle(rawValue: "mensual") == .mensual)
        #expect(Cycle(rawValue: "otra", intervalDays: 10) == .cadaDias(10))
        #expect(Cycle(rawValue: "desconocido") == .puntual)
        #expect(Cycle.cadaDias(10).rawValue == "otra")
        #expect(Cycle.cadaDias(10).intervalDays == 10)
        #expect(Cycle.cadaDias(10).title == "Cada 10 días")
    }

    @Test("Urgencia: hoy, pronto y próximas")
    func urgencia() {
        let ahora = fecha(2026, 11, 5, 10)
        #expect(Urgency.of(due: fecha(2026, 11, 5, 23), now: ahora, calendar: bogota) == .hoy)
        #expect(Urgency.of(due: fecha(2026, 11, 3), now: ahora, calendar: bogota) == .hoy)
        #expect(Urgency.of(due: fecha(2026, 11, 6, 1), now: ahora, calendar: bogota) == .pronto)
        #expect(Urgency.of(due: fecha(2026, 11, 8), now: ahora, calendar: bogota) == .pronto)
        #expect(Urgency.of(due: fecha(2026, 11, 9), now: ahora, calendar: bogota) == .proximas)
    }
}
