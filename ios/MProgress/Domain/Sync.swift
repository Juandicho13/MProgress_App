import Foundation

/// Una fila lista para subir o recién bajada (HANDOFF 9). `payload` es la fila en JSON tal como la guarda Supabase.
struct SyncRecord: Equatable, Sendable {
    var table: String
    var id: UUID
    var updatedAt: Date
    var deletedAt: Date?
    var payload: Data
}

enum SyncStatus: Equatable, Sendable {
    case sincronizado
    case sincronizando
    case sinConexion(pending: Int)
    case error(String)

    var title: String {
        switch self {
        case .sincronizado: "Sincronizado"
        case .sincronizando: "Sincronizando"
        case .sinConexion: "Sin conexión"
        case .error: "Error"
        }
    }
}

/// El servidor (Supabase en F10). En las pruebas es una memoria.
@MainActor
protocol RemoteSyncStore {
    /// Upsert por id. Si falla, lanza.
    func push(_ records: [SyncRecord]) async throws
    /// Filas de una tabla cambiadas después de `since` (borrados incluidos), de la más vieja a la más nueva.
    func pull(table: String, since: Date?) async throws -> [SyncRecord]
}

/// La base local (SwiftData en la app).
@MainActor
protocol LocalSyncStore {
    /// Cambios pendientes en el orden en que se hicieron.
    func pending() throws -> [SyncRecord]
    func markSynced(_ records: [SyncRecord]) throws
    /// Suma un intento fallido; al tercero la fila queda `failed`.
    func markFailed(_ records: [SyncRecord], attempts: Int) throws
    func attempts(for record: SyncRecord) -> Int
    /// La versión local de una fila, si existe.
    func local(table: String, id: UUID) throws -> SyncRecord?
    /// Escribe una fila que bajó del servidor, sin marcarla pendiente.
    func apply(_ record: SyncRecord) throws
    func cursor(table: String) -> Date?
    func setCursor(_ date: Date, table: String)
}

/// Motor de sincronización: sube los pendientes, baja lo nuevo y resuelve choques por `updatedAt` (gana el más reciente).
@MainActor
struct SyncEngine {
    static let maxAttempts = 3
    /// Orden de las tablas: primero lo que otras filas referencian.
    static let tables = ["spaces", "categories", "institutions", "products", "recurring", "entries", "splits",
                         "transfers", "reminders", "budgets", "savings_goals", "goal_contributions"]

    struct Report: Equatable, Sendable {
        var pushed = 0
        var pulled = 0
        var skipped = 0
        var failed = 0
    }

    let local: LocalSyncStore
    let remote: RemoteSyncStore
    var batchSize = 200

    func run() async throws -> Report {
        var report = Report()
        let pending = try local.pending()
        for start in stride(from: 0, to: pending.count, by: batchSize) {
            let batch = Array(pending[start..<min(start + batchSize, pending.count)])
            do {
                try await remote.push(batch)
                try local.markSynced(batch)
                report.pushed += batch.count
            } catch {
                let attempts = batch.map { local.attempts(for: $0) + 1 }.max() ?? 1
                try local.markFailed(batch, attempts: attempts)
                report.failed += batch.count
                if attempts >= Self.maxAttempts { continue }
                throw error
            }
        }

        for table in Self.tables {
            let rows = try await remote.pull(table: table, since: local.cursor(table: table))
            for row in rows {
                if let mine = try local.local(table: table, id: row.id), !Self.remoteWins(remote: row, local: mine) {
                    report.skipped += 1
                    continue
                }
                try local.apply(row)
                report.pulled += 1
            }
            if let newest = rows.map(\.updatedAt).max() {
                local.setCursor(newest, table: table)
            }
        }
        return report
    }

    /// Gana el `updatedAt` más reciente; si empatan, gana el servidor para que todos los teléfonos terminen igual.
    static func remoteWins(remote: SyncRecord, local: SyncRecord) -> Bool {
        remote.updatedAt >= local.updatedAt
    }

    /// Estado para la pastilla de Inicio (F10-04).
    static func status(online: Bool, pending: Int, failed: Int, running: Bool) -> SyncStatus {
        if failed > 0 { return .error("\(failed) \(failed == 1 ? "cambio no subió" : "cambios no subieron")") }
        if !online { return .sinConexion(pending: pending) }
        if running || pending > 0 { return .sincronizando }
        return .sincronizado
    }

    /// "Sin conexión · 3 cambios sin sincronizar".
    static func pillText(_ status: SyncStatus) -> String? {
        switch status {
        case .sinConexion(let pending):
            pending == 0 ? "Sin conexión" : "Sin conexión · \(pending) \(pending == 1 ? "cambio" : "cambios") sin sincronizar"
        case .error(let detail):
            "Error · \(detail)"
        case .sincronizando, .sincronizado:
            nil
        }
    }
}
