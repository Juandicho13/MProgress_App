import Foundation
import SwiftData

/// La base local para el `SyncEngine` (F10). Cada registro viaja como su fila del respaldo en JSON
/// (fechas ISO 8601 con 6 decimales), y al bajar se escribe en el mismo modelo, sin borrarlo.
/// Las categorías globales (las de la semilla, iguales para todos) no se sincronizan.
@MainActor
final class SwiftDataSyncStore: InitialUploadLocal {
    typealias S = BackupSnapshot

    static let cursorPrefix = "sync.cursor."
    static let attemptsKey = "sync.intentos"

    let context: ModelContext
    let defaults: UserDefaults
    private let encoder = ServerTime.encoder()
    private let decoder = ServerTime.decoder()
    /// Modelos por tabla e id, para no buscar en la base en cada fila.
    private var cache: [String: [UUID: any SyncTracked]] = [:]
    /// Se escribió algo que vino de la nube (para refrescar widgets y avisos).
    private(set) var appliedChanges = 0

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    // MARK: LocalSyncStore

    func pending() throws -> [SyncRecord] {
        var result: [SyncRecord] = []
        for table in SyncEngine.tables {
            result += try records(table: table).filter { isPending(table: $0.table, id: $0.id) }
        }
        return result
    }

    func markSynced(_ records: [SyncRecord]) throws {
        var attempts = storedAttempts()
        for record in records {
            attempts[E2EEFormat.id(record.id)] = nil
            // Si cambió mientras se subía, sigue pendiente para la próxima vez.
            if let model = try model(table: record.table, id: record.id), model.updatedAt == record.updatedAt {
                model.syncStateRaw = SyncState.synced.rawValue
            }
        }
        defaults.set(attempts, forKey: Self.attemptsKey)
        if context.hasChanges { try context.save() }
    }

    func markFailed(_ records: [SyncRecord], attempts: Int) throws {
        var stored = storedAttempts()
        for record in records {
            stored[E2EEFormat.id(record.id)] = attempts
            if attempts >= SyncEngine.maxAttempts, let model = try model(table: record.table, id: record.id) {
                model.syncStateRaw = SyncState.failed.rawValue
            }
        }
        defaults.set(stored, forKey: Self.attemptsKey)
        if context.hasChanges { try context.save() }
    }

    func attempts(for record: SyncRecord) -> Int {
        storedAttempts()[E2EEFormat.id(record.id)] ?? 0
    }

    func local(table: String, id: UUID) throws -> SyncRecord? {
        guard let model = try model(table: table, id: id) else { return nil }
        return SyncRecord(table: table, id: id, updatedAt: model.updatedAt, deletedAt: model.deletedAt, payload: Data())
    }

