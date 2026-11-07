import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

// Los números salen de android/app/src/test/vectors/credit_card_vectors.py (el mismo modelo en Python con
// Decimal). Android (CreditCardTest.kt) prueba exactamente los mismos.

private func cd(_ y: Int, _ m: Int, _ d: Int) -> CardDay { CardDay(y, m, d) }

/// Tarjeta de ejemplo: cupo 5.000.000, corte 30, pago 15, 28,34 % E.A.
private let base = CardTerms(limitMinor: 500_000_000, cutDay: 30, dueDay: 15, rateEA: Decimal(string: "28.34")!)

/// Igual, con cuota de manejo de 32.900 y comisión por avance de 9.900.
private var conCuota: CardTerms {
    var t = base
    t.handlingFeeMinor = 3_290_000
    t.advanceFeeMinor = 990_000
    return t
}

/// Las compras del extracto de noviembre (V7).
private let compras: [CardPurchase] = [
    CardPurchase(name: "Mercado", amountMinor: 42_000_000, day: cd(2026, 11, 2)),
    CardPurchase(name: "Celular", amountMinor: 240_000_000, day: cd(2026, 11, 5), installments: 24),
    CardPurchase(name: "Tiquetes", amountMinor: 90_000_000, day: cd(2026, 11, 12), installments: 6),
    CardPurchase(name: "Avance", amountMinor: 30_000_000, day: cd(2026, 11, 20), installments: 2, kind: .avance),
    CardPurchase(name: "Cine", amountMinor: 8_500_000, day: cd(2026, 11, 30)),
    CardPurchase(name: "Despues del corte", amountMinor: 5_000_000, day: cd(2026, 12, 1)),
]

private func lineas(_ s: CardStatement) -> [[Int64]] {
    s.lines.map { [Int64($0.installment), Int64($0.installments), $0.capitalMinor, $0.interestMinor, $0.remainingAfterMinor] }
}

struct CreditCardTests {
    // MARK: Tasa y fechas

    @Test("Tasa mensual desde la E.A. con 20 decimales")
    func tasaMensual() {
        #expect(CreditCardMath.monthlyRate(rateEA: Decimal(string: "28.34")!) == Decimal(string: "0.02101040881997040579")!)
        #expect(CreditCardMath.monthlyRate(rateEA: Decimal(string: "24.36")!) == Decimal(string: "0.01833356684882571336")!)
        #expect(CreditCardMath.monthlyRate(rateEA: 100) == Decimal(string: "0.05946309435929526456")!)
        #expect(CreditCardMath.monthlyRate(rateEA: 12) == Decimal(string: "0.00948879293458297413")!)
        #expect(CreditCardMath.monthlyRate(rateEA: 0) == 0)
        #expect(CreditCardMath.roundingUnit(.cop) == 100)
        #expect(CreditCardMath.roundingUnit(.usd) == 1)
        #expect(CreditCardMath.roundToUnit(Decimal(string: "840449.99")!, unit: 100) == 840_400)
        #expect(CreditCardMath.roundToUnit(840_450, unit: 100) == 840_500)
    }

    @Test("Corte 29 a 31 cae el último día en meses cortos")
    func corteMesCorto() {
        #expect(CreditCardMath.cut(year: 2026, month: 2, cutDay: 31) == cd(2026, 2, 28))
        #expect(CreditCardMath.cut(year: 2028, month: 2, cutDay: 31) == cd(2028, 2, 29))
        #expect(CreditCardMath.cut(year: 2026, month: 4, cutDay: 31) == cd(2026, 4, 30))
        #expect(CreditCardMath.nextCut(after: cd(2027, 1, 31), cutDay: 31) == cd(2027, 2, 28))
        #expect(CreditCardMath.nextCut(after: cd(2027, 2, 28), cutDay: 31) == cd(2027, 3, 31))
        #expect(CreditCardMath.previousCut(before: cd(2026, 3, 30), cutDay: 30) == cd(2026, 2, 28))
    }

