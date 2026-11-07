import Foundation

// Tarjetas de crédito a la colombiana: corte, fecha de pago, cuotas, avances, mínimo, pago total,
// cupo disponible, pagos parciales y simuladores. Funciones puras, sin SwiftData ni SwiftUI.
//
// La especificación ejecutable (con los números de las pruebas) es
// android/app/src/test/vectors/credit_card_vectors.py. Android tiene la misma lógica en
// domain/CreditCard.kt. Cambiar una regla aquí obliga a cambiarla en los dos y en el script.
//
// Reglas:
// - Montos en unidades mínimas. Cada línea (capital o interés) se redondea a la unidad que se ve
//   (pesos enteros en COP) con mitad hacia arriba, solo al final de su cálculo.
// - Tasa mensual = (1 + EA/100)^(1/12) - 1, con Newton en Decimal, redondeada a 20 decimales.
// - Una compra hasta el día de corte (incluido) va en el extracto que corta ese mes; después, en el
//   siguiente. Un corte 29, 30 o 31 cae el último día en los meses cortos.
// - Fecha de pago: el primer día de pago después del corte (mismo mes si cae después, si no el siguiente).
// - Capital fijo (lo normal en Colombia y el método por defecto): capital = saldo / cuotas que faltan
//   (la última lleva el resto) e interés = saldo pendiente × tasa mensual. En el primer extracto de una
//   compra el interés es proporcional a los días desde la compra hasta el corte.
// - Cuota fija (francés), por si un banco lo usa: cuota = R·i·q / (q − 1), q = (1 + i)^m.
// - Compra a 1 cuota sin intereses (si la tarjeta lo permite, como casi todas): interés 0, va completa en
//   el mínimo. Avance: intereses desde el día uno y comisión fija opcional.
// - Un pago primero cubre lo que falta del extracto (el mínimo); el excedente baja capital: avances primero,
//   luego el saldo con más intereses por delante, luego el más viejo. Si sobra, queda saldo a favor.
// - Lo que falta del mínimo al siguiente corte pasa como pendiente con interés de mora ESTIMADO (misma tasa).

/// Día del calendario sin hora ni zona: los cortes y pagos de la tarjeta son días, no instantes.
struct CardDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    /// Si el día no existe en el mes (31 de abril) se usa el último.
    init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = min(max(1, day), CardDay.daysInMonth(year: year, month: month))
    }

    init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// El mediodía de ese día en el calendario dado (para guardarlo como `Date`).
    func date(calendar: Calendar, hour: Int = 12) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        default:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        }
    }

    /// Días desde el 1 de enero de 1970 (algoritmo civil de Howard Hinnant).
    var ordinal: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    func days(to other: CardDay) -> Int { other.ordinal - ordinal }

    /// Mismo mes corrido `months` meses, con el día dado (ajustado al último si no existe).
    func shiftingMonths(_ months: Int, day: Int) -> CardDay {
        let total = year * 12 + (month - 1) + months
        let y = total >= 0 ? total / 12 : (total - 11) / 12
        return CardDay(y, total - y * 12 + 1, day)
    }

    static func < (lhs: CardDay, rhs: CardDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

/// Compra normal o avance (sacar plata con la tarjeta).
enum CardChargeKind: String, Codable, Sendable, CaseIterable {
    case compra, avance
}

/// Cómo reparte el banco cada cuota.
enum InstallmentMethod: String, Codable, Sendable, CaseIterable {
    /// Capital igual en cada cuota más intereses sobre el saldo (lo normal en Colombia).
    case capitalFijo
    /// Cuota total igual (sistema francés).
    case cuotaFija
}

/// Condiciones de una tarjeta.
struct CardTerms: Hashable, Sendable {
    /// Cupo total.
    var limitMinor: Int64
    /// Día de corte (1 a 31).
    var cutDay: Int
    /// Día de pago (1 a 31). Suele caer 15 a 20 días después del corte, a veces el mes siguiente.
    var dueDay: Int
    /// Tasa efectiva anual en porcentaje (28,34 es 28,34 % E.A.), como `Product.rateEA`.
    var rateEA: Decimal
    /// Cuota de manejo mensual (0 si no tiene).
    var handlingFeeMinor: Int64 = 0
    /// Compras a 1 cuota sin intereses (lo común en Colombia).
    var oneInstallmentFree: Bool = true
    /// Comisión fija por avance (0 si no cobra).
    var advanceFeeMinor: Int64 = 0
    var method: InstallmentMethod = .capitalFijo
    var currency: Currency = .cop
}

struct CardPurchase: Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var amountMinor: Int64
    var day: CardDay
    /// Número de cuotas, de 1 a 48.
    var installments: Int = 1
    var kind: CardChargeKind = .compra
}

