import Foundation
import SwiftData

/// Guarda lo que llega solo: Apple Pay desde Atajos, SMS del banco o un recibo (F08).
@MainActor
final class AutoCaptureStore {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    enum Outcome {
        case saved(Entry)
        /// Ya estaba: Apple Pay y el SMS del mismo pago llegan casi juntos.
        case duplicate(Entry)
    }

    /// Registra un cobro leído. Busca la tarjeta por sus últimos 4 y evita duplicados de los últimos 10 minutos.
    func record(_ charge: ParsedCharge, source: EntrySource, now: Date = .now) throws -> Outcome {
        let spaces = try context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil }, sortBy: [SortDescriptor(\.createdAt)]))
        guard let space = spaces.first(where: { $0.kindRaw == "personal" }) ?? spaces.first else {
            throw CocoaError(.coderValueNotFound)
        }
        let product = try product(last4: charge.last4, spaceId: space.id)
        let ledger = LedgerStore(context: context, calendar: calendar)

        let window = DateInterval(start: now.addingTimeInterval(-600), end: now.addingTimeInterval(60))
        if let existing = try ledger.entries(spaceId: space.id, in: window).first(where: {
            $0.amountMinor == charge.amountMinor && $0.kind == charge.kind && $0.sourceRaw != EntrySource.manual.rawValue
                && (product == nil || $0.productId == nil || $0.productId == product?.id)
        }) {
            // El segundo aviso del mismo pago completa lo que falte.
            if existing.productId == nil { existing.productId = product?.id }
            if existing.merchant == nil, let merchant = charge.merchant {
                existing.merchant = merchant
                if existing.name == "Gasto" || existing.name == "Ingreso" { existing.name = merchant }
            }
            existing.needsReview = existing.productId == nil
            existing.touch(now)
            try context.save()
            return .duplicate(existing)
        }

        let name = charge.merchant ?? (charge.kind == .ingreso ? "Ingreso" : "Gasto")
        let entry = try ledger.addEntry(spaceId: space.id, kind: charge.kind, amountMinor: charge.amountMinor, name: name,
                                        occurredAt: now, productId: product?.id,
                                        method: source == .applePay ? PayMethod.applePay.rawValue : nil,
                                        source: source.rawValue, createdBy: LocalIdentity.userId)
        entry.merchant = charge.merchant
        entry.needsReview = charge.needsReview || product == nil
        try context.save()
        return .saved(entry)
    }

    /// Lo último que llegó solo, más nuevo primero.
    func recent(limit: Int = 20) throws -> [Entry] {
        let manual = EntrySource.manual.rawValue
        var descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.deletedAt == nil && $0.sourceRaw != manual },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    private func product(last4: String?, spaceId: UUID) throws -> Product? {
        guard let last4 = MoneyStore.cleanLast4(last4) else { return nil }
        let products = try MoneyStore(context: context).products(spaceId: spaceId)
        return products.first { $0.last4 == last4 && ($0.kind == .credito || $0.kind == .debito) } ?? products.first { $0.last4 == last4 }
    }
}
