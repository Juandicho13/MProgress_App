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
        adjustPoints(for: entry, sign: 1)
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
        // Los puntos se recalculan: se quitan los del monto y la tarjeta de antes y se suman los nuevos.
        if entry.deletedAt == nil { adjustPoints(for: entry, sign: -1) }
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
        if entry.deletedAt == nil { adjustPoints(for: entry, sign: 1) }
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

    /// Crea un pago fijo. `endDate` (incluida) y `totalCount` le ponen fin; `paidCount` son las cuotas que ya cuentan.
    /// Si ya no le quedan cobros, queda inactivo.
    @discardableResult
    func addRecurring(spaceId: UUID, kind: EntryKind, name: String, amountMinor: Int64, cycle: Cycle,
                      nextDate: Date, categoryId: UUID? = nil, productId: UUID? = nil, createdBy: UUID? = nil,
                      endDate: Date? = nil, totalCount: Int? = nil, paidCount: Int = 0) throws -> Recurring {
        precondition(amountMinor > 0, "El monto va siempre positivo")
        let item = Recurring(spaceId: spaceId, kind: kind, name: name, amountMinor: amountMinor, cycle: cycle, nextDate: nextDate, calendar: calendar)
        item.categoryId = categoryId
        item.productId = productId
        item.createdBy = createdBy
        item.endDate = endDate.map { calendar.startOfDay(for: $0) }
        item.totalCount = totalCount.map { max(1, $0) }
        item.paidCount = max(0, paidCount)
        if item.isFinished(calendar: calendar) { item.active = false }
        item.touch()
        context.insert(item)
        try context.save()
        return item
    }

    /// Cambia un pago fijo desde la zona de pagos fijos. Poner fecha le quita el "sin fecha".
    /// Si con el nuevo fin ya no le quedan cobros, queda inactivo; si estaba terminado y ahora le quedan, vuelve a estar activo.
    func updateRecurring(_ item: Recurring, kind: EntryKind, name: String, amountMinor: Int64, cycle: Cycle,
                         nextDate: Date?, productId: UUID?, categoryId: UUID?, active: Bool,
                         endDate: Date? = nil, totalCount: Int? = nil, anchorDay: Int? = nil, now: Date = .now) throws {
        precondition(amountMinor > 0, "El monto va siempre positivo")
        let wasFinished = (item.endDate != nil || item.totalCount != nil) && item.isFinished(calendar: calendar)
        item.kind = kind
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.amountMinor = amountMinor
        item.cycle = cycle
        if let nextDate {
            // Si la fecha no cambió se deja como estaba, con su ancla (un mensual del 31 que hoy cae el 30 sigue del 31).
            if item.dateUnset || !calendar.isDate(nextDate, inSameDayAs: item.nextDate) {
                item.nextDate = calendar.startOfDay(for: nextDate)
                let anchor = CycleAnchor(date: nextDate, calendar: calendar)
                item.anchorDay = anchor.day
                item.anchorMonth = anchor.month
            }
            if let anchorDay { item.anchorDay = min(31, max(1, anchorDay)) }
            item.dateUnset = false
        }
        item.productId = productId
        if item.categoryId != categoryId, let categoryId { markCategoryUsed(categoryId) }
        item.categoryId = categoryId
        item.endDate = endDate.map { calendar.startOfDay(for: $0) }
        item.totalCount = totalCount.map { max(1, $0) }
        if item.isFinished(calendar: calendar) {
            item.active = false
        } else {
            item.active = wasFinished ? true : active
        }
        item.touch(now)
        try context.save()
    }

    /// Cambia solo el monto de un pago fijo (arreglo rápido del sueldo en Inicio). Queda pendiente de sincronizar.
    func setRecurringAmount(_ item: Recurring, amountMinor: Int64, now: Date = .now) throws {
        precondition(amountMinor > 0, "El monto va siempre positivo")
        item.amountMinor = amountMinor
        item.touch(now)
        try context.save()
    }

    /// Arregla el monto de unos movimientos (el sueldo de $ 2 que debía ser $ 2.000.000) sin tocar lo demás.
    func setEntryAmounts(_ entries: [Entry], amountMinor: Int64, now: Date = .now) throws {
        precondition(amountMinor > 0, "El monto va siempre positivo")
        for entry in entries {
            if entry.deletedAt == nil { adjustPoints(for: entry, sign: -1) }
            entry.amountMinor = amountMinor
            entry.touch(now)
            if entry.deletedAt == nil { adjustPoints(for: entry, sign: 1) }
        }
        try context.save()
    }

    func recurring(spaceId: UUID) throws -> [Recurring] {
        try context.fetch(FetchDescriptor<Recurring>(
            predicate: #Predicate<Recurring> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.nextDate)]
        ))
    }

    /// Marca pagado un pago fijo: crea el movimiento, suma una cuota y mueve la próxima fecha (HANDOFF 8.2).
    /// Un pago puntual, uno que llegó a su última cuota o uno cuya siguiente fecha pasa del fin queda inactivo
    /// (terminado). Para saber si terminó por su fin: `finishedByEnd` después de llamar.
    /// `amountMinor`: lo que se pagó de verdad, si no fue lo planeado (el pago fijo conserva su monto).
    @discardableResult
    func markPaid(_ item: Recurring, on date: Date = .now, by userId: UUID? = nil, amountMinor: Int64? = nil) throws -> Entry {
        let paid = amountMinor.flatMap { $0 > 0 ? $0 : nil } ?? item.amountMinor
        let entry = try addEntry(spaceId: item.spaceId, kind: item.kind, amountMinor: paid, name: item.name,
                                 occurredAt: date, categoryId: item.categoryId, productId: item.productId, createdBy: userId)
        entry.recurringId = item.id
        entry.icon = item.icon
        let payment = RecurringEnd.afterPayment(nextDate: item.nextDate, cycle: item.cycle, anchor: item.anchor,
                                                endDate: item.endDate, totalCount: item.totalCount,
                                                paidCount: item.paidCount, calendar: calendar)
        item.paidCount = payment.paidCount
        if let next = payment.nextDate { item.nextDate = next }
        if payment.finished { item.active = false }
        item.touch()
        try context.save()
        return entry
    }

    /// Terminó porque se acabaron sus cuotas o pasó su fecha final (no porque sea puntual).
    func finishedByEnd(_ item: Recurring) -> Bool {
        (item.endDate != nil || item.totalCount != nil) && item.isFinished(calendar: calendar)
    }

    /// Deshace un "marcar pagado": borra el movimiento creado, quita la cuota y devuelve la fecha y el estado de antes.
    func undoPaid(_ item: Recurring, entry: Entry, previousNext: Date, wasActive: Bool, now: Date = .now) throws {
        if entry.deletedAt == nil { adjustPoints(for: entry, sign: -1) }
        entry.deletedAt = now
        entry.touch(now)
        item.nextDate = previousNext
        item.active = wasActive
        item.paidCount = max(0, item.paidCount - 1)
        item.touch(now)
        try context.save()
    }

    // MARK: Borrado suave

    func softDelete<T: PersistentModel & SyncTracked>(_ item: T, now: Date = .now) throws {
        // Borrar un gasto con tarjeta resta los puntos que dio.
        if let entry = item as? Entry, entry.deletedAt == nil { adjustPoints(for: entry, sign: -1) }
        item.deletedAt = now
        item.touch(now)
        try context.save()
    }

    func restore<T: PersistentModel & SyncTracked>(_ item: T, now: Date = .now) throws {
        if let entry = item as? Entry, entry.deletedAt != nil { adjustPoints(for: entry, sign: 1) }
        item.deletedAt = nil
        item.touch(now)
        try context.save()
    }

    // MARK: Puntos por tarjeta

    /// Suma (`sign` = 1) o resta (-1) los puntos que da un gasto con una tarjeta que acumula en un programa:
    /// floor(monto / 1.000 × puntos por cada 1.000). No guarda: lo hace quien llama.
    func adjustPoints(for entry: Entry, sign: Int64) {
        guard entry.kind == .gasto, let productId = entry.productId else { return }
        let productQuery = FetchDescriptor<Product>(predicate: #Predicate<Product> { $0.id == productId })
        guard let product = try? context.fetch(productQuery).first,
              let programId = product.rewardProgramId, let rate = product.pointsPerThousand else { return }
        let rewardQuery = FetchDescriptor<RewardProgram>(predicate: #Predicate<RewardProgram> { $0.id == programId })
        guard let reward = try? context.fetch(rewardQuery).first, reward.deletedAt == nil else { return }
        let spaceId = entry.spaceId
        let space = try? context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.id == spaceId })).first
        let points = RewardMath.pointsEarned(amountMinor: entry.amountMinor, currency: space?.currency ?? .cop, pointsPerThousand: rate)
        guard points > 0 else { return }
        reward.balance = max(0, reward.balance + sign * points)
        reward.touch()
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