struct CardPayment: Hashable, Sendable {
    var id: UUID = UUID()
    var amountMinor: Int64
    var day: CardDay
}

/// Una línea del extracto: "Celular · cuota 1 de 24".
struct CardStatementLine: Hashable, Sendable {
    var purchaseId: UUID
    var name: String
    var kind: CardChargeKind
    var installment: Int
    var installments: Int
    var capitalMinor: Int64
    var interestMinor: Int64
    /// Capital que queda para las cuotas siguientes.
    var remainingAfterMinor: Int64
    var cuotaMinor: Int64 { capitalMinor + interestMinor }
}

struct CardStatement: Hashable, Sendable {
    var cut: CardDay
    var due: CardDay
    /// Primer día del periodo (el día después del corte anterior).
    var periodStart: CardDay
    var lines: [CardStatementLine]
    var handlingFeeMinor: Int64
    var advanceFeesMinor: Int64
    /// Lo que faltó del mínimo del extracto anterior.
    var overdueMinor: Int64
    /// Interés de mora ESTIMADO sobre lo que faltó (el banco calcula el real).
    var moraEstimateMinor: Int64
    var creditAppliedMinor: Int64
    var minimumMinor: Int64
    var totalMinor: Int64

    var interestMinor: Int64 { lines.reduce(0) { $0 + $1.interestMinor } }
    var capitalMinor: Int64 { lines.reduce(0) { $0 + $1.capitalMinor } }
}

/// Saldo de una compra dentro de la tarjeta.
struct CardBalance: Hashable, Sendable {
    var seq: Int
    var purchaseId: UUID
    var name: String
    var kind: CardChargeKind
    var installments: Int
    var billed: Int
    var day: CardDay
    var amountMinor: Int64
    var remainingMinor: Int64
}

/// Estado de la tarjeta en un momento.
struct CardState: Hashable, Sendable {
    var balances: [CardBalance] = []
    /// Lo que falta pagar del último extracto (su mínimo menos lo pagado).
    var dueUnpaidMinor: Int64 = 0
    /// Saldo a favor.
    var creditMinor: Int64 = 0
    var pendingAdvanceFeesMinor: Int64 = 0
    var nextSeq = 0

    /// Capital que falta, incluidas las cuotas futuras.
    var futureCapitalMinor: Int64 { balances.reduce(0) { $0 + $1.remainingMinor } }
    /// Todo lo que se debe ahora (negativo si hay saldo a favor).
    var debtMinor: Int64 { futureCapitalMinor + dueUnpaidMinor - creditMinor }
}

struct CardLedger: Hashable, Sendable {
    var statements: [CardStatement]
    /// Lo pagado a cada extracto (pagos entre su corte y el siguiente), en el mismo orden.
    var paidMinor: [Int64]
    var state: CardState

    var debtMinor: Int64 { state.debtMinor }
    var lastStatement: CardStatement? { statements.last }
    var paidToLastMinor: Int64 { paidMinor.last ?? 0 }
}

enum CardPaymentStatus: Hashable, Sendable {
    /// Pagó el total: queda en cero.
    case total
    /// Pagó el mínimo o más, sin llegar al total.
    case minimo
    /// Todavía no llega la fecha de pago y falta para el mínimo.
    case pendiente(missingMinor: Int64)
    /// Pasó la fecha y no cubrió el mínimo. La mora es una estimación.
    case incompleto(missingMinor: Int64, moraEstimateMinor: Int64)
}

