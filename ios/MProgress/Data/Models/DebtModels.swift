import Foundation
import SwiftData

/// Deuda con otra persona (Quién te debe, en Dinero). No es la división en pareja de F11.
/// Si se eligió una cuenta, `transferId` es la transferencia que movió la plata (ver DebtMath.outsideProductId).
@Model
final class Debt: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var person: String = ""
    var directionRaw: String = DebtDirection.meDebe.rawValue
    var amountMinor: Int64 = 0
    var occurredAt: Date = Date.now
    var dueDate: Date?
    var notes: String?
    var productId: UUID?
    var transferId: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .meDebe }
        set { directionRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), spaceId: UUID, person: String, direction: DebtDirection, amountMinor: Int64, occurredAt: Date) {
        self.id = id
        self.spaceId = spaceId
        self.person = person
        self.directionRaw = direction.rawValue
        self.amountMinor = amountMinor
        self.occurredAt = occurredAt
    }

    var record: DebtRecord {
        DebtRecord(id: id, person: person, direction: direction, amountMinor: amountMinor, date: occurredAt, dueDate: dueDate,
                   note: notes, productId: productId)
    }
}

/// Abono a una deuda. Con cuenta, también mueve la plata con su transferencia.
@Model
final class DebtPayment: SyncTracked {
    var id: UUID = UUID()
    var spaceId: UUID = UUID()
    var debtId: UUID = UUID()
    var amountMinor: Int64 = 0
    var occurredAt: Date = Date.now
    var productId: UUID?
    var transferId: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncStateRaw: String = SyncState.local.rawValue

    init(id: UUID = UUID(), spaceId: UUID, debtId: UUID, amountMinor: Int64, occurredAt: Date) {
        self.id = id
        self.spaceId = spaceId
        self.debtId = debtId
        self.amountMinor = amountMinor
        self.occurredAt = occurredAt
    }

    var record: DebtPaymentRecord {
        DebtPaymentRecord(id: id, debtId: debtId, amountMinor: amountMinor, date: occurredAt, productId: productId)
    }
}
