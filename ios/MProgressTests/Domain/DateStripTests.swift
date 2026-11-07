import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct DateStripTests {
    @Test("La semana empieza el lunes aunque el teléfono diga domingo")
    func semanaDesdeLunes() {
        var domingo = bogota
        domingo.firstWeekday = 1
        #expect(DateStrip.week(of: fecha(2026, 11, 7), calendar: domingo).map(dia)
                == ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"])
        #expect(dia(DateStrip.weekStart(of: fecha(2026, 11, 8, 23), calendar: bogota)) == "2026-11-02")
        #expect(dia(DateStrip.weekStart(of: fecha(2026, 11, 2), calendar: bogota)) == "2026-11-02")
        #expect(DateStrip.mondayIndex(fecha(2026, 11, 7), calendar: bogota) == 5)
        #expect(DateStrip.weekdayInitials == ["L", "M", "M", "J", "V", "S", "D"])
    }

    @Test("El mes completo trae los días de los meses vecinos")
    func cuadriculaDelMes() {
        let noviembre = DateStrip.monthGrid(of: fecha(2026, 11, 7), calendar: bogota)
        #expect(noviembre.count == 42)
        #expect(dia(noviembre.first!.date) == "2026-10-26")
        #expect(!noviembre.first!.inMonth)
        #expect(noviembre.filter(\.inMonth).count == 30)
        #expect(dia(noviembre.last!.date) == "2026-12-06")
        let febrero = DateStrip.monthGrid(of: fecha(2027, 2, 10), calendar: bogota)
        #expect(febrero.count == 28)
        #expect(febrero.allSatisfy { $0.inMonth })
        let marzo = DateStrip.monthGrid(of: fecha(2027, 3, 10), calendar: bogota)
        #expect(marzo.count == 35)
        #expect(marzo.first!.day == 1)
    }

    @Test("Títulos en español")
    func textos() {
        #expect(DateStrip.monthLabel(fecha(2026, 11, 7), calendar: bogota) == "noviembre 2026")
        #expect(DateStrip.spokenDate(fecha(2026, 11, 7), calendar: bogota) == "sábado 7 de noviembre de 2026")
    }

    @Test("Se puede ir hasta dos años atrás o adelante, no más")
    func limites() {
        let ahora = fecha(2026, 11, 7, 10)
        #expect(DateStrip.isSelectable(fecha(2028, 11, 7), now: ahora, calendar: bogota))
        #expect(!DateStrip.isSelectable(fecha(2028, 11, 8), now: ahora, calendar: bogota))
        #expect(DateStrip.isSelectable(fecha(2024, 11, 7), now: ahora, calendar: bogota))
        #expect(!DateStrip.isSelectable(fecha(2024, 11, 6), now: ahora, calendar: bogota))
        #expect(DateStrip.canShiftWeek(from: fecha(2026, 11, 7), by: 1, now: ahora, calendar: bogota))
        #expect(!DateStrip.canShiftWeek(from: fecha(2028, 11, 7), by: 1, now: ahora, calendar: bogota))
        #expect(DateStrip.canShiftMonth(from: fecha(2028, 10, 7), by: 1, now: ahora, calendar: bogota))
        #expect(!DateStrip.canShiftMonth(from: fecha(2028, 11, 7), by: 1, now: ahora, calendar: bogota))
        #expect(!DateStrip.canShiftMonth(from: fecha(2024, 11, 7), by: -1, now: ahora, calendar: bogota))
        #expect(dia(DateStrip.clamp(fecha(2030, 1, 1), now: ahora, calendar: bogota)) == "2028-11-07")
        #expect(bogota.component(.hour, from: DateStrip.clamp(fecha(2020, 1, 1, 15), now: ahora, calendar: bogota)) == 15)
    }

    @Test("Mover semanas y meses")
    func mover() {
        #expect(dia(DateStrip.shiftWeek(fecha(2026, 11, 7), by: -1, calendar: bogota)) == "2026-10-31")
        #expect(dia(DateStrip.shiftMonth(fecha(2026, 11, 30), by: 3, calendar: bogota)) == "2027-02-01")
    }
}