/// Resultado de un simulador de pago.
struct CardPayoff: Hashable, Sendable {
    /// False si el pago al mes no alcanza para el mínimo de algún extracto.
    var feasible: Bool
    var months: Int
    /// Intereses de los extractos que faltan (sin la cuota de manejo).
    var interestMinor: Int64
    var paidMinor: Int64
    var lastPaymentDay: CardDay?
    /// Si no alcanza: el mínimo que habría que pagar.
    var requiredMinimumMinor: Int64
}

struct CardScheduleRow: Hashable, Sendable {
    var cut: CardDay
    var due: CardDay
    var installment: Int
    var installments: Int
    var capitalMinor: Int64
    var interestMinor: Int64
    var cuotaMinor: Int64 { capitalMinor + interestMinor }
}

/// Cuánto cuesta una compra en cuotas pagando el mínimo cada mes.
struct CardPurchaseCost: Hashable, Sendable {
    var interestMinor: Int64
    var advanceFeesMinor: Int64
    var schedule: [CardScheduleRow]
    var months: Int { schedule.count }
}

enum CreditCardMath {
    static let maxInstallments = 48

    // MARK: Tasa y redondeo

    /// Tasa mensual equivalente a una E.A. en porcentaje: (1 + EA/100)^(1/12) − 1, a 20 decimales.
    static func monthlyRate(rateEA: Decimal) -> Decimal {
        let a = 1 + rateEA / 100
        guard rateEA > 0 else { return 0 }
        var x = 1 + rateEA / 1200
        for _ in 0..<60 {
            let next = x - (pow(x, 12) - a) / (12 * pow(x, 11))
            let delta = next - x
            x = next
            if abs(delta) < Decimal(sign: .plus, exponent: -30, significand: 1) { break }
        }
        var monthly = x - 1
        var rounded = Decimal()
        NSDecimalRound(&rounded, &monthly, 20, .plain)
        return rounded
    }

    /// Unidad de redondeo: lo que se ve en pantalla (100 en COP, que no muestra centavos).
    static func roundingUnit(_ currency: Currency) -> Int64 {
        var unit: Int64 = 1
        for _ in 0..<max(0, currency.minorDigits - currency.shownDigits) { unit *= 10 }
        return unit
    }

    /// Redondea a la unidad con mitad hacia arriba.
    static func roundToUnit(_ value: Decimal, unit: Int64) -> Int64 {
        var scaled = value / Decimal(unit)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value * unit
    }

    // MARK: Fechas

    /// Corte del mes: el día de corte o el último día si el mes es corto.
    static func cut(year: Int, month: Int, cutDay: Int) -> CardDay { CardDay(year, month, cutDay) }

    /// Corte del extracto donde cae una compra hecha ese día.
    static func statementCut(for day: CardDay, cutDay: Int) -> CardDay {
        let thisMonth = cut(year: day.year, month: day.month, cutDay: cutDay)
        return day <= thisMonth ? thisMonth : day.shiftingMonths(1, day: cutDay)
    }

    static func nextCut(after cut: CardDay, cutDay: Int) -> CardDay { cut.shiftingMonths(1, day: cutDay) }

    static func previousCut(before cut: CardDay, cutDay: Int) -> CardDay { cut.shiftingMonths(-1, day: cutDay) }

    /// Fecha límite de pago del extracto que corta ese día.
    static func dueDate(forCut cut: CardDay, dueDay: Int) -> CardDay {
        let sameMonth = CardDay(cut.year, cut.month, dueDay)
        return sameMonth > cut ? sameMonth : cut.shiftingMonths(1, day: dueDay)
    }

    // MARK: Motor

    private static func isFree(_ balance: CardBalance, _ terms: CardTerms) -> Bool {
        balance.kind == .compra && balance.installments == 1 && terms.oneInstallmentFree
    }