    @Test("Compra hasta el corte va en ese extracto, después en el siguiente")
    func extractoDeLaCompra() {
        #expect(CreditCardMath.statementCut(for: cd(2026, 11, 30), cutDay: 30) == cd(2026, 11, 30))
        #expect(CreditCardMath.statementCut(for: cd(2026, 12, 1), cutDay: 30) == cd(2026, 12, 30))
        #expect(CreditCardMath.statementCut(for: cd(2027, 1, 31), cutDay: 30) == cd(2027, 2, 28))
        #expect(CreditCardMath.statementCut(for: cd(2027, 2, 28), cutDay: 30) == cd(2027, 2, 28))
        #expect(CreditCardMath.statementCut(for: cd(2026, 12, 31), cutDay: 15) == cd(2027, 1, 15))
    }

    @Test("Fecha de pago después del corte, en el mismo mes o el siguiente")
    func fechaDePago() {
        #expect(CreditCardMath.dueDate(forCut: cd(2026, 11, 30), dueDay: 15) == cd(2026, 12, 15))
        #expect(CreditCardMath.dueDate(forCut: cd(2026, 11, 10), dueDay: 28) == cd(2026, 11, 28))
        #expect(CreditCardMath.dueDate(forCut: cd(2027, 1, 31), dueDay: 30) == cd(2027, 2, 28))
        #expect(CreditCardMath.dueDate(forCut: cd(2026, 11, 15), dueDay: 15) == cd(2026, 12, 15))
    }

    @Test("Días entre fechas y desde Date")
    func dias() {
        #expect(cd(2026, 9, 30).days(to: cd(2026, 10, 30)) == 30)
        #expect(cd(2028, 2, 28).days(to: cd(2028, 3, 1)) == 2)
        #expect(cd(2026, 12, 31).shiftingDays(1) == cd(2027, 1, 1))
        #expect(cd(2028, 3, 1).shiftingDays(-1) == cd(2028, 2, 29))
        #expect(cd(1970, 1, 1).ordinal == 0)
        #expect(CardDay(2026, 4, 31) == cd(2026, 4, 30))
        #expect(CardDay(fecha(2026, 11, 7, 23), calendar: bogota) == cd(2026, 11, 7))
        #expect(dia(cd(2026, 11, 7).date(calendar: bogota)) == "2026-11-07")
        #expect(cd(2026, 11, 7).description == "2026-11-07")
    }

    // MARK: Cuotas

    @Test("Compra a 12 cuotas con capital fijo")
    func doceCuotas() {
        let cost = CreditCardMath.purchaseCost(amountMinor: 120_000_000, installments: 12, day: cd(2026, 10, 20), terms: base)
        let interes: [Int64] = [840_400, 2_311_100, 2_101_000, 1_890_900, 1_680_800, 1_470_700, 1_260_600, 1_050_500, 840_400, 630_300, 420_200, 210_100]
        #expect(cost.schedule.map(\.interestMinor) == interes)
        #expect(cost.schedule.allSatisfy { $0.capitalMinor == 10_000_000 })
        #expect(cost.schedule.map(\.installment) == Array(1...12))
        #expect(cost.schedule.first?.cut == cd(2026, 10, 30))
        #expect(cost.schedule.first?.due == cd(2026, 11, 15))
        #expect(cost.schedule[4].cut == cd(2027, 2, 28))
        #expect(cost.schedule.last?.cut == cd(2027, 9, 30))
        #expect(cost.interestMinor == 14_707_000)
        #expect(cost.months == 12)
        #expect(CreditCardText.purchaseCost(cost, installments: 12) == "Esta compra a 12 cuotas te cuesta $ 147.070 de intereses")
    }

