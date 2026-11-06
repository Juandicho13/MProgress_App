import Foundation
import SwiftData

/// Movimientos y pagos fijos de un espacio. Todo cambio pasa por aquí (HANDOFF 7).
@MainActor
final class LedgerStore {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: Movimientos

    @discardableResult
    func addEntry(spaceId: UUID, kind: EntryKind, amountMinor: Int64, name: String, occurredAt: Date = .now,
                  categoryId: UUID? = nil, productId: UUID? = nil, method: String? = nil,
                  source: String = "manual", notes: String? = nil, createdBy: UUID? = nil) throws -> Entry {
        precondition(amountMinor > 0, "El monto va siempre positivo; el tipo dice si entra o sale")
        let entry = Entry(spaceId: spaceId, kind: kind, amountMinor: amountMinor, occurredAt: occurredAt, name: name)
        entry.categoryId = categoryId
        entry.productId = productId
        entry.methodRaw = method
        // Editarlo es revisarlo: lo que llegó por SMS o Apple Pay deja de estar "por revisar".
        entry.needsReview = false
        entry.sourceRaw = source
        entry.notes = notes
        entry.createdBy = createdBy
        entry.paidBy = createdBy
        entry.touch()
        context.insert(entry)
        if let categoryId { markCategoryUsed(categoryId) }
        try context.save()
        return entry
    }

    func entries(spaceId: UUID, in interval: DateInterval? = nil) throws -> [Entry] {
        var descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        if let interval {
            let start = interval.start
            let end = interval.end
            descriptor.predicate = #Predicate<Entry> {
                $0.spaceId == spaceId && $0.deletedAt == nil && $0.occurredAt >= start && $0.occurredAt < end
            }
        }
        return try context.fetch(descriptor)
    }

    /// Cambia un movimiento (F04-02). El monto va siempre positivo.
    func update(_ entry: Entry, kind: EntryKind, amountMinor: Int64, name: String, occurredAt: Date,
                categoryId: UUID?, icon: String?, notes: String?, productId: UUID? = nil, method: String? = nil,
                now: Date = .now) throws {
        precondition(amountMinor > 0, "El monto va siempre positivo")
        entry.productId = productId
        entry.methodRaw = method
        // Editarlo es revisarlo: lo que llegó por SMS o Apple Pay deja de estar "por revisar".
        entry.needsReview = false
        entry.kind = kind
        entry.amountMinor = amountMinor
        entry.name = name
        entry.occurredAt = occurredAt
        entry.icon = icon
        entry.notes = notes
        if entry.categoryId != categoryId, let categoryId { markCategoryUsed(categoryId) }
        entry.categoryId = categoryId
        entry.touch(now)
        try context.save()
    }

    /// Copia un movimiento en otra fecha (hoy por defecto). La copia no queda enlazada al pago fijo.
    @discardableResult
    func duplicate(_ entry: Entry, on date: Date = .now, by userId: UUID? = nil) throws -> Entry {
        let copy = try addEntry(spaceId: entry.spaceId, kind: entry.kind, amountMinor: entry.amountMinor, name: entry.name,
                                occurredAt: date, categoryId: entry.categoryId, productId: entry.productId,
                                method: entry.methodRaw, notes: entry.notes, createdBy: userId)
        copy.icon = entry.icon
        copy.merchant = entry.merchant
        try context.save()
        return copy
    }

    // MARK: Pagos fijos

    @discardableResult
    func addRecurring(spaceId: UUID, kind: EntryKind, name: String, amountMinor: Int64, cycle: Cycle,
                      nextDate: Date, categoryId: UUID? = nil, productId: UUID? = nil, createdBy: UUID? = nil) throws -> Recurring {
        precondition(amountMinor > 0, "El monto va siempre positivo")
        let item = Recurring(spaceId: spaceId, kind: kind, name: name, amountMinor: amountMinor, cycle: cycle, nextDate: nextDate, calendar: calendar)
        item.categoryId = categoryId
        item.productId = productId
        item.createdBy = createdBy
        item.touch()
        context.insert(item)
        try context.save()
        return item
    }

    func recurring(spaceId: UUID) throws -> [Recurring] {
        try context.fetch(FetchDescriptor<Recurring>(
            predicate: #Predicate<Recurring> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.nextDate)]
        ))
    }

    /// Marca pagado un pago fijo: crea el movimiento y mueve la próxima fecha (HANDOFF 8.2).
    /// Un pago puntual queda inactivo.
    @discardableResult
    func markPaid(_ item: Recurring, on date: Date = .now, by userId: UUID? = nil) throws -> Entry {
        let entry = try addEntry(spaceId: item.spaceId, kind: item.kind, amountMinor: item.amountMinor, name: item.name,
                                 occurredAt: date, categoryId: item.categoryId, productId: item.productId, createdBy: userId)
        entry.recurringId = item.id
        entry.icon = item.icon
        if let next = CycleMath.next(after: item.nextDate, cycle: item.cycle, anchor: item.anchor, calendar: calendar) {
            item.nextDate = next
        } else {
            item.active = false
        }
        item.touch()
        try context.save()
        return entry
    }

    /// Deshace un "marcar pagado": borra el movimiento creado y devuelve la fecha y el estado de antes.
    func undoPaid(_ item: Recurring, entry: Entry, previousNext: Date, wasActive: Bool, now: Date = .now) throws {
        entry.deletedAt = now
        entry.touch(now)
        item.nextDate = previousNext
        item.active = wasActive
        item.touch(now)
        try context.save()
    }

    // MARK: Borrado suave

    func softDelete<T: PersistentModel & SyncTracked>(_ item: T, now: Date = .now) throws {
        item.deletedAt = now
        item.touch(now)
        try context.save()
    }

    func restore<T: PersistentModel & SyncTracked>(_ item: T, now: Date = .now) throws {
        item.deletedAt = nil
        item.touch(now)
        try context.save()
    }

    // MARK: Resumen

    func monthSummary(spaceId: UUID, now: Date = .now) throws -> MonthSummary {
        let month = BalanceCalculator.monthInterval(containing: now, calendar: calendar)
        return BalanceCalculator.monthSummary(
            entries: try entries(spaceId: spaceId, in: month).map(\.record),
            recurring: try recurring(spaceId: spaceId).map(\.record),
            now: now,
            calendar: calendar
        )
    }

    /// Categorías globales y del espacio, recientes primero.
    func categories(spaceId: UUID) throws -> [SpendCategory] {
        let all = try context.fetch(FetchDescriptor<SpendCategory>(
            predicate: #Predicate<SpendCategory> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sort)]
        ))
        return all.filter { $0.ownerSpaceId == nil || $0.ownerSpaceId == spaceId }
    }

    private func markCategoryUsed(_ id: UUID) {
        let descriptor = FetchDescriptor<SpendCategory>(predicate: #Predicate<SpendCategory> { $0.id == id })
        if let category = try? context.fetch(descriptor).first {
            category.lastUsedAt = .now
        }
    }
}
