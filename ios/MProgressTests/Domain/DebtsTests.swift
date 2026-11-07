import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct DebtsTests {
    let hoy = fecha(2026, 11, 10)

    func deuda(_ person: String, _ direction: DebtDirection, _ units: Int64, day: Int = 1, due: Date? = nil) -> DebtRecord {
        DebtRecord(person: person, direction: direction, amountMinor: pesos(units), date: fecha(2026, 11, day), dueDate: due)
    }

    @Test("Lo que falta resta los abonos y nunca baja de cero")
    func falta() {
        let d = deuda("Ana", .meDebe, 100_000)
        let abonos = [DebtPaymentRecord(debtId: d.id, amountMinor: pesos(30_000), date: fecha(2026, 11, 3)),
                      DebtPaymentRecord(debtId: d.id, amountMinor: pesos(20_000), date: fecha(2026, 11, 5)),
                      DebtPaymentRecord(debtId: UUID(), amountMinor: pesos(99_000), date: fecha(2026, 11, 5))]
        #expect(DebtMath.paid(d, payments: abonos) == pesos(50_000))
        #expect(DebtMath.remaining(d, payments: abonos) == pesos(50_000))
        let demas = abonos + [DebtPaymentRecord(debtId: d.id, amountMinor: pesos(80_000), date: fecha(2026, 11, 6))]
        #expect(DebtMath.remaining(d, payments: demas) == 0)
        #expect(DebtMath.clampPayment(pesos(80_000), remaining: pesos(50_000)) == pesos(50_000))
        #expect(DebtMath.clampPayment(-5, remaining: pesos(50_000)) == 0)
        #expect(DebtMath.lastPaymentDate(d, payments: demas) == fecha(2026, 11, 6))
    }

    @Test("Estado: pendiente, vencida después de la fecha límite y saldada al llegar a cero")
    func estado() {
        let d = deuda("Ana", .meDebe, 50_000, due: fecha(2026, 11, 9))
        #expect(DebtMath.status(d, payments: [], now: fecha(2026, 11, 9, 20), calendar: bogota) == .pendiente)
        #expect(DebtMath.status(d, payments: [], now: hoy, calendar: bogota) == .vencida)
        let pago = DebtPaymentRecord(debtId: d.id, amountMinor: pesos(50_000), date: hoy)
        #expect(DebtMath.status(d, payments: [pago], now: hoy, calendar: bogota) == .saldada)
        #expect(DebtMath.status(deuda("Ana", .leDebo, 1), payments: [], now: hoy, calendar: bogota) == .pendiente)
        #expect(DebtStatus.saldada.title == "Saldada")
    }

    @Test("Neto por persona junta nombres con tildes y mayúsculas distintas")
    func porPersona() {
        let a1 = deuda("Ana María", .meDebe, 300_000, day: 1)
        let a2 = deuda("  ana maria ", .leDebo, 50_000, day: 4)
        let c = deuda("Carlos", .leDebo, 80_000, day: 2)
        let saldada = deuda("Pedro", .meDebe, 10_000)
        let pagos = [DebtPaymentRecord(debtId: saldada.id, amountMinor: pesos(10_000), date: hoy),
                     DebtPaymentRecord(debtId: a1.id, amountMinor: pesos(100_000), date: hoy)]
        let people = DebtMath.people([a1, a2, c, saldada], payments: pagos)
        #expect(people.count == 2)
        #expect(people[0].name == "ana maria")
        #expect(people[0].owedToMeMinor == pesos(200_000))
        #expect(people[0].iOweMinor == pesos(50_000))
        #expect(people[0].netMinor == pesos(150_000))
        #expect(people[0].openCount == 2)
        #expect(DebtMath.netLabel(people[0]) == "te debe")
        #expect(people[1].name == "Carlos" && people[1].netMinor == -pesos(80_000))
        #expect(DebtMath.netLabel(people[1]) == "le debes")
        #expect(DebtMath.debts(of: DebtMath.personKey("ANA MARÍA"), in: [a1, a2, c]).count == 2)
        let mano = PersonDebts(key: "x", name: "X", owedToMeMinor: 5, iOweMinor: 5, openCount: 2)
        #expect(DebtMath.netLabel(mano) == "a mano")
    }

    @Test("Resumen de Dinero: te deben y debes")
    func resumen() {
        let debts = [deuda("Ana", .meDebe, 350_000), deuda("Carlos", .leDebo, 80_000)]
        let totals = DebtMath.totals(debts, payments: [])
        #expect(DebtMath.summaryText(totals, currency: .cop) == "Te deben $ 350.000 · Debes $ 80.000")
        #expect(DebtMath.summaryText(DebtTotals(owedToMeMinor: pesos(5_000), iOweMinor: 0), currency: .cop) == "Te deben $ 5.000")
        #expect(DebtMath.summaryText(DebtTotals(owedToMeMinor: 0, iOweMinor: pesos(80_000)), currency: .cop) == "Debes $ 80.000")
        #expect(DebtMath.summaryText(DebtTotals(owedToMeMinor: 0, iOweMinor: 0), currency: .cop) == "Nadie te debe y no debes nada")
    }

    @Test("Abiertas por fecha límite y saldadas por el último abono")
    func orden() {
        let sinFecha = deuda("A", .meDebe, 1, day: 5)
        let pronto = deuda("B", .meDebe, 1, day: 1, due: fecha(2026, 11, 12))
        let despues = deuda("C", .meDebe, 1, day: 2, due: fecha(2026, 11, 20))
        let vieja = deuda("D", .meDebe, 1, day: 1)
        let nueva = deuda("E", .meDebe, 1, day: 2)
        let pagos = [DebtPaymentRecord(debtId: vieja.id, amountMinor: pesos(1), date: fecha(2026, 11, 9)),
                     DebtPaymentRecord(debtId: nueva.id, amountMinor: pesos(1), date: fecha(2026, 11, 3))]
        let all = [sinFecha, despues, pronto, vieja, nueva]
        #expect(DebtMath.open(all, payments: pagos).map(\.person) == ["B", "C", "A"])
        #expect(DebtMath.settled(all, payments: pagos).map(\.person) == ["D", "E"])
    }

    @Test("Sugerencias de nombres ya usados")
    func sugerencias() {
        let debts = [deuda("Ana María", .meDebe, 1, day: 3), deuda("ana maría", .leDebo, 1, day: 1), deuda("Andrés", .meDebe, 1, day: 2),
                     deuda("Carlos", .meDebe, 1, day: 4)]
        #expect(DebtMath.suggestions(for: "an", debts: debts) == ["Ana María", "Andrés"])
        #expect(DebtMath.suggestions(for: "mar", debts: debts) == ["Ana María"])
        #expect(DebtMath.suggestions(for: "", debts: debts) == ["Carlos", "Ana María", "Andrés"])
        #expect(DebtMath.suggestions(for: "Carlos", debts: debts).isEmpty)
        #expect(DebtMath.cleanName("  Ana   María ") == "Ana María")
    }

    @Test("Hacia dónde se mueve la plata de la cuenta elegida")
    func movimiento() {
        let cuenta = UUID()
        #expect(DebtMath.transferEnds(productId: cuenta, direction: .meDebe, isPayment: false) == (cuenta, DebtMath.outsideProductId))
        #expect(DebtMath.transferEnds(productId: cuenta, direction: .meDebe, isPayment: true) == (DebtMath.outsideProductId, cuenta))
        #expect(DebtMath.transferEnds(productId: cuenta, direction: .leDebo, isPayment: false) == (DebtMath.outsideProductId, cuenta))
        #expect(DebtMath.transferEnds(productId: cuenta, direction: .leDebo, isPayment: true) == (cuenta, DebtMath.outsideProductId))
        #expect(DebtMath.productQuestion(.meDebe, isPayment: false) == "¿De dónde salió la plata?")
        #expect(DebtMath.productQuestion(.leDebo, isPayment: false) == "¿A dónde llegó?")
        #expect(DebtMath.transferNote(person: "Ana", direction: .meDebe, isPayment: false) == "Préstamo a Ana")
        #expect(DebtMath.transferNote(person: "Ana", direction: .meDebe, isPayment: true) == "Abono de Ana")
    }

    @Test("Prestar desde una cuenta baja su saldo, el abono lo sube y el patrimonio no cuenta la otra punta")
    func saldos() {
        let cuenta = ProductRecord(kind: .cuenta, name: "Ahorros", balanceMinor: pesos(1_000_000), balanceAt: fecha(2026, 10, 31))
        let prestamo = DebtMath.transferEnds(productId: cuenta.id, direction: .meDebe, isPayment: false)
        let abono = DebtMath.transferEnds(productId: cuenta.id, direction: .meDebe, isPayment: true)
        let transfers = [TransferRecord(fromProductId: prestamo.from, toProductId: prestamo.to, amountMinor: pesos(300_000), occurredAt: fecha(2026, 11, 1)),
                         TransferRecord(fromProductId: abono.from, toProductId: abono.to, amountMinor: pesos(100_000), occurredAt: fecha(2026, 11, 5))]
        #expect(MoneyCalculator.currentBalance(of: cuenta, products: [cuenta], entries: [], transfers: transfers) == pesos(800_000))
        #expect(MoneyCalculator.netWorth(products: [cuenta], entries: [], transfers: transfers).net == pesos(800_000))
        // Pedir prestado con la tarjeta de crédito sube su deuda.
        let tarjeta = ProductRecord(kind: .credito, name: "Visa", balanceMinor: 0, balanceAt: fecha(2026, 10, 31))
        let pago = DebtMath.transferEnds(productId: tarjeta.id, direction: .leDebo, isPayment: true)
        let t = TransferRecord(fromProductId: pago.from, toProductId: pago.to, amountMinor: pesos(50_000), occurredAt: fecha(2026, 11, 2))
        #expect(MoneyCalculator.currentBalance(of: tarjeta, products: [tarjeta], entries: [], transfers: [t]) == pesos(50_000))
    }

    @Test("Aviso el día antes de la fecha límite a la hora de los avisos")
    func aviso() {
        let d = deuda("Ana María", .meDebe, 50_000, due: fecha(2026, 11, 15))
        let fire = DebtMath.reminderDate(d, payments: [], atMinutes: 540, now: hoy, calendar: bogota)
        #expect(fire == fecha(2026, 11, 14, 9))
        #expect(DebtMath.reminderDate(d, payments: [], atMinutes: 540, now: fecha(2026, 11, 14, 10), calendar: bogota) == nil)
        #expect(DebtMath.reminderDate(deuda("A", .meDebe, 1), payments: [], atMinutes: 540, now: hoy, calendar: bogota) == nil)
        let pago = DebtPaymentRecord(debtId: d.id, amountMinor: pesos(50_000), date: hoy)
        #expect(DebtMath.reminderDate(d, payments: [pago], atMinutes: 540, now: hoy, calendar: bogota) == nil)
        let debo = deuda("Carlos", .leDebo, 80_000, due: fecha(2026, 11, 20))
        let plan = DebtMath.reminders([debo, d], payments: [], atMinutes: 480, currency: .cop, now: hoy, calendar: bogota)
        #expect(plan.count == 2)
        #expect(plan[0].id == "mp.deuda.\(d.id.uuidString.lowercased())")
        #expect(plan[0].title == "Mañana Ana María te paga")
        #expect(plan[0].body == "Quedó de pagarte $ 50.000. Si quieres, recuérdale desde Dinero.")
        #expect(plan[1].title == "Mañana le pagas a Carlos")
        #expect(plan[1].body == "Le debes $ 80.000. Si ya le pagaste, anota el abono en Dinero.")
        #expect(plan[1].fireDate == fecha(2026, 11, 19, 8))
    }

    @Test("Mensaje para recordarle con el monto y la fecha")
    func recordarle() {
        let conFecha = DebtMath.shareText(person: "Ana María", remainingMinor: pesos(150_000), dueDate: fecha(2026, 11, 15),
                                          currency: .cop, now: hoy, calendar: bogota)
        #expect(conFecha == "Hola Ana, ¿cómo vas? Te escribo para recordarte los $ 150.000 que te presté. Quedamos para el 15 de noviembre. Si puedes, me los pasas para esa fecha. Gracias.")
        let vencida = DebtMath.shareText(person: "Ana", remainingMinor: pesos(150_000), dueDate: fecha(2026, 11, 1), currency: .cop, now: hoy, calendar: bogota)
        #expect(vencida.hasSuffix("Quedamos para el 1 de noviembre. Cuando puedas me los pasas. Gracias."))
        let sinFecha = DebtMath.shareText(person: "Carlos", remainingMinor: pesos(20_000), dueDate: nil, currency: .cop, now: hoy, calendar: bogota)
        #expect(sinFecha == "Hola Carlos, ¿cómo vas? Te escribo para recordarte los $ 20.000 que te presté. Cuando puedas me los pasas. Gracias.")
        #expect(!conFecha.contains("\u{2014}"))
    }

    @Test("Lo que una persona te debe para recordarle: suma lo abierto y toma la fecha más cercana")
    func loQueTeDebe() {
        let a = deuda("Ana", .meDebe, 100_000, due: fecha(2026, 11, 20))
        let b = deuda("ana", .meDebe, 50_000, due: fecha(2026, 11, 12))
        let c = deuda("Ana", .leDebo, 30_000)
        let owed = DebtMath.owedToMe(by: DebtMath.personKey("Ana"), debts: [a, b, c], payments: [])
        #expect(owed.remainingMinor == pesos(150_000))
        #expect(owed.dueDate == fecha(2026, 11, 12))
        #expect(DebtDirection(rawValue: "me_debe") == .meDebe && DebtDirection.leDebo.rawValue == "le_debo")
    }

    @Test("La hoja de estado nombra deudas y abonos pendientes, y la nube los sincroniza después de los demás")
    @MainActor func nube() {
        #expect(SyncText.pendingSummary(["debts": 2, "debt_payments": 1]) == "2 deudas, 1 abono")
        #expect(SyncEngine.tables.suffix(2) == ["debts", "debt_payments"])
    }
}
