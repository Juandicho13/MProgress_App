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
        s.spaces = try context.fetch(FetchDescriptor<Space>()).map { BackupRows.row($0) }
        s.categories = try context.fetch(FetchDescriptor<SpendCategory>()).map { BackupRows.row($0) }
        s.institutions = try context.fetch(FetchDescriptor<Institution>()).map { BackupRows.row($0) }
        s.products = try context.fetch(FetchDescriptor<Product>()).map { BackupRows.row($0) }
        s.recurring = try context.fetch(FetchDescriptor<Recurring>()).map { BackupRows.row($0) }
        s.entries = try context.fetch(FetchDescriptor<Entry>()).map { BackupRows.row($0) }
        s.transfers = try context.fetch(FetchDescriptor<Transfer>()).map { BackupRows.row($0) }
        s.reminders = try context.fetch(FetchDescriptor<Reminder>()).map { BackupRows.row($0) }
        s.budgets = try context.fetch(FetchDescriptor<Budget>()).map { BackupRows.row($0) }
        s.goals = try context.fetch(FetchDescriptor<SavingsGoal>()).map { BackupRows.row($0) }
        s.contributions = try context.fetch(FetchDescriptor<GoalContribution>()).map { BackupRows.row($0) }
        s.rewards = try context.fetch(FetchDescriptor<RewardProgram>()).map { BackupRows.row($0) }
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

        let pending = SyncState.pending.rawValue
        for r in s.spaces { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.categories { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.institutions { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.products { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.recurring { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.entries { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.transfers { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.reminders { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.budgets { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.goals { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.contributions { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        for r in s.rewards ?? [] { let m = BackupRows.make(r); m.syncStateRaw = pending; context.insert(m) }
        try context.save()
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
