import Foundation

// Quién te debe: plata prestada entre la persona y otras personas (no es la división en pareja de F11).
// Todo es puro: entran deudas y abonos, salen saldos, estados y textos. Igual que domain/Debts.kt de Android.

/// Hacia dónde va la deuda.
enum DebtDirection: String, Codable, Sendable, CaseIterable {
    /// La otra persona me debe (yo le presté).
    case meDebe = "me_debe"
    /// Yo le debo (ella me prestó).
    case leDebo = "le_debo"

    var title: String { self == .meDebe ? "Me debe" : "Le debo" }

    /// +1 si me deben, -1 si debo.
    var sign: Int64 { self == .meDebe ? 1 : -1 }
}

/// Una deuda con una persona. El monto es el original; lo que falta sale de restarle los abonos.
struct DebtRecord: Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    var person: String
    var direction: DebtDirection
    var amountMinor: Int64
    var date: Date
    var dueDate: Date? = nil
    var note: String? = nil
    /// Cuenta o producto por donde pasó la plata, si la persona lo dijo.
    var productId: UUID? = nil
}

/// Un abono a una deuda.
struct DebtPaymentRecord: Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    var debtId: UUID
    var amountMinor: Int64
    var date: Date
    var productId: UUID? = nil
}

enum DebtStatus: String, Sendable {
    case pendiente, vencida, saldada

    var title: String {
        switch self {
        case .pendiente: "Pendiente"
        case .vencida: "Vencida"
        case .saldada: "Saldada"
        }
    }
}

/// Lo que hay con una persona: cuánto te debe, cuánto le debes y el neto.
struct PersonDebts: Hashable, Sendable, Identifiable {
    /// Nombre normalizado (sin tildes ni mayúsculas), para juntar "Ana" y "ana ".
    var key: String
    /// Nombre como se escribió en la deuda más nueva.
    var name: String
    var owedToMeMinor: Int64
    var iOweMinor: Int64
    var openCount: Int

    var id: String { key }
    /// Positivo: te debe. Negativo: le debes.
    var netMinor: Int64 { owedToMeMinor - iOweMinor }
}

struct DebtTotals: Hashable, Sendable {
    var owedToMeMinor: Int64
    var iOweMinor: Int64
}

enum DebtMath {
    /// Producto que no existe: la otra punta de la transferencia que mueve la plata de una deuda. Como no es un
    /// producto, no suma en el patrimonio y solo cambia el saldo de la cuenta elegida (MoneyCalculator).
    static let outsideProductId = UUID(uuidString: "0D000000-0000-4000-8000-0000000000DE")!