    /// Orden en que el excedente de un pago baja capital: avances, luego más intereses por delante, luego el más viejo.
    private static func prepayOrder(_ balances: [CardBalance], _ terms: CardTerms, _ rate: Decimal) -> [Int] {
        func weight(_ b: CardBalance) -> Int64 {
            let bearing = !isFree(b, terms) && rate > 0
            let left = Int64(max(1, b.installments - b.billed))
            return bearing ? b.remainingMinor * (left + 1) : 0
        }
        return balances.indices.filter { balances[$0].remainingMinor > 0 }.sorted { l, r in
            let a = balances[l], b = balances[r]
            let ka = a.kind == .avance ? 0 : 1, kb = b.kind == .avance ? 0 : 1
            if ka != kb { return ka < kb }
            let wa = weight(a), wb = weight(b)
            if wa != wb { return wa > wb }
            if a.day != b.day { return a.day < b.day }
            return a.seq < b.seq
        }
    }

    /// Baja capital futuro con `amount`; devuelve lo que sobra.
    private static func prepay(_ state: inout CardState, _ amount: Int64, _ terms: CardTerms, _ rate: Decimal) -> Int64 {
        var left = amount
        for index in prepayOrder(state.balances, terms, rate) {
            guard left > 0 else { break }
            let used = min(left, state.balances[index].remainingMinor)
            state.balances[index].remainingMinor -= used
            left -= used
        }
        return left
    }

    private static func add(_ purchase: CardPurchase, to state: inout CardState, _ terms: CardTerms) {
        let count = min(maxInstallments, max(1, purchase.installments))
        state.balances.append(CardBalance(seq: state.nextSeq, purchaseId: purchase.id, name: purchase.name, kind: purchase.kind,
                                          installments: count, billed: 0, day: purchase.day,
                                          amountMinor: purchase.amountMinor, remainingMinor: purchase.amountMinor))
        state.nextSeq += 1
        if purchase.kind == .avance { state.pendingAdvanceFeesMinor += terms.advanceFeeMinor }
    }

    /// Aplica un pago: primero lo que falta del extracto, luego capital, y lo que sobra queda a favor.
    static func apply(payment amount: Int64, to state: inout CardState, terms: CardTerms) {
        let rate = monthlyRate(rateEA: terms.rateEA)
        let toDue = min(amount, state.dueUnpaidMinor)
        state.dueUnpaidMinor -= toDue
        state.creditMinor += prepay(&state, amount - toDue, terms, rate)
    }

