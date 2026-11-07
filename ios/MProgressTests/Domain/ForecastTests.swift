import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

/// "Este mes" y "Los próximos 3 meses" sin predicciones inventadas (PLAN_F12B Paso 4).
struct ForecastTests {
    let ahora = fecha(2026, 11, 10, 10)

    private func gasto(_ units: Int64, _ date: Date, fijo: UUID? = nil) -> EntryRecord {
        EntryRecord(kind: .gasto, amountMinor: pesos(units), occurredAt: date, recurringId: fijo)
    }

    private func fijo(_ name: String, _ kind: EntryKind, _ units: Int64, _ next: Date, total: Int? = nil, paid: Int = 0) -> RecurringRecord {
        RecurringRecord(kind: kind, name: name, amountMinor: pesos(units), cycle: .mensual, nextDate: next,
                        anchor: CycleAnchor(date: next, calendar: bogota), totalCount: total, paidCount: paid)
    }

    @Test("Este mes: entró, por entrar, gastaste, fijos que faltan y te quedan igual que Inicio")
    func esteMes() {
        let entries = [
            EntryRecord(kind: .ingreso, amountMinor: pesos(2_000_000), occurredAt: fecha(2026, 11, 1)),
            gasto(136_600, fecha(2026, 11, 2)),
            gasto(10_000, fecha(2026, 11, 5)),
            gasto(100_000, fecha(2026, 11, 5), fijo: UUID()),
            gasto(900_000, fecha(2026, 10, 20)),
        ]
        let recurring = [fijo("Renta", .gasto, 1_000_000, fecha(2026, 11, 15)), fijo("Prima", .ingreso, 300_000, fecha(2026, 11, 28))]
        let facts = Forecast.monthFacts(entries: entries, recurring: recurring, now: ahora, calendar: bogota)
        #expect(facts.enteredMinor == pesos(2_000_000))
        #expect(facts.pendingIncomeMinor == pesos(300_000))
        #expect(facts.spentMinor == pesos(246_600))
        #expect(facts.pendingFixedMinor == pesos(1_000_000))
        #expect(facts.remainingMinor == pesos(1_053_400))
        #expect(!facts.isOver)
        let summary = BalanceCalculator.monthSummary(entries: entries, recurring: recurring, now: ahora, calendar: bogota)
        #expect(facts.remainingMinor == summary.remainingMinor)
        #expect(Forecast.overText(remainingMinor: facts.remainingMinor, currency: .cop) == nil)
    }

    @Test("Si Te quedan ya es negativo: Te pasaste $ X de lo que entra este mes")
    func tePasaste() {
        // El caso de Juan: sueldo fijo de $ 2 por error y gastos reales del mes.
        let entries = [gasto(136_600, fecha(2026, 11, 2)), gasto(10_000, fecha(2026, 11, 5)), gasto(5_000, fecha(2026, 11, 6))]
        let sueldo = fijo("Sueldo", .ingreso, 2, fecha(2026, 11, 30))
        let facts = Forecast.monthFacts(entries: entries, recurring: [sueldo], now: fecha(2026, 11, 6, 10), calendar: bogota)
        #expect(facts.remainingMinor == pesos(2 - 151_600))
        #expect(facts.isOver)
        #expect(Forecast.overText(remainingMinor: facts.remainingMinor, currency: .cop) == "Te pasaste $ 151.598 de lo que entra este mes")
    }

    @Test("Los próximos 3 meses: solo fijos, con cuotas, y lo que quedaría")
    func proximos() {
        let recurring = [
            fijo("Sueldo", .ingreso, 3_000_000, fecha(2026, 12, 1)),
            fijo("Renta", .gasto, 1_000_000, fecha(2026, 11, 15)),
            fijo("Celular", .gasto, 150_000, fecha(2026, 12, 10), total: 3, paid: 1),
        ]
        let months = Forecast.nextMonths(3, recurring: recurring, now: ahora, calendar: bogota)
        #expect(months.map { dia($0.month) } == ["2026-12-01", "2027-01-01", "2027-02-01"])
        #expect(months[0].fixedIncomeMinor == pesos(3_000_000))
        #expect(months[0].fixedExpenseMinor == pesos(1_150_000))
        #expect(months[0].netMinor == pesos(1_850_000))
        #expect(months[1].fixedExpenseMinor == pesos(1_150_000))
        #expect(months[2].fixedExpenseMinor == pesos(1_000_000))
        #expect(months[2].netMinor == pesos(2_000_000))
        #expect(Forecast.netText(months[0], currency: .cop) == "Quedan $ 1.850.000")
        #expect(Forecast.nextMonthsNote == "Solo cuenta tus pagos fijos")
    }

    @Test("Sin fijos de ingreso, lo que quedaría es negativo")
    func proximosNegativo() {
        let months = Forecast.nextMonths(1, recurring: [fijo("Renta", .gasto, 500_000, fecha(2026, 12, 5))], now: ahora, calendar: bogota)
        #expect(months[0].netMinor == -pesos(500_000))
        #expect(Forecast.netText(months[0], currency: .cop) == "Quedan − $ 500.000")
    }

    @Test("Un fijo con fecha final no cuenta después de ella")
    func fechaFinal() {
        var curso = fijo("Curso", .gasto, 200_000, fecha(2026, 12, 5))
        curso.endDate = fecha(2026, 12, 31)
        let months = Forecast.nextMonths(3, recurring: [curso], now: ahora, calendar: bogota)
        #expect(months.map(\.fixedExpenseMinor) == [pesos(200_000), 0, 0])
    }
}
