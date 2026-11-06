import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct RecurringEndTests {
    private func fijo(_ next: Date, _ cycle: Cycle = .mensual, endDate: Date? = nil, total: Int? = nil, paid: Int = 0) -> RecurringRecord {
        RecurringRecord(kind: .gasto, name: "Celular", amountMinor: pesos(150_000), cycle: cycle, nextDate: next,
                        anchor: CycleAnchor(date: next, calendar: bogota), endDate: endDate, totalCount: total, paidCount: paid)
    }

    @Test("Mensual de 3 cuotas desde el 10 nov: 10 nov, 10 dic, 10 ene y nada más")
    func tresCuotas() {
        let item = fijo(fecha(2026, 11, 10), total: 3)
        let dates = RecurringEnd.dates(of: item, through: fecha(2027, 12, 31), calendar: bogota)
        #expect(dates.map(dia) == ["2026-11-10", "2026-12-10", "2027-01-10"])
    }

    @Test("Con paidCount = 1 el mes de noviembre no cuenta")
    func unaPagada() {
        let item = fijo(fecha(2026, 12, 10), total: 3, paid: 1)
        let dates = RecurringEnd.dates(of: item, through: fecha(2027, 12, 31), calendar: bogota)
        #expect(dates.map(dia) == ["2026-12-10", "2027-01-10"])
        let noviembre = BalanceCalculator.monthInterval(containing: fecha(2026, 11, 15), calendar: bogota)
        #expect(BalanceCalculator.pendingOccurrences(of: item, in: noviembre, calendar: bogota).isEmpty)
        let summary = BalanceCalculator.monthSummary(entries: [], recurring: [item], now: fecha(2026, 11, 15), calendar: bogota)
        #expect(summary.pendingFixedMinor == 0)
    }

    @Test("Con endDate 31 dic, un semanal no genera fechas de enero")
    func semanalHastaDiciembre() {
        let item = fijo(fecha(2026, 12, 3), .semanal, endDate: fecha(2026, 12, 31))
        let dates = RecurringEnd.dates(of: item, through: fecha(2027, 2, 28), calendar: bogota)
        #expect(dates.map(dia) == ["2026-12-03", "2026-12-10", "2026-12-17", "2026-12-24", "2026-12-31"])
        let enero = BalanceCalculator.monthInterval(containing: fecha(2027, 1, 15), calendar: bogota)
        #expect(BalanceCalculator.pendingOccurrences(of: item, in: enero, calendar: bogota).isEmpty)
    }

    @Test("La fecha final está incluida aunque el cobro sea más tarde ese día")
    func fechaIncluida() {
        let item = fijo(fecha(2026, 12, 31, 18), endDate: fecha(2026, 12, 31, 8))
        #expect(RecurringEnd.dates(of: item, through: fecha(2027, 3, 1), calendar: bogota).map(dia) == ["2026-12-31"])
    }

    @Test("Marcar pagado suma una cuota y termina en la última")
    func marcarPagado() {
        let middle = RecurringEnd.afterPayment(nextDate: fecha(2026, 12, 10), cycle: .mensual, anchor: CycleAnchor(day: 10, month: 11),
                                               endDate: nil, totalCount: 3, paidCount: 1, calendar: bogota)
        #expect(middle.paidCount == 2)
        #expect(middle.nextDate.map(dia) == "2027-01-10")
        #expect(!middle.finished)
        let last = RecurringEnd.afterPayment(nextDate: fecha(2027, 1, 10), cycle: .mensual, anchor: CycleAnchor(day: 10, month: 11),
                                             endDate: nil, totalCount: 3, paidCount: 2, calendar: bogota)
        #expect(last.paidCount == 3)
        #expect(last.finished)
    }

    @Test("Marcar pagado termina si la siguiente fecha pasa del fin")
    func pasaDelFin() {
        let payment = RecurringEnd.afterPayment(nextDate: fecha(2027, 3, 15), cycle: .mensual, anchor: CycleAnchor(day: 15, month: 3),
                                                endDate: fecha(2027, 3, 31), totalCount: nil, paidCount: 4, calendar: bogota)
        #expect(payment.finished)
        #expect(payment.paidCount == 5)
        let sinFin = RecurringEnd.afterPayment(nextDate: fecha(2027, 3, 15), cycle: .mensual, anchor: CycleAnchor(day: 15, month: 3),
                                               endDate: nil, totalCount: nil, paidCount: 0, calendar: bogota)
        #expect(!sinFin.finished)
    }

    @Test("Un pago terminado no sale en próximos")
    func terminadoNoSale() {
        let terminado = fijo(fecha(2027, 2, 10), total: 3, paid: 3)
        let vigente = fijo(fecha(2026, 11, 20), total: 3, paid: 2)
        let list = BalanceCalculator.upcoming(recurring: [terminado, vigente], now: fecha(2026, 11, 5), calendar: bogota)
        #expect(list.map(\.recurringId) == [vigente.id])
        #expect(RecurringEnd.isFinished(terminado, calendar: bogota))
    }

    @Test("El calendario respeta las cuotas")
    func calendario() {
        let item = fijo(fecha(2026, 11, 10), .semanal, total: 2)
        let days = CalendarMath.days(month: fecha(2026, 11, 1), entries: [], recurring: [item], now: fecha(2026, 11, 5), calendar: bogota)
        #expect(days.values.flatMap(\.charges).count == 2)
    }

    @Test("Textos: Cuota 3 de 12, Hasta 15 mar 2027 y Terminado")
    func textos() {
        #expect(RecurringEnd.progressText(endDate: nil, totalCount: 12, paidCount: 2, finished: false, calendar: bogota) == "Cuota 3 de 12")
        #expect(RecurringEnd.progressText(endDate: fecha(2027, 3, 15), totalCount: nil, paidCount: 0, finished: false, calendar: bogota) == "Hasta 15 mar 2027")
        #expect(RecurringEnd.progressText(endDate: nil, totalCount: 12, paidCount: 12, finished: true, calendar: bogota) == "Terminado")
        #expect(RecurringEnd.progressText(endDate: nil, totalCount: nil, paidCount: 5, finished: false, calendar: bogota) == nil)
        #expect(RecurringEnd.finishedMessage(name: "Celular", kind: .gasto) == "Terminaste de pagar Celular")
        #expect(RecurringEndChoice.of(endDate: nil, totalCount: 6) == .cuotas)
        #expect(RecurringEndChoice.of(endDate: fecha(2027, 1, 1), totalCount: nil) == .fecha)
    }

    @Test("Agregar un fijo con fecha vieja cuenta los cobros que quedaron atrás")
    func agregarConFechaVieja() {
        let plan = AddPlan.decide(cycle: .mensual, date: fecha(2026, 8, 10), now: fecha(2026, 11, 5, 22), calendar: bogota)
        #expect(plan.elapsed == 3)
        let hoy = AddPlan.decide(cycle: .mensual, date: fecha(2026, 11, 5, 9), now: fecha(2026, 11, 5, 22), calendar: bogota)
        #expect(hoy.elapsed == 1)
        let futuro = AddPlan.decide(cycle: .mensual, date: fecha(2026, 11, 20), now: fecha(2026, 11, 5, 22), calendar: bogota)
        #expect(futuro.elapsed == 0)
    }
}