    /// Genera el extracto que corta en `cut` y deja el estado listo para recibir pagos.
    static func bill(_ state: inout CardState, cut: CardDay, terms: CardTerms) -> CardStatement {
        let rate = monthlyRate(rateEA: terms.rateEA)
        let unit = roundingUnit(terms.currency)
        let previous = previousCut(before: cut, cutDay: terms.cutDay)
        let periodDays = max(1, previous.days(to: cut))
        let overdue = state.dueUnpaidMinor
        let mora = overdue > 0 ? roundToUnit(Decimal(overdue) * rate, unit: unit) : 0
        var lines: [CardStatementLine] = []
        for index in state.balances.indices where state.balances[index].remainingMinor > 0 {
            let balance = state.balances[index]
            let left = max(1, balance.installments - balance.billed)
            let free = isFree(balance, terms)
            let remaining = Decimal(balance.remainingMinor)
            let capital: Int64
            if left <= 1 {
                capital = balance.remainingMinor
            } else if terms.method == .cuotaFija && !free && rate > 0 {
                let q = pow(1 + rate, left)
                let cuota = roundToUnit(remaining * rate * q / (q - 1), unit: unit)
                capital = max(0, min(balance.remainingMinor, cuota - roundToUnit(remaining * rate, unit: unit)))
            } else {
                capital = roundToUnit(remaining / Decimal(left), unit: unit)
            }
            let interest: Int64
            if free {
                interest = 0
            } else if balance.billed == 0 {
                let days = balance.day.days(to: cut)
                interest = roundToUnit(remaining * rate * Decimal(days) / Decimal(periodDays), unit: unit)
            } else {
                interest = roundToUnit(remaining * rate, unit: unit)
            }
            state.balances[index].remainingMinor -= capital
            state.balances[index].billed += 1
            lines.append(CardStatementLine(purchaseId: balance.purchaseId, name: balance.name, kind: balance.kind,
                                           installment: balance.billed + 1, installments: balance.installments,
                                           capitalMinor: capital, interestMinor: interest,
                                           remainingAfterMinor: state.balances[index].remainingMinor))
        }
        let advanceFees = state.pendingAdvanceFeesMinor
        state.pendingAdvanceFeesMinor = 0
        var due = lines.reduce(0) { $0 + $1.capitalMinor + $1.interestMinor } + terms.handlingFeeMinor + advanceFees + overdue + mora
        let used = min(state.creditMinor, due)
        due -= used
        state.creditMinor -= used
        if state.creditMinor > 0 { state.creditMinor = prepay(&state, state.creditMinor, terms, rate) }
        state.dueUnpaidMinor = due
        return CardStatement(cut: cut, due: dueDate(forCut: cut, dueDay: terms.dueDay),
                             periodStart: previous.shiftingDays(1),
                             lines: lines, handlingFeeMinor: terms.handlingFeeMinor, advanceFeesMinor: advanceFees,
                             overdueMinor: overdue, moraEstimateMinor: mora, creditAppliedMinor: used,
                             minimumMinor: due, totalMinor: due + state.futureCapitalMinor)
    }

    /// Recorre compras, pagos y cortes en orden hasta `through` (incluido). El mismo día van primero las
    /// compras, luego los pagos y al final el corte.
    static func ledger(terms: CardTerms, purchases: [CardPurchase], payments: [CardPayment], through: CardDay) -> CardLedger {
        enum Event { case purchase(CardPurchase), payment(CardPayment) }
        var events: [(day: CardDay, order: Int, index: Int, event: Event)] = []
        for (index, purchase) in purchases.enumerated() { events.append((purchase.day, 0, index, .purchase(purchase))) }
        for (index, payment) in payments.enumerated() { events.append((payment.day, 1, index, .payment(payment))) }
        events.sort { ($0.day, $0.order, $0.index) < ($1.day, $1.order, $1.index) }
        var state = CardState()
        var statements: [CardStatement] = []
        var paid: [Int64] = []
        guard let first = events.first else { return CardLedger(statements: [], paidMinor: [], state: state) }
        var cursor = 0
        func process(until limit: CardDay) {
            while cursor < events.count && events[cursor].day <= limit {
                switch events[cursor].event {
                case .purchase(let purchase):
                    add(purchase, to: &state, terms)
                case .payment(let payment):
                    apply(payment: payment.amountMinor, to: &state, terms: terms)
                    if !paid.isEmpty { paid[paid.count - 1] += payment.amountMinor }
                }
                cursor += 1
            }
        }
        var cut = statementCut(for: first.day, cutDay: terms.cutDay)
        var guardCount = 0
        while cut <= through && guardCount < 1200 {
            process(until: cut)
            statements.append(bill(&state, cut: cut, terms: terms))
            paid.append(0)
            cut = nextCut(after: cut, cutDay: terms.cutDay)
            guardCount += 1
        }
        process(until: through)
        return CardLedger(statements: statements, paidMinor: paid, state: state)
    }

    /// El extracto que corta en `cut` (o nil si no hay movimientos antes).
    static func statement(cut: CardDay, terms: CardTerms, purchases: [CardPurchase], payments: [CardPayment]) -> CardStatement? {
        ledger(terms: terms, purchases: purchases, payments: payments, through: cut).statements.last { $0.cut == cut }
    }

