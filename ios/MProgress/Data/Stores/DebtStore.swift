import Foundation
import SwiftData

/// Quién te debe: deudas con otras personas y sus abonos. Todo cambio pone la fecha y queda pendiente de sincronizar.
/// Si la persona dice por qué cuenta pasó la plata, se guarda una transferencia contra `DebtMath.outsideProductId`
/// (un producto que no existe), así el saldo de esa cuenta queda bien sin contar como gasto ni ingreso del mes.
@MainActor
final class DebtStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func debts(spaceId: UUID) throws -> [Debt] {
        try context.fetch(FetchDescriptor<Debt>(
            predicate: #Predicate<Debt> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        ))
    }

    func payments(spaceId: UUID) throws -> [DebtPayment] {
        try context.fetch(FetchDescriptor<DebtPayment>(
            predicate: #Predicate<DebtPayment> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
    }

    func payments(of debt: Debt) throws -> [DebtPayment] {
        let id = debt.id
        return try context.fetch(FetchDescriptor<DebtPayment>(
            predicate: #Predicate<DebtPayment> { $0.debtId == id && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
    }

    func remaining(_ debt: Debt) throws -> Int64 {
        DebtMath.remaining(debt.record, payments: try payments(of: debt).map(\.record))
    }

    /// Crea o cambia una deuda. Con cuenta, crea o ajusta su transferencia; sin cuenta, la borra si había.
    @discardableResult
    func save(_ existing: Debt?, spaceId: UUID, person: String, direction: DebtDirection, amountMinor: Int64, date: Date,
              dueDate: Date?, note: String?, productId: UUID?, now: Date = .now) throws -> Debt {
        precondition(amountMinor > 0, "La deuda va siempre positiva")
        let name = DebtMath.cleanName(person)
        let movedSide = existing.map { $0.direction != direction || $0.person != name } ?? false
        let debt = existing ?? {
            let created = Debt(spaceId: spaceId, person: name, direction: direction, amountMinor: amountMinor, occurredAt: date)
            context.insert(created)
            return created
        }()
        debt.person = name
        debt.direction = direction
        debt.amountMinor = amountMinor
        debt.occurredAt = date
        debt.dueDate = dueDate
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        debt.notes = cleanNote.isEmpty ? nil : cleanNote
        debt.productId = productId
        debt.transferId = try linkTransfer(debt.transferId, spaceId: spaceId, productId: productId, direction: direction, isPayment: false,
                                           amountMinor: amountMinor, date: date, person: name, now: now)
        // Si cambió la dirección o el nombre, los abonos con cuenta mueven la plata al otro lado.
        if movedSide {
            for payment in try payments(of: debt) where payment.productId != nil {
                payment.transferId = try linkTransfer(payment.transferId, spaceId: spaceId, productId: payment.productId, direction: direction,
                                                      isPayment: true, amountMinor: payment.amountMinor, date: payment.occurredAt,
                                                      person: name, now: now)
            }
        }
        debt.touch(now)
        try context.save()
        return debt
    }

    /// Abono. No pasa de lo que falta; devuelve nil si no queda nada por pagar.
    @discardableResult
    func addPayment(to debt: Debt, amountMinor: Int64, date: Date, productId: UUID?, now: Date = .now) throws -> DebtPayment? {
        let amount = DebtMath.clampPayment(amountMinor, remaining: try remaining(debt))
        guard amount > 0 else { return nil }
        let payment = DebtPayment(spaceId: debt.spaceId, debtId: debt.id, amountMinor: amount, occurredAt: date)
        payment.productId = productId
        payment.transferId = try linkTransfer(nil, spaceId: debt.spaceId, productId: productId, direction: debt.direction, isPayment: true,
                                              amountMinor: amount, date: date, person: debt.person, now: now)
        payment.touch(now)
        context.insert(payment)
        // La deuda también cambia de estado (lo nota la nube y el otro teléfono sabe que se movió).
        debt.touch(now)
        try context.save()
        return payment
    }

    /// Salda lo que falta con un solo abono.
    @discardableResult
    func settle(_ debt: Debt, date: Date = .now, productId: UUID?, now: Date = .now) throws -> DebtPayment? {
        try addPayment(to: debt, amountMinor: try remaining(debt), date: date, productId: productId, now: now)
    }

    /// Borra un abono y su transferencia.
    func delete(_ payment: DebtPayment, now: Date = .now) throws {
        payment.deletedAt = now
        payment.touch(now)
        try deleteTransfer(payment.transferId, now: now)
        try context.save()
    }

    /// Borra la deuda con sus abonos y transferencias. Devuelve lo que se borró, para Deshacer.
    @discardableResult
    func delete(_ debt: Debt, now: Date = .now) throws -> [DebtPayment] {
        let removed = try payments(of: debt)
        for payment in removed {
            payment.deletedAt = now
            payment.touch(now)
            try deleteTransfer(payment.transferId, now: now)
        }
        debt.deletedAt = now
        debt.touch(now)
        try deleteTransfer(debt.transferId, now: now)
        try context.save()
        return removed
    }

    /// Deshacer el borrado: vuelve la deuda, los abonos que se borraron con ella y sus transferencias.
    func restore(_ debt: Debt, payments: [DebtPayment], now: Date = .now) throws {
        debt.deletedAt = nil
        debt.touch(now)
        try restoreTransfer(debt.transferId, now: now)
        for payment in payments {
            payment.deletedAt = nil
            payment.touch(now)
            try restoreTransfer(payment.transferId, now: now)
        }
        try context.save()
    }

    // MARK: Transferencias

    private func transfer(_ id: UUID?) throws -> Transfer? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Transfer>(predicate: #Predicate<Transfer> { $0.id == id })).first
    }

    /// La transferencia de una deuda o un abono: la crea, la ajusta o la borra si ya no hay cuenta. Devuelve su id.
    private func linkTransfer(_ id: UUID?, spaceId: UUID, productId: UUID?, direction: DebtDirection, isPayment: Bool,
                              amountMinor: Int64, date: Date, person: String, now: Date) throws -> UUID? {
        guard let productId, amountMinor > 0 else {
            try deleteTransfer(id, now: now)
            return nil
        }
        let ends = DebtMath.transferEnds(productId: productId, direction: direction, isPayment: isPayment)
        let link = try transfer(id) ?? {
            let created = Transfer(spaceId: spaceId, fromProductId: ends.from, toProductId: ends.to, amountMinor: amountMinor, occurredAt: date)
            context.insert(created)
            return created
        }()
        link.fromProductId = ends.from
        link.toProductId = ends.to
        link.amountMinor = amountMinor
        link.occurredAt = date
        link.notes = DebtMath.transferNote(person: person, direction: direction, isPayment: isPayment)
        link.deletedAt = nil
        link.touch(now)
        return link.id
    }

    private func deleteTransfer(_ id: UUID?, now: Date) throws {
        guard let link = try transfer(id), link.deletedAt == nil else { return }
        link.deletedAt = now
        link.touch(now)
    }

    private func restoreTransfer(_ id: UUID?, now: Date) throws {
        guard let link = try transfer(id), link.deletedAt != nil else { return }
        link.deletedAt = nil
        link.touch(now)
    }
}
