import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct BalanceTests {
    let ahora = fecha(2026, 11, 5, 10)

    private func fijo(_ name: String, _ kind: EntryKind, _ units: Int64, _ next: Date, _ cycle: Cycle = .mensual, active: Bool = true) -> RecurringRecord {
        RecurringRecord(kind: kind, name: name, amountMinor: pesos(units), cycle: cycle, nextDate: next, anchor: CycleAnchor(date: next, calendar: bogota), active: active)
    }

    private func mov(_ kind: EntryKind, _ units: Int64, _ date: Date, categoria: UUID? = nil, producto: UUID? = nil) -> EntryRecord {
        EntryRecord(kind: kind, amountMinor: pesos(units), occurredAt: date, categoryId: categoria, productId: producto)
    }

    @Test("Te quedan: sueldo cobrado menos gastos y fijos que faltan")
    func teQuedan() {
        let entries = [
            mov(.ingreso, 2_200_000, fecha(2026, 11, 1)),
            mov(.gasto, 179_000, fecha(2026, 11, 2)),
            mov(.gasto, 50_000, fecha(2026, 10, 30)),
        ]
        let recurring = [
            fijo("Gimnasio", .gasto, 119_900, fecha(2026, 11, 6)),
            fijo("Sueldo", .ingreso, 2_200_000, fecha(2026, 12, 1)),
            fijo("Renta", .gasto, 2_275_000, fecha(2026, 12, 1)),
        ]
        let summary = BalanceCalculator.monthSummary(entries: entries, recurring: recurring, now: ahora, calendar: bogota)
        #expect(summary.expectedIncomeMinor == pesos(2_200_000))
        #expect(summary.spentMinor == pesos(179_000))
        #expect(summary.pendingFixedMinor == pesos(119_900))
        #expect(summary.remainingMinor == pesos(1_901_100))
        #expect(summary.daysLeft == 25)
    }

    @Test("El sueldo pendiente del mes cuenta como ingreso esperado")
    func ingresoPendiente() {
        let recurring = [fijo("Sueldo", .ingreso, 1_000_000, fecha(2026, 11, 28))]
        let summary = BalanceCalculator.monthSummary(entries: [], recurring: recurring, now: ahora, calendar: bogota)
        #expect(summary.expectedIncomeMinor == pesos(1_000_000))
        #expect(summary.remainingMinor == pesos(1_000_000))
        #expect(summary.spentRatio == 0)
    }

    @Test("Un semanal cuenta todas sus fechas que faltan en el mes")
    func semanalEnElMes() {
        let recurring = [fijo("Clase", .gasto, 20_000, fecha(2026, 11, 9), .semanal)]
        let summary = BalanceCalculator.monthSummary(entries: [], recurring: recurring, now: ahora, calendar: bogota)
        #expect(summary.pendingFixedMinor == pesos(80_000))
    }

    @Test("Los pagos fijos inactivos no cuentan")
    func inactivos() {
        let recurring = [fijo("Netflix", .gasto, 45_500, fecha(2026, 11, 8), active: false)]
        let summary = BalanceCalculator.monthSummary(entries: [], recurring: recurring, now: ahora, calendar: bogota)
        #expect(summary.pendingFixedMinor == 0)
        #expect(BalanceCalculator.upcoming(recurring: recurring, now: ahora, calendar: bogota).isEmpty)
    }

    @Test("Un pago vencido de un mes anterior no se suma a este mes")
    func vencidoAnterior() {
        let recurring = [fijo("Agua", .gasto, 60_000, fecha(2026, 10, 20))]
        let summary = BalanceCalculator.monthSummary(entries: [], recurring: recurring, now: ahora, calendar: bogota)
        #expect(summary.pendingFixedMinor == pesos(60_000))
    }

    @Test("La barra del mes llega como máximo a 1")
    func barraTope() {
        let entries = [mov(.ingreso, 100, fecha(2026, 11, 1)), mov(.gasto, 300, fecha(2026, 11, 2))]
        let summary = BalanceCalculator.monthSummary(entries: entries, recurring: [], now: ahora, calendar: bogota)
        #expect(summary.spentRatio == 1)
        #expect(summary.remainingMinor == pesos(-200))
    }

    @Test("Próximos cargos ordenados con su urgencia")
    func proximos() {
        let recurring = [
            fijo("Renta", .gasto, 2_275_000, fecha(2026, 12, 1)),
            fijo("Gimnasio", .gasto, 119_900, fecha(2026, 11, 6)),
            fijo("Música", .gasto, 9_000, fecha(2026, 11, 12)),
            fijo("Sueldo", .ingreso, 2_200_000, fecha(2026, 12, 1)),
        ]
        let list = BalanceCalculator.upcoming(recurring: recurring, now: ahora, calendar: bogota)
        #expect(list.map(\.name) == ["Gimnasio", "Música", "Renta"])
        #expect(list.map(\.urgency) == [.pronto, .proximas, .proximas])
        #expect(list.first?.daysLeft == 1)
        #expect(BalanceCalculator.upcoming(recurring: recurring, now: ahora, calendar: bogota, kind: nil).count == 4)
    }

    @Test("Gasto por categoría de mayor a menor, sin ingresos")
    func porCategoria() {
        let deporte = UUID(), musica = UUID()
        let entries = [
            mov(.gasto, 119_900, fecha(2026, 11, 2), categoria: deporte),
            mov(.gasto, 9_000, fecha(2026, 11, 3), categoria: musica),
            mov(.gasto, 1_000, fecha(2026, 11, 4), categoria: musica),
            mov(.ingreso, 2_200_000, fecha(2026, 11, 1), categoria: musica),
            mov(.gasto, 5_000, fecha(2026, 11, 4)),
        ]
        let month = BalanceCalculator.monthInterval(containing: ahora, calendar: bogota)
        let result = BalanceCalculator.spendingByCategory(entries: entries, in: month)
        #expect(result.map(\.totalMinor) == [pesos(119_900), pesos(10_000), pesos(5_000)])
        #expect(result.first?.categoryId == deporte)
        #expect(result.last?.categoryId == nil)
    }

    @Test("Mes normal: mediana de los meses con gasto")
    func mesNormal() {
        let entries = [
            mov(.gasto, 100_000, fecha(2026, 8, 10)),
            mov(.gasto, 300_000, fecha(2026, 9, 10)),
            mov(.gasto, 200_000, fecha(2026, 10, 10)),
            mov(.gasto, 999_000, fecha(2026, 11, 2)),
        ]
        #expect(BalanceCalculator.normalMonth(entries: entries, now: ahora, calendar: bogota) == pesos(200_000))
        let pares = Array(entries.prefix(2))
        #expect(BalanceCalculator.normalMonth(entries: pares, now: ahora, calendar: bogota) == pesos(200_000))
        #expect(BalanceCalculator.normalMonth(entries: [], now: ahora, calendar: bogota) == nil)
    }

    @Test("Gastos de los últimos meses en orden")
    func ultimosMeses() {
        let entries = [mov(.gasto, 10, fecha(2026, 9, 1)), mov(.gasto, 30, fecha(2026, 10, 31, 23))]
        #expect(BalanceCalculator.monthlyExpenses(entries: entries, now: ahora, months: 3, calendar: bogota) == [0, pesos(10), pesos(30)])
    }
}