    /// Próximo extracto visto desde hoy: el que corta hoy o después, con lo registrado hasta ahora.
    static func upcomingStatement(today: CardDay, terms: CardTerms, purchases: [CardPurchase], payments: [CardPayment]) -> CardStatement? {
        let cut = statementCut(for: today, cutDay: terms.cutDay)
        let known = purchases.filter { $0.day <= today }
        let made = payments.filter { $0.day <= today }
        return statement(cut: cut, terms: terms, purchases: known, payments: made)
    }

    /// Cupo disponible: cupo menos todo lo que se debe (capital futuro incluido). Negativo si se pasó.
    static func availableMinor(terms: CardTerms, ledger: CardLedger) -> Int64 {
        terms.limitMinor - ledger.debtMinor
    }

    static func availableMinor(at day: CardDay, terms: CardTerms, purchases: [CardPurchase], payments: [CardPayment]) -> Int64 {
        availableMinor(terms: terms, ledger: ledger(terms: terms, purchases: purchases, payments: payments, through: day))
    }

    /// Cómo va el pago de un extracto.
    static func status(of statement: CardStatement, paidMinor: Int64, today: CardDay, terms: CardTerms) -> CardPaymentStatus {
        if paidMinor >= statement.totalMinor { return .total }
        if paidMinor >= statement.minimumMinor { return .minimo }
        let missing = statement.minimumMinor - paidMinor
        if today <= statement.due { return .pendiente(missingMinor: missing) }
        let rate = monthlyRate(rateEA: terms.rateEA)
        return .incompleto(missingMinor: missing, moraEstimateMinor: roundToUnit(Decimal(missing) * rate, unit: roundingUnit(terms.currency)))
    }

    // MARK: Simuladores

    /// "Si pagas solo el mínimo": meses hasta quedar en cero e intereses que faltan, sin compras nuevas ni cuota de manejo.
    static func payOnlyMinimum(terms: CardTerms, purchases: [CardPurchase], payments: [CardPayment], today: CardDay) -> CardPayoff {
        simulate(terms: terms, purchases: purchases, payments: payments, today: today, fixedMinor: nil)
    }

    /// "Si pagas $ X al mes": si X no alcanza el mínimo de algún extracto, `feasible` es false con ese mínimo.
    static func payFixed(_ amountMinor: Int64, terms: CardTerms, purchases: [CardPurchase], payments: [CardPayment], today: CardDay) -> CardPayoff {
        simulate(terms: terms, purchases: purchases, payments: payments, today: today, fixedMinor: amountMinor)
    }

    private static func simulate(terms original: CardTerms, purchases: [CardPurchase], payments: [CardPayment], today: CardDay,
                                 fixedMinor: Int64?, maxMonths: Int = 600) -> CardPayoff {
        var terms = original
        terms.handlingFeeMinor = 0
        let base = ledger(terms: terms, purchases: purchases, payments: payments, through: today)
        var state = base.state
        var months = 0
        var interest: Int64 = 0
        var paidTotal: Int64 = 0
        var lastDay: CardDay?
        var cut = base.lastStatement.map { nextCut(after: $0.cut, cutDay: terms.cutDay) } ?? statementCut(for: today, cutDay: terms.cutDay)

        func pay(minimum: Int64, on day: CardDay) -> Bool {
            let amount: Int64
            if let fixedMinor {
                guard fixedMinor >= minimum else { return false }
                amount = min(fixedMinor, state.debtMinor)
            } else {
                amount = state.dueUnpaidMinor
            }
            if amount > 0 {
                apply(payment: amount, to: &state, terms: terms)
                months += 1
                paidTotal += amount
                lastDay = day
            }
            return true
        }

        if let last = base.lastStatement, state.dueUnpaidMinor > 0 {
            let minimum = state.dueUnpaidMinor
            if !pay(minimum: minimum, on: max(last.due, today)) {
                return CardPayoff(feasible: false, months: 0, interestMinor: 0, paidMinor: 0, lastPaymentDay: nil, requiredMinimumMinor: minimum)
            }
        }
        for _ in 0..<maxMonths {
            if state.debtMinor <= 0 { break }
            let statement = bill(&state, cut: cut, terms: terms)
            interest += statement.interestMinor + statement.moraEstimateMinor
            if !pay(minimum: statement.minimumMinor, on: statement.due) {
                return CardPayoff(feasible: false, months: 0, interestMinor: 0, paidMinor: 0, lastPaymentDay: nil,
                                  requiredMinimumMinor: statement.minimumMinor)
            }
            cut = nextCut(after: cut, cutDay: terms.cutDay)
        }
        return CardPayoff(feasible: true, months: months, interestMinor: interest, paidMinor: paidTotal, lastPaymentDay: lastDay, requiredMinimumMinor: 0)
    }

