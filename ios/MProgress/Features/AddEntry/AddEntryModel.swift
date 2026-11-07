import Foundation
import SwiftData
import Observation

/// Estado de Agregar movimiento (pantalla 7).
@MainActor
@Observable
final class AddEntryModel {
    /// Con qué ciclo se abre Agregar (Inicio pide .puntual, .mensual o .anual). Lo que se elige adentro va en `repeatDraft`.
    typealias CycleChoice = Cycle

    var kind: EntryKind
    var name = ""
    var icon: String?
    var amount: AmountInput
    /// "¿Se repite?": Una vez, Semanal, Quincenal, Mensual u Otra (con Cada N días, semanas, meses o años).
    /// Las opciones se cambian con `selectRepeat` y los días de quincena con `setQuincena`; lo de Otra se escribe directo.
    var repeatDraft: RepeatDraft
    var date = Date.now
    var categoryId: UUID?
    var notes = ""
    /// Con qué se pagó (F06-04). Nil: sin elegir.
    var productId: UUID?
    var method: PayMethod?
    /// De dónde viene: manual o un recibo escaneado.
    var source: EntrySource = .manual
    /// Comercio tal como llegó (recibo), para aprender el nombre que le da la persona.
    private(set) var rawMerchant: String?
    /// Fecha que tenía antes de que Quincenal la moviera al próximo día de quincena (para devolverla si se cambia de opción).
    @ObservationIgnored private var dateBeforeQuincena: (before: Date, set: Date)?
    /// Pagos fijos mensuales: día elegido en la cuadrícula de 1 a 31 (nil: el de `date`) y, si ya pasó
    /// este mes, si ya se pagó. La cuadrícula escribe en `date`, que sigue siendo la fecha que se guarda.
    private(set) var pickedDay: Int?
    private(set) var paidThisMonth = true
    /// Cómo termina un pago fijo: nunca, en una fecha o después de N cuotas.
    var endChoice: RecurringEndChoice = .nunca
    var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    var totalCount = 12
    /// Al guardar se creó un pago fijo (para ofrecer los avisos en el momento justo).
    private(set) var createdRecurring = false
    /// Movimiento que se está editando (F04-02). Al editar no se cambia el ciclo.
    private(set) var editing: Entry?

    init(kind: EntryKind = .gasto, cycle: CycleChoice = .puntual, currency: Currency = .cop) {
        self.kind = kind
        self.repeatDraft = RepeatDraft(cycle: cycle)
        self.amount = AmountInput(currency: currency)
        if case .quincenal(let days) = cycle { date = QuincenaMath.onOrAfter(date, days: days, calendar: .current) }
    }

    init(editing entry: Entry, currency: Currency = .cop) {
        self.editing = entry
        self.kind = entry.kind
        self.name = entry.name
        self.icon = entry.icon
        self.amount = AmountInput(minor: entry.amountMinor, currency: currency)
        self.repeatDraft = RepeatDraft(choice: .unaVez)
        self.date = entry.occurredAt
        self.categoryId = entry.categoryId
        self.notes = entry.notes ?? ""
        self.productId = entry.productId
        self.method = entry.methodRaw.flatMap(PayMethod.init(rawValue:))
    }

    /// Borrador desde un recibo escaneado (F08-05): nombre y monto ya puestos, todo editable.
    /// `merchant` es el comercio leído (si el nombre ya viene de un nombre aprendido) y `categoryId` la categoría aprendida.
    init(prefillName: String, amountMinor: Int64, source: EntrySource, currency: Currency = .cop,
         merchant: String? = nil, categoryId: UUID? = nil) {
        self.kind = .gasto
        self.repeatDraft = RepeatDraft(choice: .unaVez)
        self.name = prefillName
        self.amount = AmountInput(minor: amountMinor, currency: currency)
        self.source = source
        self.categoryId = categoryId
        let raw = (merchant ?? prefillName).trimmingCharacters(in: .whitespaces)
        self.rawMerchant = source == .manual || raw.isEmpty ? nil : raw
    }

    var isEditing: Bool { editing != nil }