    @Test("La misma compra con cuota fija (francés)")
    func cuotaFija() {
        var t = base
        t.method = .cuotaFija
        let cost = CreditCardMath.purchaseCost(amountMinor: 120_000_000, installments: 12, day: cd(2026, 10, 20), terms: t)
        #expect(cost.schedule.map(\.capitalMinor) == [8_896_500, 9_083_400, 9_274_200, 9_469_100, 9_668_000, 9_871_100,
                                                       10_078_500, 10_290_300, 10_506_400, 10_727_200, 10_952_600, 11_182_700])
        #expect(cost.schedule.map(\.interestMinor) == [840_400, 2_334_300, 2_143_500, 1_948_600, 1_749_700, 1_546_600,
                                                        1_339_200, 1_127_400, 911_200, 690_500, 465_100, 235_000])
        #expect(cost.schedule.reduce(0) { $0 + $1.capitalMinor } == 120_000_000)
        #expect(cost.interestMinor == 15_331_500)
    }

    @Test("A 1 cuota no paga intereses, salvo que la tarjeta no lo permita")
    func unaCuota() {
        let free = CreditCardMath.purchaseCost(amountMinor: 35_000_000, installments: 1, day: cd(2026, 11, 3), terms: base)
        #expect(free.interestMinor == 0)
        #expect(free.schedule.map(\.capitalMinor) == [35_000_000])
        #expect(CreditCardText.purchaseCost(free, installments: 1) == "A 1 cuota no pagas intereses")
        var t = base
        t.oneInstallmentFree = false
        let paid = CreditCardMath.purchaseCost(amountMinor: 35_000_000, installments: 1, day: cd(2026, 11, 3), terms: t)
        #expect(paid.interestMinor == 640_500)
        #expect(CreditCardText.purchaseCost(paid, installments: 1) == "Esta compra a 1 cuota te cuesta $ 6.405 de intereses")
        var sinTasa = base
        sinTasa.rateEA = 0
        let cero = CreditCardMath.purchaseCost(amountMinor: 35_000_000, installments: 6, day: cd(2026, 11, 3), terms: sinTasa)
        #expect(CreditCardText.purchaseCost(cero, installments: 6) == "Esta compra a 6 cuotas no te cobra intereses")
    }

    @Test("Avance: intereses desde el día uno y comisión")
    func avance() {
        var t = base
        t.advanceFeeMinor = 990_000
        let led = CreditCardMath.ledger(terms: t, purchases: [CardPurchase(name: "Avance", amountMinor: 50_000_000, day: cd(2026, 11, 10), kind: .avance)],
                                        payments: [], through: cd(2026, 11, 30))
        let s = try! #require(led.lastStatement)
        #expect(s.interestMinor == 677_800)
        #expect(s.advanceFeesMinor == 990_000)
        #expect(s.minimumMinor == 51_667_800)
        #expect(s.totalMinor == 51_667_800)
        let tres = CreditCardMath.purchaseCost(amountMinor: 50_000_000, installments: 3, kind: .avance, day: cd(2026, 11, 10), terms: t)
        #expect(tres.schedule.map(\.capitalMinor) == [16_666_700, 16_666_700, 16_666_600])
        #expect(tres.schedule.map(\.interestMinor) == [677_800, 700_300, 350_200])
        #expect(tres.interestMinor == 1_728_300)
        #expect(tres.advanceFeesMinor == 990_000)
        #expect(CreditCardText.purchaseCost(tres, installments: 3, kind: .avance) == "Este avance a 3 cuotas te cuesta $ 17.283 de intereses y $ 9.900 de comisión")
    }

    // MARK: Extracto

    @Test("Extracto con varias compras, avance y cuota de manejo")
    func extracto() {
        let s = try! #require(CreditCardMath.statement(cut: cd(2026, 11, 30), terms: conCuota, purchases: compras, payments: []))
        #expect(s.lines.map(\.name) == ["Mercado", "Celular", "Tiquetes", "Avance", "Cine"])
        #expect(lineas(s) == [[1, 1, 42_000_000, 0, 0], [1, 24, 10_000_000, 4_066_500, 230_000_000],
                              [1, 6, 15_000_000, 1_098_000, 75_000_000], [1, 2, 15_000_000, 203_300, 15_000_000],
                              [1, 1, 8_500_000, 0, 0]])
        #expect(s.handlingFeeMinor == 3_290_000)
        #expect(s.advanceFeesMinor == 990_000)
        #expect(s.interestMinor == 5_367_800)
        #expect(s.minimumMinor == 100_147_800)
        #expect(s.totalMinor == 420_147_800)
        #expect(s.due == cd(2026, 12, 15))
        #expect(s.periodStart == cd(2026, 10, 31))
        #expect(CreditCardText.minimum(s) == "Mínimo $ 1.001.478")
        #expect(CreditCardText.payTotal(s) == "Paga $ 4.201.478 antes del 15 dic para no pagar más intereses")
        #expect(CreditCardText.installment(s.lines[1]) == "Cuota 1 de 24")
        #expect(CreditCardText.installment(s.lines[0]) == "1 cuota")
    }

    @Test("Cupo disponible cuenta las cuotas futuras y las compras después del corte")
    func cupo() {
        #expect(CreditCardMath.availableMinor(at: cd(2026, 11, 30), terms: conCuota, purchases: compras, payments: []) == 79_852_200)
        #expect(CreditCardMath.availableMinor(at: cd(2026, 12, 3), terms: conCuota, purchases: compras, payments: []) == 74_852_200)
        #expect(CreditCardText.available(79_852_200) == "Te quedan $ 798.522 de cupo")
        #expect(CreditCardText.available(0) == "No te queda cupo")
        #expect(CreditCardText.available(-12_000_000) == "Te pasaste $ 120.000 del cupo")
        #expect(CreditCardMath.ledger(terms: base, purchases: [], payments: [], through: cd(2026, 11, 30)).debtMinor == 0)
    }

    @Test("Próximo extracto desde hoy")
    func proximo() {
        let s = try! #require(CreditCardMath.upcomingStatement(today: cd(2026, 11, 20), terms: conCuota, purchases: compras, payments: []))
        #expect(s.cut == cd(2026, 11, 30))
        // Solo lo registrado hasta hoy: sin el cine del 30.
        #expect(s.lines.map(\.name) == ["Mercado", "Celular", "Tiquetes", "Avance"])
    }

    // MARK: Pagos

    @Test("Pago entre el mínimo y el total: el excedente va primero al avance y luego al saldo más caro")
    func pagoParcial() {
        let led = CreditCardMath.ledger(terms: conCuota, purchases: compras, payments: [CardPayment(amountMinor: 200_000_000, day: cd(2026, 12, 10))],
                                        through: cd(2026, 12, 30))
        #expect(led.statements.count == 2)
        #expect(led.paidMinor[0] == 200_000_000)
        #expect(CreditCardMath.status(of: led.statements[0], paidMinor: led.paidMinor[0], today: cd(2026, 12, 20), terms: conCuota) == .minimo)
        let dic = led.statements[1]
        #expect(dic.lines.map(\.name) == ["Celular", "Tiquetes", "Despues del corte"])
        #expect(lineas(dic) == [[2, 24, 6_310_800, 3_049_600, 138_837_000], [2, 6, 15_000_000, 1_575_800, 60_000_000], [1, 1, 5_000_000, 0, 0]])
        #expect(dic.minimumMinor == 34_226_200)
        #expect(dic.totalMinor == 233_063_200)
        #expect(dic.interestMinor == 4_625_400)
        #expect(led.debtMinor == 233_063_200)
    }

    @Test("Pago menor al mínimo: pendiente antes de la fecha, incompleto después y mora estimada")
    func pagoIncompleto() {
        let led = CreditCardMath.ledger(terms: conCuota, purchases: compras, payments: [CardPayment(amountMinor: 50_000_000, day: cd(2026, 12, 14))],
                                        through: cd(2026, 12, 30))
        let nov = led.statements[0]
        #expect(CreditCardMath.status(of: nov, paidMinor: led.paidMinor[0], today: cd(2026, 12, 10), terms: conCuota) == .pendiente(missingMinor: 50_147_800))
        let late = CreditCardMath.status(of: nov, paidMinor: led.paidMinor[0], today: cd(2026, 12, 16), terms: conCuota)
        #expect(late == .incompleto(missingMinor: 50_147_800, moraEstimateMinor: 1_053_600))
        #expect(CreditCardText.status(late) == "Pago incompleto: faltaron $ 501.478 del mínimo · mora estimada $ 10.536")
        #expect(CreditCardText.status(.pendiente(missingMinor: 50_147_800)) == "Te faltan $ 501.478 para el mínimo")
        let dic = led.statements[1]
        #expect(dic.overdueMinor == 50_147_800)
        #expect(dic.moraEstimateMinor == 1_053_600)
        #expect(lineas(dic) == [[2, 24, 10_000_000, 4_832_400, 220_000_000], [2, 6, 15_000_000, 1_575_800, 60_000_000],
                                [2, 2, 15_000_000, 315_200, 0], [1, 1, 5_000_000, 0, 0]])
        #expect(dic.interestMinor == 6_723_400)
        #expect(dic.minimumMinor == 106_214_800)
        #expect(dic.totalMinor == 386_214_800)
        #expect(CreditCardText.payTotal(dic) == "Paga $ 3.862.148 antes del 15 ene para no pagar más intereses")
    }

    @Test("Pago total deja la tarjeta en cero y el siguiente extracto solo con lo nuevo")
    func pagoTotal() {
        let led = CreditCardMath.ledger(terms: conCuota, purchases: compras, payments: [CardPayment(amountMinor: 420_147_800, day: cd(2026, 12, 15))],
                                        through: cd(2026, 12, 30))
        #expect(CreditCardMath.status(of: led.statements[0], paidMinor: led.paidMinor[0], today: cd(2026, 12, 20), terms: conCuota) == .total)
        let dic = led.statements[1]
        #expect(lineas(dic) == [[1, 1, 5_000_000, 0, 0]])
        #expect(dic.minimumMinor == 8_290_000)
        #expect(dic.totalMinor == 8_290_000)
        #expect(led.debtMinor == 8_290_000)
        #expect(CreditCardText.payTotal(dic) == "Paga $ 82.900 antes del 15 ene para no pagar intereses")
        #expect(CreditCardText.status(.total) == "Pagaste el total")
        #expect(CreditCardText.status(.minimo) == "Pagaste el mínimo")
    }

    @Test("Pagar de más deja saldo a favor para el siguiente extracto")
    func saldoAFavor() {
        let led = CreditCardMath.ledger(terms: conCuota, purchases: compras, payments: [CardPayment(amountMinor: 430_147_800, day: cd(2026, 12, 15))],
                                        through: cd(2026, 12, 30))
        let dic = led.statements[1]
        #expect(dic.lines.isEmpty)
        #expect(dic.creditAppliedMinor == 3_290_000)
        #expect(dic.minimumMinor == 0)
        #expect(dic.totalMinor == 0)
        #expect(led.debtMinor == -1_710_000)
        #expect(CreditCardText.payTotal(dic) == "No debes nada de este extracto")
        #expect(CreditCardMath.availableMinor(terms: conCuota, ledger: led) == 501_710_000)
    }

    @Test("Un abono antes del primer corte baja el capital")
    func abonoAntes() {
        let led = CreditCardMath.ledger(terms: base, purchases: [CardPurchase(name: "TV", amountMinor: 100_000_000, day: cd(2026, 11, 1), installments: 10)],
                                        payments: [CardPayment(amountMinor: 40_000_000, day: cd(2026, 11, 15))], through: cd(2026, 11, 30))
        let s = try! #require(led.lastStatement)
        #expect(lineas(s) == [[1, 10, 6_000_000, 1_179_300, 54_000_000]])
        #expect(s.minimumMinor == 7_179_300)
        #expect(s.totalMinor == 61_179_300)
        #expect(led.paidMinor == [0])
    }

    @Test("Corte 31 sin pagos: meses cortos, pendiente y mora estimada que se acumula")
    func corte31() {
        var t = base
        t.cutDay = 31
        t.dueDay = 20
        let led = CreditCardMath.ledger(terms: t, purchases: [CardPurchase(name: "Bici", amountMinor: 60_000_000, day: cd(2027, 1, 31), installments: 3)],
                                        payments: [], through: cd(2027, 4, 30))
        #expect(led.statements.map(\.cut) == [cd(2027, 1, 31), cd(2027, 2, 28), cd(2027, 3, 31), cd(2027, 4, 30)])
        #expect(led.statements.map(\.due) == [cd(2027, 2, 20), cd(2027, 3, 20), cd(2027, 4, 20), cd(2027, 5, 20)])
        #expect(led.statements.map(\.minimumMinor) == [20_000_000, 41_260_600, 62_547_700, 63_861_900])
        #expect(led.statements.map(\.totalMinor) == [60_000_000, 61_260_600, 62_547_700, 63_861_900])
        #expect(led.statements.map(\.overdueMinor) == [0, 20_000_000, 41_260_600, 62_547_700])
        #expect(led.statements.map(\.moraEstimateMinor) == [0, 420_200, 866_900, 1_314_200])
        #expect(led.statements.map(\.interestMinor) == [0, 840_400, 420_200, 0])
    }

    // MARK: Simuladores

    @Test("Si pagas solo el mínimo o un valor fijo al mes")
    func simuladores() {
        let hoy = cd(2026, 12, 1)
        let minimo = CreditCardMath.payOnlyMinimum(terms: conCuota, purchases: compras, payments: [], today: hoy)
        #expect(minimo.feasible)
        #expect(minimo.months == 24)
        #expect(minimo.interestMinor == 63_031_300)
        #expect(minimo.paidMinor == 484_889_100)
        #expect(minimo.lastPaymentDay == cd(2028, 11, 15))
        #expect(CreditCardText.onlyMinimum(minimo) == "Si pagas solo el mínimo terminas en 24 meses y pagas $ 630.313 de intereses")

        let fijo = CreditCardMath.payFixed(100_000_000, terms: conCuota, purchases: compras, payments: [], today: hoy)
        #expect(fijo.feasible)
        #expect(fijo.months == 5)
        #expect(fijo.interestMinor == 15_018_400)
        #expect(fijo.paidMinor == 436_876_200)
        #expect(fijo.lastPaymentDay == cd(2027, 4, 15))
        #expect(CreditCardText.fixedPayment(100_000_000, fijo) == "Si pagas $ 1.000.000 al mes terminas en 5 meses y pagas $ 150.184 de intereses")

        let poco = CreditCardMath.payFixed(30_000_000, terms: conCuota, purchases: compras, payments: [], today: hoy)
        #expect(!poco.feasible)
        #expect(poco.requiredMinimumMinor == 96_857_800)
        #expect(CreditCardText.fixedPayment(30_000_000, poco) == "Con $ 300.000 al mes no alcanzas el mínimo de $ 968.578")

        let nada = CreditCardMath.payOnlyMinimum(terms: base, purchases: [], payments: [], today: hoy)
        #expect(nada.months == 0)
        #expect(CreditCardText.onlyMinimum(nada) == "No tienes deuda en esta tarjeta")
    }

    // MARK: Desde el producto y textos

    @Test("Condiciones por defecto desde un producto")
    func condiciones() {
        let usura = Decimal(string: "28.34")!
        let t = CreditCardMath.terms(limitMinor: nil, cutDay: nil, dueDay: nil, rateEA: nil, defaultRateEA: usura)
        #expect(t.cutDay == 30)
        #expect(t.dueDay == 14)
        #expect(t.rateEA == usura)
        #expect(t.limitMinor == 0)
        #expect(t.oneInstallmentFree)
        #expect(CreditCardMath.terms(limitMinor: 1, cutDay: 15, dueDay: nil, rateEA: nil, defaultRateEA: usura).dueDay == 30)
        #expect(CreditCardMath.terms(limitMinor: 1, cutDay: 1, dueDay: nil, rateEA: nil, defaultRateEA: usura).dueDay == 16)
        let p = CreditCardMath.terms(limitMinor: 9, cutDay: 40, dueDay: 0, rateEA: 20, defaultRateEA: usura, handlingFeeMinor: 5, oneInstallmentFree: false)
        #expect(p.cutDay == 31)
        #expect(p.dueDay == 1)
        #expect(p.rateEA == 20)
        #expect(p.handlingFeeMinor == 5)
        #expect(!p.oneInstallmentFree)
    }

    @Test("Textos cortos")
    func textos() {
        #expect(CreditCardText.dayMonth(cd(2026, 11, 15)) == "15 nov")
        #expect(CreditCardText.rate(Decimal(string: "28.34")!) == "28,34 % E.A.")
        #expect(CreditCardText.rate(24) == "24 % E.A.")
        let uno = CardPayoff(feasible: true, months: 1, interestMinor: 0, paidMinor: 1, lastPaymentDay: nil, requiredMinimumMinor: 0)
        #expect(CreditCardText.onlyMinimum(uno) == "Si pagas solo el mínimo terminas en 1 mes y pagas $ 0 de intereses")
        for text in [CreditCardText.available(1), CreditCardText.status(.incompleto(missingMinor: 1, moraEstimateMinor: 1))] {
            #expect(!text.contains("\u{2014}"))
        }
    }
}