    /// Plan de cuotas y costo de una compra sola pagando el mínimo: "Esta compra a 12 cuotas te cuesta $ Y".
    static func purchaseCost(amountMinor: Int64, installments: Int, kind: CardChargeKind = .compra, day: CardDay, terms original: CardTerms) -> CardPurchaseCost {
        var terms = original
        terms.handlingFeeMinor = 0
        var state = CardState()
        add(CardPurchase(name: "", amountMinor: amountMinor, day: day, installments: installments, kind: kind), to: &state, terms)
        var cut = statementCut(for: day, cutDay: terms.cutDay)
        var rows: [CardScheduleRow] = []
        var interest: Int64 = 0
        var fees: Int64 = 0
        for _ in 0..<(maxInstallments + 12) {
            if state.futureCapitalMinor <= 0 { break }
            let statement = bill(&state, cut: cut, terms: terms)
            fees += statement.advanceFeesMinor
            for line in statement.lines {
                interest += line.interestMinor
                rows.append(CardScheduleRow(cut: cut, due: statement.due, installment: line.installment, installments: line.installments,
                                            capitalMinor: line.capitalMinor, interestMinor: line.interestMinor))
            }
            apply(payment: state.dueUnpaidMinor, to: &state, terms: terms)
            cut = nextCut(after: cut, cutDay: terms.cutDay)
        }
        return CardPurchaseCost(interestMinor: interest, advanceFeesMinor: fees, schedule: rows)
    }

    // MARK: Desde los modelos de la app

    /// Condiciones a partir de un producto de crédito. Sin día de corte usa 30 y sin día de pago, 15 días después;
    /// sin tasa usa `defaultRateEA` (el tope de usura del catálogo).
    static func terms(limitMinor: Int64?, cutDay: Int?, dueDay: Int?, rateEA: Decimal?, defaultRateEA: Decimal,
                      handlingFeeMinor: Int64? = nil, oneInstallmentFree: Bool? = nil, currency: Currency = .cop) -> CardTerms {
        let cut = min(31, max(1, cutDay ?? 30))
        let due = min(31, max(1, dueDay ?? ((cut + 14) % 31 + 1)))
        return CardTerms(limitMinor: max(0, limitMinor ?? 0), cutDay: cut, dueDay: due, rateEA: rateEA ?? defaultRateEA,
                         handlingFeeMinor: max(0, handlingFeeMinor ?? 0), oneInstallmentFree: oneInstallmentFree ?? true,
                         currency: currency)
    }
}

