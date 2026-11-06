import Foundation

/// Un dispositivo de la cuenta, como lo devuelve `devices`.
struct RemoteDevice: Decodable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String?
    let publicKey: String?
    let createdAt: Date?
    let lastSeenAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case publicKey = "public_key"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
    }

    var publicKeyData: Data? { publicKey.flatMap { Data(base64Encoded: $0) } }
}

/// Una llave de espacio envuelta (`space_keys`). `deviceId` nil es la del código de recuperación.
struct RemoteSpaceKey: Decodable, Equatable, Sendable {
    let id: UUID
    let deviceId: UUID?
    let wrappedKey: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case wrappedKey = "wrapped_key"
    }
}

/// Llamadas a PostgREST con la sesión del usuario. La seguridad por fila decide qué ve y qué escribe.
@MainActor
struct CloudAPI {
    /// Da un access token vigente (lo renueva si hace falta).
    let accessToken: () async throws -> String

    private func send(_ method: SupabaseHTTP.Method, _ path: String, query: [(String, String)] = [], body: Data? = nil,
                      prefer: String? = nil) async throws -> Data {
        let token = try await accessToken()
        let url = SupabaseHTTP.url(CloudConfig.restURL, path: path, query: query)
        return try await SupabaseHTTP.send(method, url, body: body, accessToken: token, headers: prefer.map { ["Prefer": $0] } ?? [:])
    }

    // MARK: Espacio

    /// El espacio Personal de la cuenta (lo crea el servidor al crear la cuenta). Si no está, lo crea.
    func personalSpaceId(userId: UUID) async throws -> UUID {
        struct Row: Decodable { let id: UUID }
        let data = try await send(.get, "spaces", query: [
            ("select", "id"), ("owner_id", "eq.\(E2EEFormat.id(userId))"), ("kind", "eq.personal"),
            ("deleted_at", "is.null"), ("order", "created_at.asc"), ("limit", "1"),
        ])
        if let existing = try SupabaseHTTP.decode([Row].self, data).first { return existing.id }
        let body = try JSONSerialization.data(withJSONObject: ["owner_id": E2EEFormat.id(userId), "name": "Personal", "kind": "personal"])
        let created = try await send(.post, "spaces", query: [("select", "id")], body: body, prefer: "return=representation")
        guard let row = try SupabaseHTTP.decode([Row].self, created).first else { throw CloudError.badResponse }
        return row.id
    }

    // MARK: Dispositivos

    /// Registra (o actualiza) este dispositivo con su llave pública.
    func registerDevice(id: UUID, userId: UUID, publicKey: Data, name: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [[
            "id": E2EEFormat.id(id), "user_id": E2EEFormat.id(userId), "platform": "ios", "name": name,
            "public_key": publicKey.base64EncodedString(), "last_seen_at": ServerTime.format(.now),
        ]])
        _ = try await send(.post, "devices", query: [("on_conflict", "id")], body: body,
                           prefer: "resolution=merge-duplicates,return=minimal")
    }

    func devices() async throws -> [RemoteDevice] {
        let data = try await send(.get, "devices", query: [
            ("select", "id,name,public_key,created_at,last_seen_at"), ("order", "created_at.asc"),
        ])
        return try SupabaseHTTP.decode([RemoteDevice].self, data)
    }

    func deleteDevice(_ id: UUID) async throws {
        _ = try await send(.delete, "devices", query: [("id", "eq.\(E2EEFormat.id(id))")], prefer: "return=minimal")
    }

    // MARK: Llaves de espacio

    func spaceKeys(spaceId: UUID) async throws -> [RemoteSpaceKey] {
        let data = try await send(.get, "space_keys", query: [
            ("select", "id,device_id,wrapped_key"), ("space_id", "eq.\(E2EEFormat.id(spaceId))"),
        ])
        return try SupabaseHTTP.decode([RemoteSpaceKey].self, data)
    }

    /// Guarda una llave envuelta para un dispositivo (o la de recuperación con `deviceId` nil).
    func addSpaceKey(spaceId: UUID, deviceId: UUID?, wrappedKey: String) async throws {
        var row: [String: Any] = ["space_id": E2EEFormat.id(spaceId), "wrapped_key": wrappedKey]
        if let deviceId {
            row["device_id"] = E2EEFormat.id(deviceId)
        } else {
            row["device_id"] = NSNull()
        }
        _ = try await send(.post, "space_keys", body: try JSONSerialization.data(withJSONObject: row), prefer: "return=minimal")
    }

    /// Quita la llave de recuperación (para poner una nueva al cambiar el código).
    func deleteRecoveryKey(spaceId: UUID) async throws {
        _ = try await send(.delete, "space_keys", query: [("space_id", "eq.\(E2EEFormat.id(spaceId))"), ("device_id", "is.null")],
                           prefer: "return=minimal")
    }

    // MARK: Cuenta

    /// Borra la cuenta remota y todo lo suyo en el servidor (función `delete_my_account`).
    func deleteMyAccount() async throws {
        _ = try await send(.post, "rpc/delete_my_account", body: Data("{}".utf8))
    }
}

/// Sobres de `sync_records` por PostgREST: upsert por id y bajada por tipo desde un cursor del servidor.
@MainActor
final class PostgrestEnvelopeTransport: EnvelopeTransport {
    let api: CloudAPI
    let pageSize = 1000

    init(api: CloudAPI) {
        self.api = api
    }

    /// Lo que se sube: `deleted_at` va siempre (null incluido) para que un registro restaurado vuelva a estar vivo.
    private struct Upload: Encodable {
        let row: SyncEnvelope

        enum CodingKeys: String, CodingKey {
            case id, entity, payload
            case spaceId = "space_id"
            case changedAt = "changed_at"
            case deletedAt = "deleted_at"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(E2EEFormat.id(row.id), forKey: .id)
            try container.encode(E2EEFormat.id(row.spaceId), forKey: .spaceId)
            try container.encode(row.entity, forKey: .entity)
            try container.encode(row.payload, forKey: .payload)
            try container.encode(row.changedAt, forKey: .changedAt)
            try container.encode(row.deletedAt, forKey: .deletedAt)
        }
    }

    func upsert(_ rows: [SyncEnvelope]) async throws {
        let token = try await api.accessToken()
        let url = SupabaseHTTP.url(CloudConfig.restURL, path: "sync_records", query: [
            ("on_conflict", "id"), ("columns", "id,space_id,entity,payload,changed_at,deleted_at"),
        ])
        let body = try SupabaseHTTP.json(rows.map(Upload.init(row:)))
        _ = try await SupabaseHTTP.send(.post, url, body: body, accessToken: token,
                                        headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    func fetch(entity: String, since: Date?) async throws -> [SyncEnvelope] {
        var result: [SyncEnvelope] = []
        var cursor = since
        while true {
            var query: [(String, String)] = [
                ("select", "id,space_id,entity,payload,changed_at,updated_at,deleted_at"),
                ("entity", "eq.\(entity)"), ("order", "updated_at.asc"), ("limit", "\(pageSize)"),
            ]
            if let cursor { query.append(("updated_at", "gt.\(ServerTime.format(cursor))")) }
            let token = try await api.accessToken()
            let data = try await SupabaseHTTP.send(.get, SupabaseHTTP.url(CloudConfig.restURL, path: "sync_records", query: query),
                                                   accessToken: token)
            let page = try SupabaseHTTP.decode([SyncEnvelope].self, data)
            result.append(contentsOf: page)
            guard page.count == pageSize, let last = page.last?.updatedAt else { break }
            cursor = last
        }
        return result
    }
}