struct MoneyCalculatorTests {
    let referencia = fecha(2026, 11, 1, 0)

    @Test("Cuenta: el débito descuenta de su cuenta y los ingresos suman")
    func cuentaConDebito() {
        let cuenta = ProductRecord(kind: .cuenta, name: "Ahorros", balanceMinor: pesos(1_000_000), balanceAt: referencia)
        let debito = ProductRecord(kind: .debito, name: "Débito", balanceMinor: 0, balanceAt: referencia, parentProductId: cuenta.id)
        let entries = [
            EntryRecord(kind: .gasto, amountMinor: pesos(84_300), occurredAt: fecha(2026, 11, 3), productId: debito.id),
            EntryRecord(kind: .gasto, amountMinor: pesos(10_000), occurredAt: fecha(2026, 11, 4), productId: cuenta.id),
            EntryRecord(kind: .ingreso, amountMinor: pesos(200_000), occurredAt: fecha(2026, 11, 4), productId: cuenta.id),
            EntryRecord(kind: .gasto, amountMinor: pesos(999), occurredAt: fecha(2026, 10, 30), productId: cuenta.id),
        ]
        let saldo = MoneyCalculator.currentBalance(of: cuenta, products: [cuenta, debito], entries: entries, transfers: [])
        #expect(saldo == pesos(1_105_700))
    }