extension CardDay {
    func shiftingDays(_ days: Int) -> CardDay {
        // Inverso de `ordinal` (civil_from_days de Howard Hinnant).
        let z = ordinal + days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return CardDay(yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
}

/// Textos en español para las pantallas de tarjeta.
enum CreditCardText {
    static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    /// "15 nov".
    static func dayMonth(_ day: CardDay) -> String { "\(day.day) \(months[day.month - 1])" }

    private static func money(_ minor: Int64, _ currency: Currency) -> String { Money(minor: minor, currency: currency).formatted() }

    /// "Paga $ 845.000 antes del 15 nov para no pagar intereses".
    static func payTotal(_ statement: CardStatement, currency: Currency = .cop) -> String {
        if statement.totalMinor <= 0 { return "No debes nada de este extracto" }
        let tail = statement.interestMinor > 0 || statement.overdueMinor > 0 ? "para no pagar más intereses" : "para no pagar intereses"
        return "Paga \(money(statement.totalMinor, currency)) antes del \(dayMonth(statement.due)) \(tail)"
    }

    /// "Mínimo $ 210.300".
    static func minimum(_ statement: CardStatement, currency: Currency = .cop) -> String {
        "Mínimo \(money(statement.minimumMinor, currency))"
    }

    /// "Te quedan $ 3.200.000 de cupo".
    static func available(_ availableMinor: Int64, currency: Currency = .cop) -> String {
        if availableMinor > 0 { return "Te quedan \(money(availableMinor, currency)) de cupo" }
        if availableMinor == 0 { return "No te queda cupo" }
        return "Te pasaste \(money(-availableMinor, currency)) del cupo"
    }

    /// "Cuota 3 de 12" o "1 cuota".
    static func installment(_ line: CardStatementLine) -> String {
        line.installments <= 1 ? "1 cuota" : "Cuota \(line.installment) de \(line.installments)"
    }

    /// "Esta compra a 12 cuotas te cuesta $ 147.070 de intereses".
    static func purchaseCost(_ cost: CardPurchaseCost, installments: Int, kind: CardChargeKind = .compra, currency: Currency = .cop) -> String {
        let what = kind == .avance ? "Este avance" : "Esta compra"
        let plan = installments <= 1 ? "a 1 cuota" : "a \(installments) cuotas"
        let fee = cost.advanceFeesMinor > 0 ? money(cost.advanceFeesMinor, currency) + " de comisión" : nil
        if cost.interestMinor <= 0 {
            if kind == .compra && installments <= 1 { return "A 1 cuota no pagas intereses" }
            return "\(what) \(plan) no te cobra intereses" + (fee.map { ", solo \($0)" } ?? "")
        }
        return "\(what) \(plan) te cuesta \(money(cost.interestMinor, currency)) de intereses" + (fee.map { " y \($0)" } ?? "")
    }

    private static func monthsText(_ months: Int) -> String { months == 1 ? "1 mes" : "\(months) meses" }

    /// "Si pagas solo el mínimo terminas en 24 meses y pagas $ 630.313 de intereses".
    static func onlyMinimum(_ payoff: CardPayoff, currency: Currency = .cop) -> String {
        if payoff.months == 0 { return "No tienes deuda en esta tarjeta" }
        return "Si pagas solo el mínimo terminas en \(monthsText(payoff.months)) y pagas \(money(payoff.interestMinor, currency)) de intereses"
    }

    /// "Si pagas $ 1.000.000 al mes terminas en 5 meses y pagas $ 150.184 de intereses".
    static func fixedPayment(_ amountMinor: Int64, _ payoff: CardPayoff, currency: Currency = .cop) -> String {
        if !payoff.feasible {
            return "Con \(money(amountMinor, currency)) al mes no alcanzas el mínimo de \(money(payoff.requiredMinimumMinor, currency))"
        }
        if payoff.months == 0 { return "No tienes deuda en esta tarjeta" }
        return "Si pagas \(money(amountMinor, currency)) al mes terminas en \(monthsText(payoff.months)) y pagas \(money(payoff.interestMinor, currency)) de intereses"
    }

    /// Estado del pago del extracto.
    static func status(_ status: CardPaymentStatus, currency: Currency = .cop) -> String {
        switch status {
        case .total: return "Pagaste el total"
        case .minimo: return "Pagaste el mínimo"
        case .pendiente(let missing): return "Te faltan \(money(missing, currency)) para el mínimo"
        case .incompleto(let missing, let mora):
            return "Pago incompleto: faltaron \(money(missing, currency)) del mínimo · mora estimada \(money(mora, currency))"
        }
    }

    /// "28,34 % E.A.".
    static func rate(_ rateEA: Decimal) -> String {
        var value = rateEA
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return "\(rounded)".replacingOccurrences(of: ".", with: ",") + " % E.A."
    }
}
