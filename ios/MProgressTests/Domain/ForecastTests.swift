import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct ForecastTests {
    let ahora = fecha(2026, 11, 10, 10)

    private func gasto(_ units: Int64, _ date: Date, fijo: UUID? = nil) -> EntryRecord {
        EntryRecord(kind: .gasto, amountMinor: pesos(units), occurredAt: date, recurringId: fijo)
    }

    private func fijo(_ name: String, _ kind: EntryKind, _ units: Int64, _ next: Date, total: Int? = nil, paid: Int = 0) -> RecurringRecord {
        RecurringRecord(kind: kind, name: name, amountMinor: pesos(units), cycle: .mensual, nextDate: next,
                        anchor: CycleAnchor(date: next, calendar: bogota), totalCount: total, paidCount: paid)
    }

    @Test("Ritmo variable: gasto del mes sin pagos fijos entre el día del mes")
    func ritmo() {
        let entries = [
            gasto(300_000, fecha(2026, 11, 2)),
            gasto(200_000, fecha(2026, 11, 8)),
            gasto(100_000, fecha(2026, 11, 5), fijo: UUID()),
            gasto(900_000, fecha(2026, 10, 20)),
            EntryRecord(kind: .ingreso, amountMinor: pesos(2_000_000), occurredAt: fecha(2026, 11, 1)),
        ]
        #expect(Forecast.variablePace(entries: entries, now: ahora, calendar: bogota) == pesos(50_000))
        #expect(Forecast.variablePace(entries: [gasto(30_000, fecha(2026, 11, 1, 8))], now: fecha(2026, 11, 1, 20), calendar: bogota) == pesos(30_000))
    }

    @Test("Proyección: te quedan menos ritmo por días que faltan")
    func proyeccion() {
        let ingreso = EntryRecord(kind: .ingreso, amountMinor: pesos(2_000_000), occurredAt: fecha(2026, 11, 1))
        let bien = Forecast.endOfMonth(entries: [ingreso, gasto(500_000, fecha(2026, 11, 3))], recurring: [], now: ahora, calendar: bogota)
        #expect(bien.summary.remainingMinor == pesos(1_500_000))
        #expect(bien.summary.daysLeft == 20)
        #expect(bien.projectedMinor == pesos(500_000))
        #expect(!bien.isNegative)
        #expect(Forecast.alertText(projectedMinor: bien.projectedMinor, currency: .cop) == nil)

        let mal = Forecast.projectedEndOfMonth(entries: [ingreso, gasto(1_500_000, fecha(2026, 11, 3))], recurring: [], now: ahora, calendar: bogota)
        #expect(mal == -pesos(2_500_000))
        #expect(Forecast.alertText(projectedMinor: mal, currency: .cop) == "A este ritmo terminas el mes en − $ 2.500.000")
    }

    @Test("Los fijos que faltan del mes también bajan la proyección")
    func conFijos() {
        let ingreso = EntryRecord(kind: .ingreso, amountMinor: pesos(2_000_000), occurredAt: fecha(2026, 11, 1))
        let renta = fijo("Renta", .gasto, 1_000_000, fecha(2026, 11, 15))
        let result = Forecast.endOfMonth(entries: [ingreso, gasto(500_000, fecha(2026, 11, 3))], recurring: [renta], now: ahora, calendar: bogota)
        #expect(result.projectedMinor == -pesos(500_000))
    }

    @Test("Los próximos 3 meses: fijos con cuotas y promedio de los 3 meses con datos")
    func proximosConHistoria() {
        let entries = [
            gasto(900_000, fecha(2026, 7, 10)),
            gasto(300_000, fecha(2026, 8, 10)),
            gasto(600_000, fecha(2026, 10, 10)),
            gasto(500_000, fecha(2026, 11, 3)),
        ]
        let recurring = [
            fijo("Sueldo", .ingreso, 3_000_000, fecha(2026, 12, 1)),
            fijo("Renta", .gasto, 1_000_000, fecha(2026, 11, 15)),
            fijo("Celular", .gasto, 150_000, fecha(2026, 12, 10), total: 3, paid: 1),
        ]
        let months = Forecast.nextMonths(3, entries: entries, recurring: recurring, now: ahora, calendar: bogota)
        #expect(months.map { dia($0.month) } == ["2026-12-01", "2027-01-01", "2027-02-01"])
        #expect(months[0].fixedIncomeMinor == pesos(3_000_000))
        #expect(months[0].fixedExpenseMinor == pesos(1_150_000))
        #expect(months[0].variableMinor == pesos(600_000))
        #expect(months[0].variableFromHistory)
        #expect(months[0].netMinor == pesos(1_250_000))
        #expect(months[1].fixedExpenseMinor == pesos(1_150_000))
        #expect(months[2].fixedExpenseMinor == pesos(1_000_000))
    }

    @Test("Sin meses anteriores con datos, el variable es el ritmo de este mes por los días del mes")
    func proximosSinHistoria() {
        let months = Forecast.nextMonths(3, entries: [gasto(500_000, fecha(2026, 11, 3))], recurring: [], now: ahora, calendar: bogota)
        #expect(months.map(\.variableMinor) == [pesos(1_550_000), pesos(1_550_000), pesos(1_400_000)])
        #expect(!months[0].variableFromHistory)
        #expect(months[0].netMinor == -pesos(1_550_000))
    }

    @Test("Un fijo con fecha final no cuenta después de ella")
    func fechaFinal() {
        var curso = fijo("Curso", .gasto, 200_000, fecha(2026, 12, 5))
        curso.endDate = fecha(2026, 12, 31)
        let months = Forecast.nextMonths(3, entries: [], recurring: [curso], now: ahora, calendar: bogota)
        #expect(months.map(\.fixedExpenseMinor) == [pesos(200_000), 0, 0])
    }
}
