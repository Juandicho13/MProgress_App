import Foundation
import SwiftData

/// Deudas y abonos en su fila del respaldo y de vuelta (mismo patrón que BackupRows). Los usan el respaldo y la nube
/// (entidades "debts" y "debt_payments" dentro de sync_records).
extension BackupRows {
    // MARK: Deudas

    static func row(_ m: Debt) -> S.DebtRow {
        .init(id: m.id, spaceId: m.spaceId, person: m.person, directionRaw: m.directionRaw, amountMinor: m.amountMinor, occurredAt: m.occurredAt,
              dueDate: m.dueDate, notes: m.notes, productId: m.productId, transferId: m.transferId,
              createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.DebtRow) -> Debt {
        let m = Debt(id: r.id, spaceId: r.spaceId, person: r.person, direction: DebtDirection(rawValue: r.directionRaw) ?? .meDebe,
                     amountMinor: r.amountMinor, occurredAt: r.occurredAt)
        fill(m, r)
        return m
    }

    static func fill(_ m: Debt, _ r: S.DebtRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.person = r.person
        m.directionRaw = r.directionRaw
        m.amountMinor = r.amountMinor
        m.occurredAt = r.occurredAt
        m.dueDate = r.dueDate
        m.notes = r.notes
        m.productId = r.productId
        m.transferId = r.transferId
        m.createdAt = r.createdAt
        m.updatedAt = r.updatedAt
        m.deletedAt = r.deletedAt
    }

    // MARK: Abonos

    static func row(_ m: DebtPayment) -> S.DebtPaymentRow {
        .init(id: m.id, spaceId: m.spaceId, debtId: m.debtId, amountMinor: m.amountMinor, occurredAt: m.occurredAt,
              productId: m.productId, transferId: m.transferId, createdAt: m.createdAt, updatedAt: m.updatedAt, deletedAt: m.deletedAt)
    }

    static func make(_ r: S.DebtPaymentRow) -> DebtPayment {
        let m = DebtPayment(id: r.id, spaceId: r.spaceId, debtId: r.debtId, amountMinor: r.amountMinor, occurredAt: r.occurredAt)
        fill(m, r)
        return m
    }

    static func fill(_ m: DebtPayment, _ r: S.DebtPaymentRow) {
        m.id = r.id
        m.spaceId = r.spaceId
        m.debtId = r.debtId
        m.amountMinor = r.amountMinor
        m.occurredAt = r.occurredAt
        m.productId = r.productId
        m.transferId = r.transferId
        m.createdAt = r.createdAt
        m.updatedAt = r.updatedAt
        m.deletedAt = r.deletedAt
    }
}
