import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

@MainActor
final class FakeRemote: RemoteSyncStore {
    var rows: [String: [UUID: SyncRecord]] = [:]
    var failNext = 0
    var pushes = 0

    struct Offline: Error {}

    func push(_ records: [SyncRecord]) async throws {
        if failNext > 0 {
            failNext -= 1
            throw Offline()
        }
        pushes += 1
        for record in records { rows[record.table, default: [:]][record.id] = record }
    }

    func pull(table: String, since: Date?) async throws -> [SyncRecord] {
        (rows[table] ?? [:]).values.filter { since == nil || $0.updatedAt > since! }.sorted { $0.updatedAt < $1.updatedAt }
    }
}

@MainActor
final class FakeLocal: LocalSyncStore {
    var rows: [String: [UUID: SyncRecord]] = [:]
    var pendingIds: [UUID] = []
    var failures: [UUID: Int] = [:]
    var failedIds: Set<UUID> = []
    var cursors: [String: Date] = [:]

    func edit(_ record: SyncRecord) {
        rows[record.table, default: [:]][record.id] = record
        pendingIds.removeAll { $0 == record.id }
        pendingIds.append(record.id)
    }

    func pending() throws -> [SyncRecord] {
        pendingIds.filter { !failedIds.contains($0) }.compactMap { id in rows.values.compactMap { $0[id] }.first }
    }

    func markSynced(_ records: [SyncRecord]) throws {
        let ids = Set(records.map(\.id))
        pendingIds.removeAll { ids.contains($0) }
    }

    func markFailed(_ records: [SyncRecord], attempts: Int) throws {
        for record in records {
            failures[record.id] = attempts
            if attempts >= SyncEngine.maxAttempts { failedIds.insert(record.id) }
        }
    }

    func attempts(for record: SyncRecord) -> Int { failures[record.id] ?? 0 }
    func local(table: String, id: UUID) throws -> SyncRecord? { rows[table]?[id] }
    func apply(_ record: SyncRecord) throws { rows[record.table, default: [:]][record.id] = record }
    func cursor(table: String) -> Date? { cursors[table] }
    func setCursor(_ date: Date, table: String) { cursors[table] = date }
}

@MainActor
struct SyncTests {
    func row(_ id: UUID, _ name: String, at date: Date, deleted: Date? = nil, table: String = "entries") -> SyncRecord {
        SyncRecord(table: table, id: id, updatedAt: date, deletedAt: deleted, payload: Data(name.utf8))
    }

    @Test("Dos teléfonos: lo que uno sube el otro lo baja, y el cursor avanza")
    func ida() async throws {
        let server = FakeRemote()
        let juan = FakeLocal()
        let mariana = FakeLocal()
        let id = UUID()
        juan.edit(row(id, "Mercado", at: fecha(2026, 11, 6, 9)))

        let subida = try await SyncEngine(local: juan, remote: server).run()
        #expect(subida.pushed == 1)
        #expect(try juan.pending().isEmpty)

        let bajada = try await SyncEngine(local: mariana, remote: server).run()
        #expect(bajada.pulled == 1)
        #expect(mariana.rows["entries"]?[id]?.payload == Data("Mercado".utf8))
        #expect(mariana.cursors["entries"] == fecha(2026, 11, 6, 9))

        let otraVez = try await SyncEngine(local: mariana, remote: server).run()
        #expect(otraVez.pulled == 0)
    }

    @Test("Choque: gana el cambio más reciente, en los dos sentidos")
    func choque() async throws {
        let server = FakeRemote()
        let id = UUID()
        server.rows["entries"] = [id: row(id, "Servidor 10:00", at: fecha(2026, 11, 6, 10))]

        let viejo = FakeLocal()
        viejo.rows["entries"] = [id: row(id, "Local 9:00", at: fecha(2026, 11, 6, 9))]
        _ = try await SyncEngine(local: viejo, remote: server).run()
        #expect(viejo.rows["entries"]?[id]?.payload == Data("Servidor 10:00".utf8))

        let nuevo = FakeLocal()
        nuevo.rows["entries"] = [id: row(id, "Local 11:00", at: fecha(2026, 11, 6, 11))]
        let report = try await SyncEngine(local: nuevo, remote: server).run()
        #expect(report.skipped == 1)
        #expect(nuevo.rows["entries"]?[id]?.payload == Data("Local 11:00".utf8))
    }

    @Test("Los borrados también viajan")
    func borrados() async throws {
        let server = FakeRemote()
        let juan = FakeLocal()
        let mariana = FakeLocal()
        let id = UUID()
        juan.edit(row(id, "Taxi", at: fecha(2026, 11, 6, 9)))
        _ = try await SyncEngine(local: juan, remote: server).run()
        _ = try await SyncEngine(local: mariana, remote: server).run()

        juan.edit(row(id, "Taxi", at: fecha(2026, 11, 6, 12), deleted: fecha(2026, 11, 6, 12)))
        _ = try await SyncEngine(local: juan, remote: server).run()
        _ = try await SyncEngine(local: mariana, remote: server).run()
        #expect(mariana.rows["entries"]?[id]?.deletedAt == fecha(2026, 11, 6, 12))
    }

    @Test("Sin conexión los cambios esperan; al tercer intento fallido quedan con error")
    func fallos() async throws {
        let server = FakeRemote()
        let juan = FakeLocal()
        juan.edit(row(UUID(), "Café", at: fecha(2026, 11, 6, 9)))
        server.failNext = 3

        for intento in 1...2 {
            await #expect(throws: FakeRemote.Offline.self) { try await SyncEngine(local: juan, remote: server).run() }
            #expect(try juan.pending().count == 1, "intento \(intento)")
        }
        let tercero = try await SyncEngine(local: juan, remote: server).run()
        #expect(tercero.failed == 1)
        #expect(try juan.pending().isEmpty)
        #expect(juan.failedIds.count == 1)
    }

    @Test("Sube en lotes y en el orden en que se hicieron")
    func lotes() async throws {
        let server = FakeRemote()
        let juan = FakeLocal()
        for minute in 0..<5 { juan.edit(row(UUID(), "\(minute)", at: fecha(2026, 11, 6, 9).addingTimeInterval(Double(minute) * 60))) }
        let report = try await SyncEngine(local: juan, remote: server, batchSize: 2).run()
        #expect(report.pushed == 5)
        #expect(server.pushes == 3)
    }

    @Test("Estado y texto de la pastilla")
    func estado() {
        #expect(SyncEngine.status(online: false, pending: 3, failed: 0, running: false) == .sinConexion(pending: 3))
        #expect(SyncEngine.pillText(.sinConexion(pending: 3)) == "Sin conexión · 3 cambios sin sincronizar")
        #expect(SyncEngine.pillText(.sinConexion(pending: 1)) == "Sin conexión · 1 cambio sin sincronizar")
        #expect(SyncEngine.status(online: true, pending: 0, failed: 0, running: false) == .sincronizado)
        #expect(SyncEngine.pillText(.sincronizado) == nil)
        #expect(SyncEngine.status(online: true, pending: 2, failed: 1, running: false).title == "Error")
    }
}
