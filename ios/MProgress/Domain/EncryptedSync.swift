import Foundation

/// Una fila de `sync_records` tal como la ve Supabase: solo ids, tipo y fechas en claro; el resto cifrado.
struct SyncEnvelope: Codable, Equatable, Sendable {
    var id: UUID
    var spaceId: UUID
    var entity: String
    /// base64(AES-GCM(JSON del registro)) con datos asociados "espacio|entidad|id".
    var payload: String
    /// Cuándo cambió en el teléfono: decide quién gana.
    var changedAt: Date
    /// Cuándo llegó al servidor: lo pone el servidor. Nil al subir.
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, entity, payload
        case spaceId = "space_id"
        case changedAt = "changed_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

/// El transporte de los sobres (PostgREST en la app, una memoria en las pruebas).
@MainActor
protocol EnvelopeTransport {
    /// Upsert por id. El servidor pone `updated_at` y no pisa una fila con un `changed_at` más nuevo.
    func upsert(_ rows: [SyncEnvelope]) async throws
    /// Sobres de un tipo que llegaron al servidor después de `since`, del más viejo al más nuevo.
    func fetch(entity: String, since: Date?) async throws -> [SyncEnvelope]
}

/// `RemoteSyncStore` que cifra al subir y descifra al bajar: el `SyncEngine` de siempre, con sobres.
@MainActor
final class EncryptedRemote: RemoteSyncStore {
    let transport: EnvelopeTransport
    let crypto: CryptoProvider
    /// Espacio de los registros que no dicen el suyo.
    let defaultSpaceId: UUID
    /// Llave de cada espacio; nil si este dispositivo no la tiene.
    let keyFor: (UUID) -> Data?
    /// Sobres que bajaron pero no se pudieron abrir (sin llave o alterados). Se ignoran.
    private(set) var unreadable = 0

    init(transport: EnvelopeTransport, crypto: CryptoProvider, defaultSpaceId: UUID, keyFor: @escaping (UUID) -> Data?) {
        self.transport = transport
        self.crypto = crypto
        self.defaultSpaceId = defaultSpaceId
        self.keyFor = keyFor
    }

    func push(_ records: [SyncRecord]) async throws {
        let rows = try records.map { record in
            let space = record.spaceId ?? defaultSpaceId
            guard let key = keyFor(space) else { throw E2EEError.missingKey }
            return SyncEnvelope(
                id: record.id, spaceId: space, entity: record.table,
                payload: try Envelope.seal(record.payload, spaceId: space, entity: record.table, id: record.id, key: key, crypto: crypto),
                changedAt: record.updatedAt, updatedAt: nil, deletedAt: record.deletedAt)
        }
        guard !rows.isEmpty else { return }
        try await transport.upsert(rows)
    }

    func pull(table: String, since: Date?) async throws -> [SyncRecord] {
        let rows = try await transport.fetch(entity: table, since: since)
        return rows.compactMap { row in
            guard let key = keyFor(row.spaceId),
                  let payload = try? Envelope.open(row.payload, spaceId: row.spaceId, entity: row.entity, id: row.id, key: key, crypto: crypto)
            else {
                unreadable += 1
                return nil
            }
            return SyncRecord(table: row.entity, id: row.id, updatedAt: row.changedAt, deletedAt: row.deletedAt,
                              payload: payload, spaceId: row.spaceId, serverUpdatedAt: row.updatedAt)
        }
    }
}