    /// "  ana   maría " → "ana maría": un solo espacio, sin espacios al borde.
    static func cleanName(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Clave para juntar a la misma persona: minúsculas, sin tildes ni signos.
    static func personKey(_ raw: String) -> String {
        InitialUpload.normalizedName(raw)
    }

    static func paid(_ debt: DebtRecord, payments: [DebtPaymentRecord]) -> Int64 {
        payments.filter { $0.debtId == debt.id }.reduce(Int64(0)) { $0 + $1.amountMinor }
    }

    /// Lo que falta: el monto menos los abonos, nunca menos de cero.
    static func remaining(_ debt: DebtRecord, payments: [DebtPaymentRecord]) -> Int64 {
        max(0, debt.amountMinor - paid(debt, payments: payments))
    }

    static func status(_ debt: DebtRecord, payments: [DebtPaymentRecord], now: Date, calendar: Calendar) -> DebtStatus {
        if remaining(debt, payments: payments) == 0 { return .saldada }
        if let due = debt.dueDate, calendar.startOfDay(for: due) < calendar.startOfDay(for: now) { return .vencida }
        return .pendiente
    }

    /// Un abono no puede pasarse de lo que falta.
    static func clampPayment(_ amountMinor: Int64, remaining: Int64) -> Int64 {
        max(0, min(amountMinor, remaining))
    }

    /// Fecha del último abono (para ordenar las saldadas).
    static func lastPaymentDate(_ debt: DebtRecord, payments: [DebtPaymentRecord]) -> Date? {
        payments.filter { $0.debtId == debt.id }.map(\.date).max()
    }

    /// Las deudas abiertas, la que vence primero arriba (sin fecha al final), luego la más nueva.
    static func open(_ debts: [DebtRecord], payments: [DebtPaymentRecord]) -> [DebtRecord] {
        debts.filter { remaining($0, payments: payments) > 0 }.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.date > b.date
            }
        }
    }

    /// Las saldadas, la que se saldó más reciente arriba.
    static func settled(_ debts: [DebtRecord], payments: [DebtPaymentRecord]) -> [DebtRecord] {
        debts.filter { remaining($0, payments: payments) == 0 }.sorted {
            (lastPaymentDate($0, payments: payments) ?? $0.date) > (lastPaymentDate($1, payments: payments) ?? $1.date)
        }
    }

    /// Una fila por persona con deudas abiertas, la de más plata arriba.
    static func people(_ debts: [DebtRecord], payments: [DebtPaymentRecord]) -> [PersonDebts] {
        var byKey: [String: PersonDebts] = [:]
        var newest: [String: Date] = [:]
        for debt in debts {
            let left = remaining(debt, payments: payments)
            guard left > 0 else { continue }
            let key = personKey(debt.person)
            var person = byKey[key] ?? PersonDebts(key: key, name: cleanName(debt.person), owedToMeMinor: 0, iOweMinor: 0, openCount: 0)
            if debt.direction == .meDebe { person.owedToMeMinor += left } else { person.iOweMinor += left }
            person.openCount += 1
            if debt.date >= (newest[key] ?? .distantPast) {
                newest[key] = debt.date
                person.name = cleanName(debt.person)
            }
            byKey[key] = person
        }
        return byKey.values.sorted { a, b in
            abs(a.netMinor) != abs(b.netMinor) ? abs(a.netMinor) > abs(b.netMinor) : a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    /// Todas las deudas (abiertas y saldadas) de una persona.
    static func debts(of key: String, in debts: [DebtRecord]) -> [DebtRecord] {
        debts.filter { personKey($0.person) == key }
    }

    static func totals(_ debts: [DebtRecord], payments: [DebtPaymentRecord]) -> DebtTotals {
        var totals = DebtTotals(owedToMeMinor: 0, iOweMinor: 0)
        for debt in debts {
            let left = remaining(debt, payments: payments)
            if debt.direction == .meDebe { totals.owedToMeMinor += left } else { totals.iOweMinor += left }
        }
        return totals
    }

    /// "Te deben $ 350.000 · Debes $ 80.000". Sin nada pendiente: "Nadie te debe y no debes nada".
    static func summaryText(_ totals: DebtTotals, currency: Currency) -> String {
        var parts: [String] = []
        if totals.owedToMeMinor > 0 { parts.append("Te deben \(Money(minor: totals.owedToMeMinor, currency: currency).formatted())") }
        if totals.iOweMinor > 0 { parts.append("Debes \(Money(minor: totals.iOweMinor, currency: currency).formatted())") }
        return parts.isEmpty ? "Nadie te debe y no debes nada" : parts.joined(separator: " · ")
    }

    /// Lo que se dice al lado del monto de una persona: "te debe", "le debes" o "a mano".
    static func netLabel(_ person: PersonDebts) -> String {
        person.netMinor > 0 ? "te debe" : person.netMinor < 0 ? "le debes" : "a mano"
    }

    /// Nombres ya usados que empiezan (o tienen una palabra que empieza) por lo escrito, sin repetir. Vacío: los más recientes.
    static func suggestions(for typed: String, debts: [DebtRecord], limit: Int = 5) -> [String] {
        let query = personKey(typed)
        var seen = Set<String>()
        var out: [String] = []
        for debt in debts.sorted(by: { $0.date > $1.date }) {
            let key = personKey(debt.person)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            if query.isEmpty || (key != query && (key.hasPrefix(query) || key.split(separator: " ").contains { $0.hasPrefix(query) })) {
                out.append(cleanName(debt.person))
            }
            if out.count == limit { break }
        }
        return out
    }

    /// La plata sale de la cuenta elegida al prestar (me debe) y al pagar lo que debo; entra al pedir prestado y al recibir un abono.
    static func moneyLeaves(_ direction: DebtDirection, isPayment: Bool) -> Bool {
        (direction == .meDebe) != isPayment
    }

    /// Las dos puntas de la transferencia que mueve la plata en la cuenta elegida.
    static func transferEnds(productId: UUID, direction: DebtDirection, isPayment: Bool) -> (from: UUID, to: UUID) {
        moneyLeaves(direction, isPayment: isPayment) ? (productId, outsideProductId) : (outsideProductId, productId)
    }

    /// Pregunta del producto en el formulario.
    static func productQuestion(_ direction: DebtDirection, isPayment: Bool) -> String {
        moneyLeaves(direction, isPayment: isPayment) ? "¿De dónde salió la plata?" : "¿A dónde llegó?"
    }

    /// Nota de la transferencia: "Préstamo a Ana", "Abono de Ana".
    static func transferNote(person: String, direction: DebtDirection, isPayment: Bool) -> String {
        let name = cleanName(person)
        switch (direction, isPayment) {
        case (.meDebe, false): return "Préstamo a \(name)"
        case (.leDebo, false): return "Préstamo de \(name)"
        case (.meDebe, true): return "Abono de \(name)"
        case (.leDebo, true): return "Abono a \(name)"
        }
    }

    /// El día antes de la fecha límite a la hora de los avisos. Nil si no tiene fecha, ya está saldada o la hora ya pasó.
    static func reminderDate(_ debt: DebtRecord, payments: [DebtPaymentRecord], atMinutes: Int, now: Date, calendar: Calendar) -> Date? {
        guard let due = debt.dueDate, remaining(debt, payments: payments) > 0 else { return nil }
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: due)),
              let fire = calendar.date(byAdding: .minute, value: max(0, min(1439, atMinutes)), to: dayBefore) else { return nil }
        return fire > now ? fire : nil
    }

    /// Avisos del día antes de cada fecha límite. Ids "mp.deuda.<id>" para que se borren y se vuelvan a crear con los demás.
    static func reminders(_ debts: [DebtRecord], payments: [DebtPaymentRecord], atMinutes: Int, currency: Currency,
                          now: Date, calendar: Calendar) -> [PlannedNotification] {
        debts.compactMap { debt in
            guard let fire = reminderDate(debt, payments: payments, atMinutes: atMinutes, now: now, calendar: calendar) else { return nil }
            let amount = Money(minor: remaining(debt, payments: payments), currency: currency).formatted()
            let name = cleanName(debt.person)
            let title = debt.direction == .meDebe ? "Mañana \(name) te paga" : "Mañana le pagas a \(name)"
            let body = debt.direction == .meDebe
                ? "Quedó de pagarte \(amount). Si quieres, recuérdale desde Dinero."
                : "Le debes \(amount). Si ya le pagaste, anota el abono en Dinero."
            return PlannedNotification(id: "mp.deuda.\(debt.id.uuidString.lowercased())", fireDate: fire, title: title, body: body)
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// Mensaje amable para recordarle a alguien lo que te debe. Se comparte con la hoja del sistema.
    static func shareText(person: String, remainingMinor: Int64, dueDate: Date?, currency: Currency, now: Date, calendar: Calendar) -> String {
        let name = cleanName(person).split(separator: " ").first.map(String.init) ?? cleanName(person)
        let amount = Money(minor: remainingMinor, currency: currency).formatted()
        var text = "Hola \(name), ¿cómo vas? Te escribo para recordarte los \(amount) que te presté."
        if let dueDate {
            let day = calendar.component(.day, from: dueDate)
            let month = DueText.monthName(dueDate, calendar: calendar)
            let passed = calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now)
            text += " Quedamos para el \(day) de \(month)."
            text += passed ? " Cuando puedas me los pasas." : " Si puedes, me los pasas para esa fecha."
        } else {
            text += " Cuando puedas me los pasas."
        }
        return text + " Gracias."
    }

    /// Lo que le falta a la persona por pagarte y la fecha límite más cercana, para "Recordarle".
    static func owedToMe(by key: String, debts: [DebtRecord], payments: [DebtPaymentRecord]) -> (remainingMinor: Int64, dueDate: Date?) {
        let mine = Self.debts(of: key, in: debts).filter { $0.direction == .meDebe && remaining($0, payments: payments) > 0 }
        let total = mine.reduce(Int64(0)) { $0 + remaining($1, payments: payments) }
        return (total, mine.compactMap(\.dueDate).min())
    }
}

extension BackupSnapshot {
    /// Deuda con una persona (entidad "debts" en la nube). `transferId` es la transferencia que movió la plata, si hubo.
    struct DebtRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var person: String; var directionRaw: String; var amountMinor: Int64; var occurredAt: Date
        var dueDate: Date?; var notes: String?; var productId: UUID?; var transferId: UUID?
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    /// Abono a una deuda (entidad "debt_payments").
    struct DebtPaymentRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var debtId: UUID; var amountMinor: Int64; var occurredAt: Date
        var productId: UUID?; var transferId: UUID?
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }
}