    func apply(_ record: SyncRecord) throws {
        switch record.table {
        case "spaces": try upsert(record, as: S.SpaceRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "categories": try upsert(record, as: S.CategoryRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "institutions": try upsert(record, as: S.InstitutionRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "reward_programs": try upsert(record, as: S.RewardRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "products": try upsert(record, as: S.ProductRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "recurring": try upsert(record, as: S.RecurringRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "entries": try upsert(record, as: S.EntryRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "transfers": try upsert(record, as: S.TransferRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "reminders": try upsert(record, as: S.ReminderRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "budgets": try upsert(record, as: S.BudgetRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "savings_goals": try upsert(record, as: S.GoalRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "goal_contributions": try upsert(record, as: S.ContributionRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "merchant_alias": try upsert(record, as: S.MerchantAliasRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "debts": try upsert(record, as: S.DebtRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        case "debt_payments": try upsert(record, as: S.DebtPaymentRow.self, make: { BackupRows.make($0) }, fill: { BackupRows.fill($0, $1) })
        default: return
        }
    }

    func cursor(table: String) -> Date? {
        let value = defaults.double(forKey: Self.cursorPrefix + table)
        return value > 0 ? Date(timeIntervalSinceReferenceDate: value) : nil
    }

    func setCursor(_ date: Date, table: String) {
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: Self.cursorPrefix + table)
        // Se guarda una vez por tabla, no en cada fila.
        if context.hasChanges { try? context.save() }
    }

    /// Para cerrar sesión o cambiar de cuenta: se vuelve a bajar todo la próxima vez.
    static func resetCursors(defaults: UserDefaults = .standard) {
        for table in SyncEngine.tables { defaults.removeObject(forKey: cursorPrefix + table) }
        defaults.removeObject(forKey: attemptsKey)
    }

    /// Cuántos cambios esperan subir (para la pastilla "Sin conexión · 3 cambios sin sincronizar").
    func pendingCount() -> Int { (try? pending().count) ?? 0 }

    /// Cuántos no subieron después de 3 intentos.
    func failedCount() -> Int {
        var count = 0
        for table in SyncEngine.tables {
            count += ((try? allModels(table: table)) ?? []).filter { $0.syncStateRaw == SyncState.failed.rawValue }.count
        }
        return count
    }

    /// Vuelve a intentar los que fallaron 3 veces.
    func retryFailed() throws {
        for table in SyncEngine.tables {
            for model in try allModels(table: table) where model.syncStateRaw == SyncState.failed.rawValue {
                model.syncStateRaw = SyncState.pending.rawValue
            }
        }
        defaults.removeObject(forKey: Self.attemptsKey)
        if context.hasChanges { try context.save() }
    }

    /// Cambios sin subir por tabla (pendientes y los que fallaron), para la hoja de estado: "3 movimientos, 1 pago fijo".
    func pendingCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for table in SyncEngine.tables {
            let count = ((try? allModels(table: table)) ?? []).filter { $0.syncStateRaw != SyncState.synced.rawValue }.count
            if count > 0 { counts[table] = count }
        }
        return counts
    }

    // MARK: Primera subida (F10-05)

    func uploadItems() throws -> [InitialUpload.Item] {
        var items: [InitialUpload.Item] = []
        for table in SyncEngine.tables {
            items += try records(table: table).map {
                InitialUpload.Item(table: table, id: $0.id, updatedAt: $0.updatedAt, deleted: $0.deletedAt != nil,
                                   seedKey: InitialUpload.seedKey(table: table, payload: $0.payload))
            }
        }
        return items
    }

    /// Las categorías y reglas de comercio repetidas pasan a la de la nube. El duplicado nunca subió: se borra de verdad.
    func resolveDuplicates(_ remap: [String: [UUID: UUID]]) throws {
        let categories = remap["categories"] ?? [:]
        let aliases = remap["merchant_alias"] ?? [:]
        guard !categories.isEmpty || !aliases.isEmpty else { return }
        if !categories.isEmpty {
            for m in try context.fetch(FetchDescriptor<Entry>()) {
                if let id = m.categoryId, let to = categories[id] { m.categoryId = to; m.touch() }
            }
            for m in try context.fetch(FetchDescriptor<Recurring>()) {
                if let id = m.categoryId, let to = categories[id] { m.categoryId = to; m.touch() }
            }
            for m in try context.fetch(FetchDescriptor<Budget>()) {
                if let id = m.categoryId, let to = categories[id] { m.categoryId = to; m.touch() }
            }
            for m in try context.fetch(FetchDescriptor<MerchantAlias>()) {
                if let id = m.categoryId, let to = categories[id] { m.categoryId = to; m.touch() }
            }
            for m in try context.fetch(FetchDescriptor<SpendCategory>()) where categories[m.id] != nil {
                context.delete(m)
            }
        }
        if !aliases.isEmpty {
            for m in try context.fetch(FetchDescriptor<MerchantAlias>()) where aliases[m.id] != nil {
                context.delete(m)
            }
        }
        cache = [:]
        if context.hasChanges { try context.save() }
    }

    /// Deja pendientes las filas que el plan sube (por ejemplo, las que quedaron sincronizadas con otra cuenta).
    func queue(_ refs: [InitialUpload.Ref]) throws {
        for ref in refs {
            guard let model = try model(table: ref.table, id: ref.id) else { continue }
            if model.syncStateRaw == SyncState.synced.rawValue || model.syncStateRaw == SyncState.failed.rawValue {
                model.syncStateRaw = SyncState.pending.rawValue
            }
        }
        if context.hasChanges { try context.save() }
    }

    // MARK: Filas

    private func isPending(table: String, id: UUID) -> Bool {
        guard let model = try? model(table: table, id: id) else { return false }
        return model.syncStateRaw == SyncState.local.rawValue || model.syncStateRaw == SyncState.pending.rawValue
    }

    /// Todos los registros de una tabla como SyncRecord (con su JSON).
    private func records(table: String) throws -> [SyncRecord] {
        switch table {
        case "spaces":
            return try context.fetch(FetchDescriptor<Space>()).map { try record(table, $0, BackupRows.row($0), space: $0.id) }
        case "categories":
            return try context.fetch(FetchDescriptor<SpendCategory>()).filter { $0.ownerSpaceId != nil }
                .map { try record(table, $0, BackupRows.row($0), space: $0.ownerSpaceId) }
        case "institutions":
            return try context.fetch(FetchDescriptor<Institution>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "reward_programs":
            return try context.fetch(FetchDescriptor<RewardProgram>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "products":
            return try context.fetch(FetchDescriptor<Product>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "recurring":
            return try context.fetch(FetchDescriptor<Recurring>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "entries":
            return try context.fetch(FetchDescriptor<Entry>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "transfers":
            return try context.fetch(FetchDescriptor<Transfer>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "reminders":
            return try context.fetch(FetchDescriptor<Reminder>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "budgets":
            return try context.fetch(FetchDescriptor<Budget>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "savings_goals":
            return try context.fetch(FetchDescriptor<SavingsGoal>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "goal_contributions":
            return try context.fetch(FetchDescriptor<GoalContribution>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "merchant_alias":
            return try context.fetch(FetchDescriptor<MerchantAlias>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "debts":
            return try context.fetch(FetchDescriptor<Debt>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        case "debt_payments":
            return try context.fetch(FetchDescriptor<DebtPayment>()).map { try record(table, $0, BackupRows.row($0), space: $0.spaceId) }
        default:
            return []
        }
    }

    private func record<M: SyncTracked, R: Encodable>(_ table: String, _ model: M, _ row: R, space: UUID?) throws -> SyncRecord {
        SyncRecord(table: table, id: model.id, updatedAt: model.updatedAt, deletedAt: model.deletedAt,
                   payload: try encoder.encode(row), spaceId: space)
    }

    /// Todos los modelos de una tabla, como SyncTracked.
    private func allModels(table: String) throws -> [any SyncTracked] {
        switch table {
        case "spaces": return try context.fetch(FetchDescriptor<Space>())
        case "categories": return try context.fetch(FetchDescriptor<SpendCategory>()).filter { $0.ownerSpaceId != nil }
        case "institutions": return try context.fetch(FetchDescriptor<Institution>())
        case "reward_programs": return try context.fetch(FetchDescriptor<RewardProgram>())
        case "products": return try context.fetch(FetchDescriptor<Product>())
        case "recurring": return try context.fetch(FetchDescriptor<Recurring>())
        case "entries": return try context.fetch(FetchDescriptor<Entry>())
        case "transfers": return try context.fetch(FetchDescriptor<Transfer>())
        case "reminders": return try context.fetch(FetchDescriptor<Reminder>())
        case "budgets": return try context.fetch(FetchDescriptor<Budget>())
        case "savings_goals": return try context.fetch(FetchDescriptor<SavingsGoal>())
        case "goal_contributions": return try context.fetch(FetchDescriptor<GoalContribution>())
        case "merchant_alias": return try context.fetch(FetchDescriptor<MerchantAlias>())
        case "debts": return try context.fetch(FetchDescriptor<Debt>())
        case "debt_payments": return try context.fetch(FetchDescriptor<DebtPayment>())
        default: return []
        }
    }

    private func model(table: String, id: UUID) throws -> (any SyncTracked)? {
        if cache[table] == nil {
            var index: [UUID: any SyncTracked] = [:]
            for model in try allModels(table: table) { index[model.id] = model }
            cache[table] = index
        }
        return cache[table]?[id]
    }

    /// Escribe una fila bajada en su modelo (o lo crea). Si ya tiene exactamente ese cambio, no hace nada.
    private func upsert<M: PersistentModel & SyncTracked, R: Decodable>(_ record: SyncRecord, as rowType: R.Type,
                                                                        make: (R) -> M, fill: (M, R) -> Void) throws {
        let row = try decoder.decode(R.self, from: record.payload)
        if let existing = try model(table: record.table, id: record.id) as? M {
            if existing.updatedAt == record.updatedAt && existing.syncStateRaw == SyncState.synced.rawValue { return }
            fill(existing, row)
            existing.syncStateRaw = SyncState.synced.rawValue
        } else {
            let created = make(row)
            created.syncStateRaw = SyncState.synced.rawValue
            context.insert(created)
            cache[record.table]?[created.id] = created
        }
        appliedChanges += 1
    }

    private func storedAttempts() -> [String: Int] {
        defaults.dictionary(forKey: Self.attemptsKey) as? [String: Int] ?? [:]
    }
}

/// El espacio Personal de la nube lo crea el servidor al crear la cuenta. Cada dispositivo adopta su id
/// para los datos locales: así todos los dispositivos de la cuenta comparten el mismo espacio.
@MainActor
enum SpaceAdoption {
    static func adopt(_ newId: UUID, ownerId: UUID, context: ModelContext) throws {
        let spaces = try context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil },
                                                              sortBy: [SortDescriptor(\.createdAt)]))
        guard let personal = spaces.first(where: { $0.kindRaw == "personal" }) ?? spaces.first else {
            let created = Space(id: newId, ownerId: ownerId, name: "Personal")
            context.insert(created)
            try context.save()
            return
        }
        let old = personal.id
        guard old != newId else { return }
        let pending = SyncState.pending.rawValue
        personal.id = newId
        personal.ownerId = ownerId
        personal.syncStateRaw = pending
        for m in try context.fetch(FetchDescriptor<SpendCategory>()) where m.ownerSpaceId == old { m.ownerSpaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Institution>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Product>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Recurring>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Entry>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Split>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Transfer>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Reminder>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Budget>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<SavingsGoal>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<GoalContribution>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<RewardProgram>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<MerchantAlias>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<Debt>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        for m in try context.fetch(FetchDescriptor<DebtPayment>()) where m.spaceId == old { m.spaceId = newId; m.syncStateRaw = pending }
        try context.save()
    }
}