struct TwoLevelReminderTests {
    let renta = RecurringRecord(kind: .gasto, name: "Renta", amountMinor: pesos(2_275_000), cycle: .mensual,
                                nextDate: fecha(2026, 11, 15), anchor: CycleAnchor(day: 15, month: 11))

    @Test("Sin aviso propio usa el general")
    func usaGeneral() {
        let general = GeneralReminder(enabled: true, daysBefore: 2, atMinutes: 480)
        let plan = ReminderPlanner.plan(recurring: [renta], rules: [], general: general, currency: .cop,
                                        now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 40)
        #expect(plan.map { dia($0.fireDate) } == ["2026-11-13", "2026-12-13"])
        #expect(bogota.component(.hour, from: plan[0].fireDate) == 8)
    }

    @Test("General en 0 días avisa el mismo día")
    func mismoDia() {
        let general = GeneralReminder(enabled: true, daysBefore: 0, atMinutes: 540)
        let plan = ReminderPlanner.plan(recurring: [renta], rules: [], general: general, currency: .cop,
                                        now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 10)
        #expect(plan.map { dia($0.fireDate) } == ["2026-11-15"])
        #expect(plan[0].body.hasPrefix("Renta vence hoy"))
    }

    @Test("General apagado, Sin aviso y Personalizado")
    func modos() {
        let apagado = GeneralReminder(enabled: false, daysBefore: 2, atMinutes: 480)
        #expect(ReminderPlanner.plan(recurring: [renta], rules: [], general: apagado, currency: .cop,
                                     now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 30).isEmpty)

        let encendido = GeneralReminder(enabled: true, daysBefore: 2, atMinutes: 480)
        let sinAviso = ReminderRule(recurringId: renta.id, daysBefore: 3, atMinutes: 540, sameDay: true, mode: .ninguno)
        #expect(ReminderPlanner.plan(recurring: [renta], rules: [sinAviso], general: encendido, currency: .cop,
                                     now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 30).isEmpty)

        let comoGeneral = ReminderRule(recurringId: renta.id, daysBefore: 9, atMinutes: 0, sameDay: true, mode: .general)
        let conGeneral = ReminderPlanner.plan(recurring: [renta], rules: [comoGeneral], general: encendido, currency: .cop,
                                              now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 10)
        #expect(conGeneral.map { dia($0.fireDate) } == ["2026-11-13"])

        let propio = ReminderRule(recurringId: renta.id, daysBefore: 1, atMinutes: 1200, sameDay: false)
        let conPropio = ReminderPlanner.plan(recurring: [renta], rules: [propio], general: apagado, currency: .cop,
                                             now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 10)
        #expect(conPropio.map { dia($0.fireDate) } == ["2026-11-14"])
        #expect(bogota.component(.hour, from: conPropio[0].fireDate) == 20)
    }

    @Test("Los avisos no pasan de la última cuota")
    func respetaCuotas() {
        var item = renta
        item.totalCount = 1
        let general = GeneralReminder(enabled: true, daysBefore: 1, atMinutes: 540)
        let plan = ReminderPlanner.plan(recurring: [item], rules: [], general: general, currency: .cop,
                                        now: fecha(2026, 11, 10), calendar: bogota, horizonDays: 60)
        #expect(plan.map { dia($0.fireDate) } == ["2026-11-14"])
    }
}