    @Test("Crédito: los gastos suben la deuda y pagar la tarjeta la baja")
    func credito() {
        let cuenta = ProductRecord(kind: .cuenta, name: "Ahorros", balanceMinor: pesos(500_000), balanceAt: referencia)
        let tarjeta = ProductRecord(kind: .credito, name: "Oro", balanceMinor: pesos(1_000_000), balanceAt: referencia)
        let entries = [EntryRecord(kind: .gasto, amountMinor: pesos(81_900), occurredAt: fecha(2026, 11, 2), productId: tarjeta.id)]
        let pago = TransferRecord(fromProductId: cuenta.id, toProductId: tarjeta.id, amountMinor: pesos(300_000), occurredAt: fecha(2026, 11, 3))
        let products = [cuenta, tarjeta]
        #expect(MoneyCalculator.currentBalance(of: tarjeta, products: products, entries: entries, transfers: [pago]) == pesos(781_900))
        #expect(MoneyCalculator.currentBalance(of: cuenta, products: products, entries: entries, transfers: [pago]) == pesos(200_000))
        let net = MoneyCalculator.netWorth(products: products, entries: entries, transfers: [pago])
        #expect(net.have == pesos(200_000))
        #expect(net.owe == pesos(781_900))
        #expect(net.net == pesos(-581_900))
    }

    @Test("Mover a un bolsillo no cambia el patrimonio")
    func bolsillo() {
        let cuenta = ProductRecord(kind: .cuenta, name: "Nequi", balanceMinor: pesos(400_000), balanceAt: referencia)
        let bolsillo = ProductRecord(kind: .bolsillo, name: "Viaje", balanceMinor: 0, balanceAt: referencia)
        let paso = TransferRecord(fromProductId: cuenta.id, toProductId: bolsillo.id, amountMinor: pesos(150_000), occurredAt: fecha(2026, 11, 2))
        let net = MoneyCalculator.netWorth(products: [cuenta, bolsillo], entries: [], transfers: [paso])
        #expect(net.net == pesos(400_000))
        #expect(MoneyCalculator.currentBalance(of: bolsillo, products: [cuenta, bolsillo], entries: [], transfers: [paso]) == pesos(150_000))
    }

    @Test("Lo oculto no cuenta en el patrimonio")
    func oculto() {
        let visible = ProductRecord(kind: .cuenta, name: "A", balanceMinor: pesos(100), balanceAt: referencia)
        let oculta = ProductRecord(kind: .credito, name: "B", balanceMinor: pesos(900), balanceAt: referencia, hidden: true)
        #expect(MoneyCalculator.netWorth(products: [visible, oculta], entries: [], transfers: []).net == pesos(100))
    }

    @Test("Rendimiento mensual de una cajita al 12 % E.A.")
    func rendimiento() {
        let yield = MoneyCalculator.monthlyYield(balanceMinor: pesos(1_500_000), rateEA: 12)
        #expect(yield == 1_423_319)
        #expect(MoneyCalculator.monthlyYield(balanceMinor: pesos(1_000), rateEA: nil) == 0)
        #expect(MoneyCalculator.monthlyYield(balanceMinor: pesos(-5), rateEA: 10) == 0)
    }
}
