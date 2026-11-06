import Foundation
import SwiftData
import Observation

/// Estado de Agregar movimiento (pantalla 7).
@MainActor
@Observable
final class AddEntryModel {
    enum CycleChoice: String, CaseIterable, Identifiable {
        case puntual, mensual, anual, otra
        var id: String { rawValue }

        var title: String {
            switch self {
            case .puntual: "Puntual"
            case .mensual: "Mensual"
            case .anual: "Anual"
            case .otra: "Otra"
            }
        }
    }

    var kind: EntryKind
    var name = ""
    var icon: String?
    var amount: AmountInput
    var cycleChoice: CycleChoice
    var everyDays = 15
    var date = Date.now
    var categoryId: UUID?
    var notes = ""
    /// Con qué se pagó (F06-04). Nil: sin elegir.
    var productId: UUID?
    var method: PayMethod?
    /// De dónde viene: manual o un recibo escaneado.
    var source: EntrySource = .manual
    /// Movimiento que se está editando (F04-02). Al editar no se cambia el ciclo.
    private(set) var editing: Entry?

    init(kind: EntryKind = .gasto, cycle: CycleChoice = .puntual, currency: Currency = .cop) {
        self.kind = kind
        self.cycleChoice = cycle
        self.amount = AmountInput(currency: currency)
    }

    init(editing entry: Entry, currency: Currency = .cop) {
        self.editing = entry
        self.kind = entry.kind
        self.name = entry.name
        self.icon = entry.icon
        self.amount = AmountInput(minor: entry.amountMinor, currency: currency)
        self.cycleChoice = .puntual
        self.date = entry.occurredAt
        self.categoryId = entry.categoryId
        self.notes = entry.notes ?? ""
        self.productId = entry.productId
        self.method = entry.methodRaw.flatMap(PayMethod.init(rawValue:))
    }

    /// Borrador desde un recibo escaneado (F08-05): nombre y monto ya puestos, todo editable.
    init(prefillName: String, amountMinor: Int64, source: EntrySource, currency: Currency = .cop) {
        self.kind = .gasto
        self.cycleChoice = .puntual
        self.name = prefillName
        self.amount = AmountInput(minor: amountMinor, currency: currency)
        self.source = source
    }

    var isEditing: Bool { editing != nil }

    var cycle: Cycle {
        switch cycleChoice {
        case .puntual: .puntual
        case .mensual: .mensual
        case .anual: .anual
        case .otra: .cadaDias(max(1, everyDays))
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount.money.minor > 0
    }

    /// "Mensual · cobra el 8 de cada mes", "Puntual", "Cada 15 días".
    func cycleSummary(calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        switch cycle {
        case .puntual: return "Puntual"
        case .mensual: return "Mensual · el \(day) de cada mes"
        case .anual: return "Anual · cada \(day) de \(DueText.monthName(date, calendar: calendar))"
        case .semanal: return "Semanal"
        case .cadaDias(let days): return "Cada \(days) días"
        }
    }

    /// Guarda según AddPlan y devuelve el movimiento creado, si hubo.
    @discardableResult
    func save(context: ModelContext, spaceId: UUID, now: Date = .now, calendar: Calendar = .current) throws -> Entry? {
        let ledger = LedgerStore(context: context, calendar: calendar)
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = AddPlan.decide(cycle: cycle, date: date, now: now, calendar: calendar)
        let user = LocalIdentity.userId

        if let editing {
            try ledger.update(editing, kind: kind, amountMinor: amount.money.minor, name: cleanName, occurredAt: date,
                              categoryId: categoryId, icon: icon, notes: cleanNotes.isEmpty ? nil : cleanNotes,
                              productId: productId, method: method?.rawValue, now: now)
            return editing
        }

        var created: Entry?
        if let entryDate = plan.entryDate {
            let entry = try ledger.addEntry(spaceId: spaceId, kind: kind, amountMinor: amount.money.minor, name: cleanName,
                                            occurredAt: entryDate, categoryId: categoryId, productId: productId,
                                            method: method?.rawValue, source: source.rawValue, createdBy: user)
            entry.icon = icon
            entry.notes = cleanNotes.isEmpty ? nil : cleanNotes
            created = entry
        }
        if let next = plan.recurringNext {
            let item = try ledger.addRecurring(spaceId: spaceId, kind: kind, name: cleanName, amountMinor: amount.money.minor,
                                               cycle: cycle, nextDate: next, categoryId: categoryId, productId: productId, createdBy: user)
            item.icon = icon
            if let created { created.recurringId = item.id }
        }
        try context.save()
        return created
    }
}