    var cycle: Cycle { isEditing ? .puntual : repeatDraft.cycle }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount.money.minor > 0 && (isEditing || repeatDraft.isValid)
    }

    /// Mensual o cada N meses al agregar: además del calendario, la fila "Día del mes" con la cuadrícula de 1 a 31.
    var usesDayOfMonth: Bool { !isEditing && cycle.isMonthly }

    /// Elegir en "¿Se repite?". Quincenal mueve la fecha al próximo día de quincena (o la deja si hoy lo es);
    /// al salir de Quincenal, si nadie tocó esa fecha, vuelve la de antes.
    func selectRepeat(_ choice: RepeatChoice, now: Date = .now, calendar: Calendar) {
        let wasQuincena = repeatDraft.choice == .quincenal
        repeatDraft.choice = choice
        if choice == .quincenal {
            moveToQuincena(now: now, calendar: calendar)
        } else if wasQuincena, let saved = dateBeforeQuincena, saved.set == date {
            date = saved.before
            dateBeforeQuincena = nil
        }
    }

    /// Cambiar los días de la quincena mueve la fecha al próximo de esos días.
    func setQuincena(_ days: QuincenaDays, now: Date = .now, calendar: Calendar) {
        repeatDraft.quincena = days
        moveToQuincena(now: now, calendar: calendar)
    }

    /// Elegir un día en el calendario de semana o del mes. La cuadrícula "Día del mes" pasa a ese mismo día.
    func setDate(_ newDate: Date) {
        date = newDate
        pickedDay = nil
        dateBeforeQuincena = nil
    }

    private func moveToQuincena(now: Date, calendar: Calendar) {
        let before = dateBeforeQuincena?.before ?? date
        let start = DayShortcut.combine(day: now, time: date, calendar: calendar)
        date = QuincenaMath.onOrAfter(start, days: repeatDraft.quincena, calendar: calendar)
        dateBeforeQuincena = (before, date)
    }

    /// Día que marca la cuadrícula.
    func dayOfMonth(calendar: Calendar) -> Int { pickedDay ?? calendar.component(.day, from: date) }

    /// Elegir un día en la cuadrícula: este mes si no ha pasado; si pasó, este mes si ya se pagó o el que viene si no.
    func pickDay(_ day: Int, now: Date = .now, calendar: Calendar) {
        pickedDay = min(31, max(1, day))
        date = DayOfMonth.date(day: day, now: now, alreadyPaidIfPassed: paidThisMonth, time: date, calendar: calendar)
    }

    /// "Ya lo pagué este mes" (solo cuando el día ya pasó).
    func setPaidThisMonth(_ paid: Bool, now: Date = .now, calendar: Calendar) {
        paidThisMonth = paid
        pickDay(dayOfMonth(calendar: calendar), now: now, calendar: calendar)
    }

    /// La fecha que se guarda.
    func resolvedDate(now: Date = .now, calendar: Calendar) -> Date { date }

    /// Ancla del día del mes elegido en la cuadrícula: el 31 sigue siendo del 31 aunque el mes tenga 30.
    func anchor(for date: Date, calendar: Calendar) -> CycleAnchor? {
        guard usesDayOfMonth, let pickedDay else { return nil }
        return CycleAnchor(day: pickedDay, month: calendar.component(.month, from: date))
    }

    /// "Se anota el 2 nov como pagado y el próximo cobro es el 2 dic", "Próximo cobro: 20 nov".
    func planSummary(now: Date = .now, calendar: Calendar) -> String {
        let date = resolvedDate(now: now, calendar: calendar)
        let plan = AddPlan.decide(cycle: cycle, date: date, now: now, calendar: calendar, anchor: anchor(for: date, calendar: calendar))
        let word = kind == .ingreso ? "pago" : "cobro"
        let next = plan.recurringNext.map { DueText.shortDate($0, calendar: calendar, now: now) } ?? ""
        if let entry = plan.entryDate {
            let done = kind == .ingreso ? "recibido" : "pagado"
            return "Se anota el \(DueText.shortDate(entry, calendar: calendar, now: now)) como \(done) y el próximo \(word) es el \(next)."
        }
        return "Próximo \(word): \(next)."
    }

    /// "Mensual · el 8 de cada mes", "Una vez", "Quincenal · 15 y último día", "Cada 15 días".
    func cycleSummary(calendar: Calendar) -> String {
        let date = resolvedDate(calendar: calendar)
        let day = calendar.component(.day, from: date)
        switch cycle {
        case .puntual: return "Una vez"
        case .mensual: return "Mensual · el \(day) de cada mes"
        case .cadaMeses: return "\(cycle.title) · el \(day)"
        case .anual: return "Anual · cada \(day) de \(DueText.monthName(date, calendar: calendar))"
        case .semanal, .cadaDias: return cycle.title
        case .quincenal(let days): return "Quincenal · \(days.title)"
        }
    }

    /// Bajo Otra: "Se repite cada 3 meses, el próximo es el 7 feb".
    func otherSummary(now: Date = .now, calendar: Calendar) -> String? {
        let date = resolvedDate(now: now, calendar: calendar)
        let plan = AddPlan.decide(cycle: cycle, date: date, now: now, calendar: calendar, anchor: anchor(for: date, calendar: calendar))
        return repeatDraft.summary(next: plan.recurringNext, calendar: calendar, now: now)
    }

    /// Lo que dice la fila "Termina" plegada: "Nunca", "Hasta 15 mar 2027" o "12 cuotas".
    func endSummary(calendar: Calendar) -> String {
        switch endChoice {
        case .nunca: "Nunca"
        case .fecha: "Hasta \(RecurringEnd.fullDate(endDate, calendar: calendar))"
        case .cuotas: "\(max(1, totalCount)) \(totalCount == 1 ? "cuota" : "cuotas")"
        }
    }

    /// Guarda según AddPlan y devuelve el movimiento creado, si hubo.
    @discardableResult
    func save(context: ModelContext, spaceId: UUID, now: Date = .now, calendar: Calendar = .current) throws -> Entry? {
        let ledger = LedgerStore(context: context, calendar: calendar)
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = resolvedDate(now: now, calendar: calendar)
        let plan = AddPlan.decide(cycle: cycle, date: date, now: now, calendar: calendar, anchor: anchor(for: date, calendar: calendar))
        let user = LocalIdentity.userId

        if let editing {
            try ledger.update(editing, kind: kind, amountMinor: amount.money.minor, name: cleanName, occurredAt: date,
                              categoryId: categoryId, icon: icon, notes: cleanNotes.isEmpty ? nil : cleanNotes,
                              productId: productId, method: method?.rawValue, now: now)
            // Lo que llegó solo y la persona renombró queda aprendido para el próximo pago del mismo comercio.
            try MerchantAliasStore(context: context).learn(from: editing, now: now)
            return editing
        }

        var created: Entry?
        if let entryDate = plan.entryDate {
            let entry = try ledger.addEntry(spaceId: spaceId, kind: kind, amountMinor: amount.money.minor, name: cleanName,
                                            occurredAt: entryDate, categoryId: categoryId, productId: productId,
                                            method: method?.rawValue, source: source.rawValue, createdBy: user)
            entry.icon = icon
            entry.notes = cleanNotes.isEmpty ? nil : cleanNotes
            entry.merchant = rawMerchant
            created = entry
        }
        if let next = plan.recurringNext {
            let repeats = cycle.repeats
            let item = try ledger.addRecurring(spaceId: spaceId, kind: kind, name: cleanName, amountMinor: amount.money.minor,
                                               cycle: cycle, nextDate: next, categoryId: categoryId, productId: productId, createdBy: user,
                                               endDate: repeats && endChoice == .fecha ? endDate : nil,
                                               totalCount: repeats && endChoice == .cuotas ? max(1, totalCount) : nil,
                                               paidCount: plan.elapsed)
            item.icon = icon
            if usesDayOfMonth, let pickedDay { item.anchorDay = pickedDay }
            if let created { created.recurringId = item.id }
            createdRecurring = true
        }
        try context.save()
        if let created { try MerchantAliasStore(context: context).learn(from: created, now: now) }
        return created
    }
}
