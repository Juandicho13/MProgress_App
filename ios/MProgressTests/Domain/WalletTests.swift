import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct WalletTests {
    let inicio = fecha(2026, 11, 1)

    @Test("Totales de un banco: tiene, debe y rendimiento de las cajitas")
    func totales() {
        let cuenta = ProductRecord(kind: .cuenta, name: "Ahorros", balanceMinor: pesos(600_000), balanceAt: inicio)
        let debito = ProductRecord(kind: .debito, name: "Débito", balanceMinor: 0, balanceAt: inicio, parentProductId: cuenta.id)
        let cajita = ProductRecord(kind: .bolsillo, name: "Emergencias", balanceMinor: pesos(1_500_000), balanceAt: inicio, rateEA: 8.25)
        let credito = ProductRecord(kind: .credito, name: "Crédito", balanceMinor: pesos(1_000_000), balanceAt: inicio)
        let oculto = ProductRecord(kind: .bolsillo, name: "Oculto", balanceMinor: pesos(999_000), balanceAt: inicio, hidden: true)
        let todos = [cuenta, debito, cajita, credito, oculto]
        let gasto = EntryRecord(kind: .gasto, amountMinor: pesos(100_000), occurredAt: fecha(2026, 11, 3), name: "Mercado", productId: debito.id)
        let pago = TransferRecord(fromProductId: cuenta.id, toProductId: credito.id, amountMinor: pesos(200_000), occurredAt: fecha(2026, 11, 4))

        let totales = WalletMath.totals(of: todos, allProducts: todos, entries: [gasto], transfers: [pago])
        #expect(totales.haveMinor == pesos(300_000 + 1_500_000))
        #expect(totales.oweMinor == pesos(800_000))
        #expect(totales.netMinor == pesos(1_000_000))
        #expect(totales.monthlyYieldMinor == MoneyCalculator.monthlyYield(balanceMinor: pesos(1_500_000), rateEA: 8.25))
        #expect(totales.monthlyYieldMinor > 0)
    }

    @Test("Una cajita cuenta como plata disponible, no como deuda, y suma su rendimiento")
    func cajita() {
        let cuenta = ProductRecord(kind: .cuenta, name: "Cuenta Nu", balanceMinor: pesos(200_000), balanceAt: inicio)
        let cajita = ProductRecord(kind: .cajita, name: "Viaje", balanceMinor: pesos(1_000_000), balanceAt: inicio, rateEA: 9)
        let bolsillo = ProductRecord(kind: .bolsillo, name: "Arriendo", balanceMinor: pesos(500_000), balanceAt: inicio)
        let todos = [cuenta, cajita, bolsillo]
        let paso = TransferRecord(fromProductId: cuenta.id, toProductId: cajita.id, amountMinor: pesos(100_000), occurredAt: fecha(2026, 11, 2))
        let totales = WalletMath.totals(of: todos, allProducts: todos, entries: [], transfers: [paso])
        #expect(totales.haveMinor == pesos(1_700_000))
        #expect(totales.oweMinor == 0)
        #expect(totales.monthlyYieldMinor == MoneyCalculator.monthlyYield(balanceMinor: pesos(1_100_000), rateEA: 9))
        let worth = MoneyCalculator.netWorth(products: todos, entries: [], transfers: [paso])
        #expect(worth.have == pesos(1_700_000) && worth.owe == 0)
        #expect(!ProductKind.cajita.isDebt && ProductKind.cajita.earnsYield && ProductKind.bolsillo.earnsYield && !ProductKind.cuenta.earnsYield)
        #expect(ProductKind.cajita.title == "Cajita" && ProductKind.bolsillo.title == "Bolsillo")
        #expect(ProductKind(rawValue: "cajita") == .cajita && ProductKind(rawValue: "bolsillo") == .bolsillo)
    }

    @Test("Subtítulo del banco según sus productos")
    func subtitulo() {
        #expect(WalletMath.subtitle(kinds: [.cuenta, .debito, .credito, .credito]) == "Cuenta · débito · 2 tarjetas de crédito")
        #expect(WalletMath.subtitle(kinds: [.cuenta, .bolsillo, .bolsillo, .bolsillo, .credito]) == "Cuenta · 3 bolsillos · tarjeta de crédito")
        #expect(WalletMath.subtitle(kinds: [.cuenta, .bolsillo, .cajita, .cajita]) == "Cuenta · 1 bolsillo · 2 cajitas")
        #expect(WalletMath.subtitle(kinds: [.efectivo]) == "Billetera física")
        #expect(WalletMath.subtitle(kinds: []) == "Sin productos")
    }

    @Test("Próximo pago de tarjeta: hoy, este mes o el siguiente, y el 31 en meses cortos")
    func proximoPago() {
        #expect(dia(WalletMath.nextDueDate(day: 20, now: fecha(2026, 11, 10), calendar: bogota)) == "2026-11-20")
        #expect(dia(WalletMath.nextDueDate(day: 10, now: fecha(2026, 11, 10, 18), calendar: bogota)) == "2026-11-10")
        #expect(dia(WalletMath.nextDueDate(day: 5, now: fecha(2026, 11, 10), calendar: bogota)) == "2026-12-05")
        #expect(dia(WalletMath.nextDueDate(day: 31, now: fecha(2026, 11, 10), calendar: bogota)) == "2026-11-30")
        #expect(dia(WalletMath.nextDueDate(day: 31, now: fecha(2027, 2, 1), calendar: bogota)) == "2027-02-28")
    }

    @Test("La más usada del mes cuenta pagos y Apple Pay")
    func masUsada() {
        let oro = UUID()
        let nu = UUID()
        let a = EntryRecord(kind: .gasto, amountMinor: pesos(10_000), occurredAt: fecha(2026, 11, 2), name: "A", productId: oro)
        let b = EntryRecord(kind: .gasto, amountMinor: pesos(20_000), occurredAt: fecha(2026, 11, 3), name: "B", productId: oro)
        let c = EntryRecord(kind: .gasto, amountMinor: pesos(90_000), occurredAt: fecha(2026, 11, 3), name: "C", productId: nu)
        let viejo = EntryRecord(kind: .gasto, amountMinor: pesos(1), occurredAt: fecha(2026, 10, 3), name: "D", productId: nu)
        let viejo2 = EntryRecord(kind: .gasto, amountMinor: pesos(1), occurredAt: fecha(2026, 10, 4), name: "E", productId: nu)
        let uso = WalletMath.mostUsed(entries: [a, b, c, viejo, viejo2], methods: [a.id: .applePay], now: fecha(2026, 11, 10), calendar: bogota)
        #expect(uso?.productId == oro)
        #expect(uso?.count == 2)
        #expect(uso?.applePay == 1)
        #expect(uso?.totalMinor == pesos(30_000))
        #expect(WalletMath.mostUsed(entries: [], methods: [:], now: fecha(2026, 11, 10), calendar: bogota) == nil)
    }

    @Test("Pestañas de ¿Con qué pagaste? y productos transferibles")
    func pestanas() {
        #expect(WalletMath.PayTab.of(.debito) == .tarjeta)
        #expect(WalletMath.PayTab.of(.bolsillo) == .cuenta)
        #expect(WalletMath.PayTab.of(.cajita) == .cuenta)
        #expect(WalletMath.PayTab.of(.efectivo) == .efectivo)
        let debito = ProductRecord(kind: .debito, name: "D", balanceMinor: 0, balanceAt: inicio)
        let cuenta = ProductRecord(kind: .cuenta, name: "C", balanceMinor: 0, balanceAt: inicio)
        #expect(WalletMath.transferable([debito, cuenta]).map(\.name) == ["C"])
    }
}

struct CardDueTests {
    @Test("Avisa las tarjetas con deuda cuyo pago está cerca")
    func pagosCerca() {
        let inicio = fecha(2026, 11, 1)
        let oro = ProductRecord(kind: .credito, name: "Oro", balanceMinor: pesos(300_000), balanceAt: inicio, dueDay: 12)
        let lejos = ProductRecord(kind: .credito, name: "Lejos", balanceMinor: pesos(100_000), balanceAt: inicio, dueDay: 28)
        let pagada = ProductRecord(kind: .credito, name: "Pagada", balanceMinor: 0, balanceAt: inicio, dueDay: 11)
        let sinDia = ProductRecord(kind: .credito, name: "SinDia", balanceMinor: pesos(5_000), balanceAt: inicio)
        let pagos = WalletMath.cardDues(products: [oro, lejos, pagada, sinDia], entries: [], transfers: [],
                                        now: fecha(2026, 11, 10), calendar: bogota)
        #expect(pagos.map(\.name) == ["Oro"])
        #expect(pagos.first?.urgency == .pronto)
        #expect(pagos.first?.debtMinor == pesos(300_000))
    }
}