struct EasyDateTests {
    let ahora = fecha(2026, 11, 6, 15)

    @Test("Hoy, Ayer y Mañana cambian el día y conservan la hora")
    func atajos() {
        let base = fecha(2026, 10, 20, 7)
        #expect(dia(DayShortcut.ayer.apply(to: base, now: ahora, calendar: bogota)) == "2026-11-05")
        #expect(dia(DayShortcut.manana.apply(to: base, now: ahora, calendar: bogota)) == "2026-11-07")
        #expect(bogota.component(.hour, from: DayShortcut.hoy.apply(to: base, now: ahora, calendar: bogota)) == 7)
        #expect(DayShortcut.matching(fecha(2026, 11, 5, 23), now: ahora, calendar: bogota) == .ayer)
        #expect(DayShortcut.matching(fecha(2026, 11, 6, 1), now: ahora, calendar: bogota) == .hoy)
        #expect(DayShortcut.matching(fecha(2026, 11, 2), now: ahora, calendar: bogota) == nil)
    }

    @Test("Día del mes: este mes si no ha pasado, y si pasó según si ya se pagó")
    func diaDelMes() {
        #expect(dia(DayOfMonth.date(day: 20, now: ahora, alreadyPaidIfPassed: true, calendar: bogota)) == "2026-11-20")
        #expect(dia(DayOfMonth.date(day: 6, now: ahora, alreadyPaidIfPassed: false, calendar: bogota)) == "2026-11-06")
        #expect(dia(DayOfMonth.date(day: 2, now: ahora, alreadyPaidIfPassed: true, calendar: bogota)) == "2026-11-02")
        #expect(dia(DayOfMonth.date(day: 2, now: ahora, alreadyPaidIfPassed: false, calendar: bogota)) == "2026-12-02")
        #expect(dia(DayOfMonth.date(day: 31, now: ahora, alreadyPaidIfPassed: false, calendar: bogota)) == "2026-11-30")
        #expect(DayOfMonth.hasPassed(day: 5, now: ahora, calendar: bogota))
        #expect(!DayOfMonth.hasPassed(day: 6, now: ahora, calendar: bogota))
    }
}

