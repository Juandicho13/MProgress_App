import Foundation
import SwiftData
import CryptoKit
import Security

/// Lee y restaura toda la base (F09-06). Restaurar reemplaza lo que hay por lo del respaldo, con los mismos ids.
@MainActor
enum BackupService {
    /// Fecha del último respaldo, en segundos desde 2001 (así la lee @AppStorage).
    static let lastBackupKey = "respaldo.ultimo"

    static func snapshot(context: ModelContext, now: Date = .now) throws -> BackupSnapshot {
        var s = BackupSnapshot(createdAt: now)
        s.spaces = try context.fetch(FetchDescriptor<Space>()).map {
            .init(id: $0.id, ownerId: $0.ownerId, name: $0.name, kindRaw: $0.kindRaw, currencyCode: $0.currencyCode, colorHex: $0.colorHex,
                  icon: $0.icon, shareTotalsOnly: $0.shareTotalsOnly, defaultSplit: $0.defaultSplit, endsOn: $0.endsOn,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.categories = try context.fetch(FetchDescriptor<SpendCategory>()).map {
            .init(id: $0.id, ownerSpaceId: $0.ownerSpaceId, name: $0.name, icon: $0.icon, colorHex: $0.colorHex, sort: $0.sort,
                  lastUsedAt: $0.lastUsedAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.institutions = try context.fetch(FetchDescriptor<Institution>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, name: $0.name, colorHex: $0.colorHex, icon: $0.icon, hidden: $0.hidden, sort: $0.sort,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.products = try context.fetch(FetchDescriptor<Product>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, institutionId: $0.institutionId, parentProductId: $0.parentProductId, kindRaw: $0.kindRaw,
                  name: $0.name, last4: $0.last4, balanceMinor: $0.balanceMinor, balanceAt: $0.balanceAt, creditLimitMinor: $0.creditLimitMinor,
                  cutDay: $0.cutDay, dueDay: $0.dueDay, rateEA: $0.rateEA, lockedUntil: $0.lockedUntil, inWallet: $0.inWallet, hidden: $0.hidden,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.recurring = try context.fetch(FetchDescriptor<Recurring>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, kindRaw: $0.kindRaw, name: $0.name, icon: $0.icon, amountMinor: $0.amountMinor,
                  cycleRaw: $0.cycleRaw, intervalDays: $0.intervalDays, nextDate: $0.nextDate, anchorDay: $0.anchorDay, anchorMonth: $0.anchorMonth,
                  categoryId: $0.categoryId, productId: $0.productId, responsibleId: $0.responsibleId, active: $0.active, createdBy: $0.createdBy,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt, dateUnset: $0.dateUnset)
        }
        s.entries = try context.fetch(FetchDescriptor<Entry>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, kindRaw: $0.kindRaw, amountMinor: $0.amountMinor, occurredAt: $0.occurredAt, name: $0.name,
                  merchant: $0.merchant, icon: $0.icon, categoryId: $0.categoryId, productId: $0.productId, recurringId: $0.recurringId,
                  paidBy: $0.paidBy, methodRaw: $0.methodRaw, sourceRaw: $0.sourceRaw, needsReview: $0.needsReview, notes: $0.notes,
                  createdBy: $0.createdBy, createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.transfers = try context.fetch(FetchDescriptor<Transfer>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, fromProductId: $0.fromProductId, toProductId: $0.toProductId, amountMinor: $0.amountMinor,
                  occurredAt: $0.occurredAt, notes: $0.notes, createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.reminders = try context.fetch(FetchDescriptor<Reminder>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, recurringId: $0.recurringId, daysBefore: $0.daysBefore, targetRaw: $0.targetRaw, userId: $0.userId,
                  atMinutes: $0.atMinutes, notifyPartnerOnPaid: $0.notifyPartnerOnPaid, sameDay: $0.sameDay,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.budgets = try context.fetch(FetchDescriptor<Budget>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, categoryId: $0.categoryId, monthlyLimitMinor: $0.monthlyLimitMinor,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.goals = try context.fetch(FetchDescriptor<SavingsGoal>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, name: $0.name, targetAmountMinor: $0.targetAmountMinor, targetDate: $0.targetDate,
                  productId: $0.productId, createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.contributions = try context.fetch(FetchDescriptor<GoalContribution>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, goalId: $0.goalId, userId: $0.userId, amountMinor: $0.amountMinor, occurredAt: $0.occurredAt,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        s.rewards = try context.fetch(FetchDescriptor<RewardProgram>()).map {
            .init(id: $0.id, spaceId: $0.spaceId, name: $0.name, kindRaw: $0.kindRaw, balance: $0.balance, valuePerPoint: $0.valuePerPoint,
                  expiresAt: $0.expiresAt, productId: $0.productId, colorHex: $0.colorHex, balanceAt: $0.balanceAt,
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt)
        }
        return s
    }

    /// Borra todo y pone lo del respaldo. Todo queda pendiente de sincronizar.
    static func restore(_ s: BackupSnapshot, context: ModelContext) throws {
        try context.delete(model: Space.self)
        try context.delete(model: SpendCategory.self)
        try context.delete(model: Institution.self)
        try context.delete(model: Product.self)
        try context.delete(model: Recurring.self)
        try context.delete(model: Entry.self)
        try context.delete(model: Split.self)
        try context.delete(model: Transfer.self)
        try context.delete(model: Reminder.self)
        try context.delete(model: Budget.self)
        try context.delete(model: SavingsGoal.self)
        try context.delete(model: GoalContribution.self)
        try context.delete(model: RewardProgram.self)

        for r in s.spaces {
            let m = Space(id: r.id, ownerId: r.ownerId, name: r.name, kindRaw: r.kindRaw, currencyCode: r.currencyCode)
            m.colorHex = r.colorHex
            m.icon = r.icon
            m.shareTotalsOnly = r.shareTotalsOnly
            m.defaultSplit = r.defaultSplit
            m.endsOn = r.endsOn
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.categories {
            let m = SpendCategory(id: r.id, ownerSpaceId: r.ownerSpaceId, name: r.name, icon: r.icon, sort: r.sort)
            m.colorHex = r.colorHex
            m.lastUsedAt = r.lastUsedAt
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.institutions {
            let m = Institution(id: r.id, spaceId: r.spaceId, name: r.name, colorHex: r.colorHex)
            m.icon = r.icon
            m.hidden = r.hidden
            m.sort = r.sort
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.products {
            let m = Product(id: r.id, spaceId: r.spaceId, institutionId: r.institutionId, kind: ProductKind(rawValue: r.kindRaw) ?? .cuenta, name: r.name)
            m.parentProductId = r.parentProductId
            m.last4 = MoneyStore.cleanLast4(r.last4)
            m.balanceMinor = r.balanceMinor
            m.balanceAt = r.balanceAt
            m.creditLimitMinor = r.creditLimitMinor
            m.cutDay = r.cutDay
            m.dueDay = r.dueDay
            m.rateEA = r.rateEA
            m.lockedUntil = r.lockedUntil
            m.inWallet = r.inWallet
            m.hidden = r.hidden
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.recurring {
            let m = Recurring(id: r.id, spaceId: r.spaceId, kind: EntryKind(rawValue: r.kindRaw) ?? .gasto, name: r.name, amountMinor: r.amountMinor,
                              cycle: Cycle(rawValue: r.cycleRaw, intervalDays: r.intervalDays), nextDate: r.nextDate)
            m.icon = r.icon
            m.anchorDay = r.anchorDay
            m.anchorMonth = r.anchorMonth
            m.categoryId = r.categoryId
            m.productId = r.productId
            m.responsibleId = r.responsibleId
            m.active = r.active
            m.dateUnset = r.dateUnset ?? false
            m.createdBy = r.createdBy
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.entries {
            let m = Entry(id: r.id, spaceId: r.spaceId, kind: EntryKind(rawValue: r.kindRaw) ?? .gasto, amountMinor: r.amountMinor,
                          occurredAt: r.occurredAt, name: r.name)
            m.merchant = r.merchant
            m.icon = r.icon
            m.categoryId = r.categoryId
            m.productId = r.productId
            m.recurringId = r.recurringId
            m.paidBy = r.paidBy
            m.methodRaw = r.methodRaw
            m.sourceRaw = r.sourceRaw
            m.needsReview = r.needsReview
            m.notes = r.notes
            m.createdBy = r.createdBy
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.transfers {
            let m = Transfer(spaceId: r.spaceId, fromProductId: r.fromProductId, toProductId: r.toProductId, amountMinor: r.amountMinor, occurredAt: r.occurredAt)
            m.id = r.id
            m.notes = r.notes
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.reminders {
            let m = Reminder(spaceId: r.spaceId, recurringId: r.recurringId, daysBefore: r.daysBefore)
            m.id = r.id
            m.targetRaw = r.targetRaw
            m.userId = r.userId
            m.atMinutes = r.atMinutes
            m.notifyPartnerOnPaid = r.notifyPartnerOnPaid
            m.sameDay = r.sameDay
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.budgets {
            let m = Budget(spaceId: r.spaceId, categoryId: r.categoryId, monthlyLimitMinor: r.monthlyLimitMinor)
            m.id = r.id
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.goals {
            let m = SavingsGoal(spaceId: r.spaceId, name: r.name, targetAmountMinor: r.targetAmountMinor)
            m.id = r.id
            m.targetDate = r.targetDate
            m.productId = r.productId
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.contributions {
            let m = GoalContribution(spaceId: r.spaceId, goalId: r.goalId, userId: r.userId, amountMinor: r.amountMinor, occurredAt: r.occurredAt)
            m.id = r.id
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        for r in s.rewards ?? [] {
            let m = RewardProgram(id: r.id, spaceId: r.spaceId, name: r.name, kind: RewardKind(rawValue: r.kindRaw) ?? .puntos, balance: r.balance)
            m.valuePerPoint = r.valuePerPoint
            m.expiresAt = r.expiresAt
            m.productId = r.productId
            m.colorHex = r.colorHex
            m.balanceAt = r.balanceAt
            stamp(m, r.createdAt, r.updatedAt, r.deletedAt)
            context.insert(m)
        }
        try context.save()
    }

    private static func stamp<T: SyncTracked>(_ model: T, _ created: Date, _ updated: Date, _ deleted: Date?) {
        model.createdAt = created
        model.updatedAt = updated
        model.deletedAt = deleted
        model.syncStateRaw = SyncState.pending.rawValue
    }

    // MARK: Respaldo automático cifrado

    /// Carpeta de respaldos: Archivos › En mi iPhone › MProgress › Respaldos. Cuando la app tenga firma e iCloud
    /// (F00-02), la misma carpeta pasa al contenedor de iCloud Drive.
    static var folder: URL {
        URL.documentsDirectory.appending(path: "Respaldos", directoryHint: .isDirectory)
    }

    /// Respaldo cifrado de hoy si no hay uno. Guarda los últimos 7.
    @discardableResult
    static func autoBackupIfNeeded(context: ModelContext, now: Date = .now, calendar: Calendar = .current, force: Bool = false) throws -> URL? {
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastBackupKey)
        if !force, last > 0, calendar.isDate(Date(timeIntervalSinceReferenceDate: last), inSameDayAs: now) { return nil }
        let data = try BackupCodec.encode(snapshot(context: context, now: now))
        let sealed = try BackupCrypto.seal(data)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: BackupCodec.fileName(date: now, calendar: calendar, ext: "mprogress-cifrado"))
        try sealed.write(to: url, options: [.atomic, .completeFileProtection])
        defaults.set(now.timeIntervalSinceReferenceDate, forKey: lastBackupKey)
        try prune(keep: 7)
        return url
    }

    static func encryptedBackups() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "mprogress-cifrado" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func prune(keep: Int) throws {
        for url in encryptedBackups().dropFirst(keep) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Abre un respaldo: `.mprogress` (JSON) o `.mprogress-cifrado`.
    static func read(_ data: Data) throws -> BackupSnapshot {
        if let snapshot = try? BackupCodec.decode(data) { return snapshot }
        return try BackupCodec.decode(BackupCrypto.open(data))
    }
}

/// Cifra los respaldos automáticos con AES-GCM. La llave vive en el llavero de iCloud (sincronizable),
/// así un iPhone nuevo con el mismo Apple ID puede abrir los respaldos.
enum BackupCrypto {
    private static let service = "com.olarte.mprogress.backup-key"

    static func seal(_ data: Data) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key()).combined else { throw CocoaError(.coderInvalidValue) }
        return combined
    }

    static func open(_ data: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key())
    }

    /// Borra la llave de respaldo (también la copia en el llavero de iCloud).
    static func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func key() throws -> SymmetricKey {
        if let stored = read() { return SymmetricKey(data: stored) }
        let new = SymmetricKey(size: .bits256)
        let data = new.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { throw CocoaError(.fileWriteNoPermission) }
        return new
    }

    private static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}