struct PointsTests {
    @Test("Puntos: floor(monto / 1.000 × puntos por cada 1.000)")
    func puntos() {
        #expect(RewardMath.pointsEarned(amountMinor: pesos(84_300), currency: .cop, pointsPerThousand: 2) == 168)
        #expect(RewardMath.pointsEarned(amountMinor: pesos(84_300), currency: .cop, pointsPerThousand: Decimal(string: "1.5")) == 126)
        #expect(RewardMath.pointsEarned(amountMinor: pesos(999), currency: .cop, pointsPerThousand: 1) == 0)
        #expect(RewardMath.pointsEarned(amountMinor: pesos(1_000), currency: .cop, pointsPerThousand: 1) == 1)
        #expect(RewardMath.pointsEarned(amountMinor: pesos(50_000), currency: .cop, pointsPerThousand: nil) == 0)
        #expect(RewardMath.rateText(pointsPerThousand: 2, kind: .puntos, currency: .cop) == "2 puntos por cada $ 1.000")
        #expect(RewardMath.rateText(pointsPerThousand: 1, kind: .millas, currency: .cop) == "1 milla por cada $ 1.000")
    }
}

struct ManyCashTests {
    @Test("Varios efectivos se nombran y se agrupan")
    func efectivos() {
        #expect(WalletMath.subtitle(kinds: [.efectivo]) == "Billetera física")
        #expect(WalletMath.subtitle(kinds: [.efectivo, .efectivo, .efectivo]) == "Efectivo en 3 lugares")
        #expect(WalletMath.nextCashName(existing: ["Efectivo"]) == "Billetera")
        #expect(WalletMath.nextCashName(existing: ["Efectivo", "Billetera"]) == "Casa")
        #expect(WalletMath.nextCashName(existing: WalletMath.cashSuggestions) == "Efectivo 2")
    }

    @Test("Transferir entre dos efectivos mueve el saldo")
    func transferir() {
        let billetera = ProductRecord(kind: .efectivo, name: "Billetera", balanceMinor: pesos(200_000), balanceAt: fecha(2026, 11, 1))
        let casa = ProductRecord(kind: .efectivo, name: "Casa", balanceMinor: pesos(50_000), balanceAt: fecha(2026, 11, 1))
        let move = TransferRecord(fromProductId: billetera.id, toProductId: casa.id, amountMinor: pesos(80_000), occurredAt: fecha(2026, 11, 3))
        #expect(WalletMath.transferable([billetera, casa]).count == 2)
        #expect(MoneyCalculator.currentBalance(of: billetera, products: [billetera, casa], entries: [], transfers: [move]) == pesos(120_000))
        #expect(MoneyCalculator.currentBalance(of: casa, products: [billetera, casa], entries: [], transfers: [move]) == pesos(130_000))
    }
}
