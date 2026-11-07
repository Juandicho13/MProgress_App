import Foundation

/// F10-05: la primera vez que un dispositivo entra a la cuenta (o crea la llave del espacio) sube todo lo local una sola vez.
///
/// Reglas:
/// - Las filas conservan su id: el servidor hace upsert por id y así nada se duplica.
/// - Primero se baja todo lo que ya hay en la nube (un segundo dispositivo que se une a un espacio con datos) y luego se suben
///   solo las filas locales que la nube no tiene o que cambiaron aquí después (`updatedAt` más nuevo).
/// - Lo que se creó igual en dos teléfonos antes de entrar (una categoría "Mascotas" en cada uno, la misma regla de comercio)
///   se une con la fila de la nube por una clave estable: las referencias locales pasan al id de la nube y el duplicado local
///   se borra sin subirlo. Las categorías de la semilla tienen ids fijos y no se sincronizan, así que nunca se suben.
/// - Los ajustes del espacio (moneda) vienen de la nube si ya existen allá.
/// - Se marca hecho por espacio y usuario (`storageKey`) para no repetirlo.
enum InitialUpload {
    /// Lotes más pequeños en la primera subida para que el avance se vea ("Subiendo tus datos: 100 de 340").
    static let batchSize = 50

    /// Una fila, local o de la nube, con lo justo para planear.
    struct Item: Equatable, Sendable {
        var table: String
        var id: UUID
        var updatedAt: Date
        var deleted: Bool = false
        /// Clave estable para unir duplicados. Nil: la fila no se une con otra.
        var seedKey: String? = nil
    }

    struct Ref: Hashable, Sendable {
        var table: String
        var id: UUID
    }

    struct Plan: Equatable, Sendable {
        /// Filas locales que se suben: la nube no las tiene o aquí cambiaron después.
        var push: [Ref] = []
        /// Filas de la nube que se escriben aquí: este dispositivo no las tiene o allá cambiaron después.
        var take: [Ref] = []
        /// Duplicados locales que se cambian por la fila de la nube: tabla › id local › id de la nube.
        var remap: [String: [UUID: UUID]] = [:]
        /// Iguales en los dos lados: no se hace nada.
        var unchanged = 0
    }

    /// Tablas cuyas filas se unen por una clave estable.
    static let seedTables: Set<String> = ["categories", "merchant_alias"]

    /// Arma el plan de la primera subida. Puro: no toca la base ni la red.
    static func plan(local: [Item], remote: [Item]) -> Plan {
        var remoteById: [Ref: Item] = [:]
        var remoteOrder: [Ref] = []
        var remoteBySeed: [String: Item] = [:]
        for item in remote {
            let ref = Ref(table: item.table, id: item.id)
            if let seen = remoteById[ref] {
                if item.updatedAt > seen.updatedAt { remoteById[ref] = item }
            } else {
                remoteById[ref] = item
                remoteOrder.append(ref)
            }
        }
        for ref in remoteOrder {
            guard let item = remoteById[ref], !item.deleted, let key = item.seedKey else { continue }
            let slot = item.table + "|" + key
            // Si la nube ya tiene dos con la misma clave, se usa la más vieja (y si empatan, el id menor): todos eligen igual.
            if let current = remoteBySeed[slot],
               current.updatedAt < item.updatedAt || (current.updatedAt == item.updatedAt && E2EEFormat.id(current.id) < E2EEFormat.id(item.id)) {
                continue
            }
            remoteBySeed[slot] = item
        }

        var plan = Plan()
        var localRefs = Set<Ref>()
        for item in local {
            let ref = Ref(table: item.table, id: item.id)
            guard !localRefs.contains(ref) else { continue }
            localRefs.insert(ref)
            if let theirs = remoteById[ref] {
                if item.table == "spaces" {
                    plan.take.append(ref)
                } else if item.updatedAt > theirs.updatedAt {
                    plan.push.append(ref)
                } else if item.updatedAt < theirs.updatedAt {
                    plan.take.append(ref)
                } else {
                    plan.unchanged += 1
                }
            } else if !item.deleted, let key = item.seedKey, let twin = remoteBySeed[item.table + "|" + key], twin.id != item.id {
                plan.remap[item.table, default: [:]][item.id] = twin.id
            } else {
                plan.push.append(ref)
            }
        }
        for ref in remoteOrder where !localRefs.contains(ref) {
            plan.take.append(ref)
        }
        return plan
    }

    /// El id que queda después de unir duplicados.
    static func remapped(_ id: UUID?, in map: [UUID: UUID]) -> UUID? {
        guard let id else { return nil }
        return map[id] ?? id
    }

    // MARK: Claves estables

    /// "Mascotas ", "mascotas" y "MASCOTÁS" dan "mascotas": minúsculas, sin tildes, solo letras y números, un espacio.
    static func normalizedName(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_CO")).lowercased()
        var out = ""
        var pendingSpace = false
        for character in folded {
            if character.isLetter || character.isNumber {
                if pendingSpace && !out.isEmpty { out.append(" ") }
                pendingSpace = false
                out.append(character)
            } else {
                pendingSpace = true
            }
        }
        return out
    }

    /// Clave de una categoría: nombre normalizado y, si la categoría tiene tipo (gasto o ingreso), el tipo.
    static func categoryKey(name: String, kind: String? = nil) -> String? {
        let clean = normalizedName(name)
        guard !clean.isEmpty else { return nil }
        guard let kind, !kind.isEmpty else { return clean }
        return normalizedName(kind) + "|" + clean
    }

    /// La clave estable de una fila a partir de su JSON (la fila del respaldo). Nil si la tabla no se une.
    static func seedKey(table: String, payload: Data) -> String? {
        guard seedTables.contains(table),
              let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] else { return nil }
        switch table {
        case "categories":
            guard let name = object["name"] as? String else { return nil }
            return categoryKey(name: name, kind: object["kindRaw"] as? String)
        case "merchant_alias":
            guard let key = object["key"] as? String else { return nil }
            let clean = normalizedName(key)
            return clean.isEmpty ? nil : clean
        default:
            return nil
        }
    }

    // MARK: Textos y marca de hecho

    /// "Subiendo tus datos: 120 de 340".
    static func progressText(done: Int, total: Int) -> String {
        total <= 0 ? "Preparando tus datos…" : "Subiendo tus datos: \(min(done, total)) de \(total)"
    }

    static let doneText = "Tus datos ya están en la nube, cifrados"

    /// Llave en las preferencias del dispositivo: la primera subida de este usuario a este espacio ya se hizo.
    static func storageKey(spaceId: UUID, userId: UUID) -> String {
        "nube.subidaInicial.\(E2EEFormat.id(spaceId)).\(E2EEFormat.id(userId))"
    }
}

/// La base local con lo que necesita la primera subida (SwiftData en la app, una memoria en las pruebas).
@MainActor
protocol InitialUploadLocal: LocalSyncStore {
    /// Todas las filas locales que se sincronizan, pendientes o no, con su clave estable.
    func uploadItems() throws -> [InitialUpload.Item]
    /// Pasa las referencias de cada duplicado local al id de la nube y borra el duplicado (nunca subió).
    func resolveDuplicates(_ remap: [String: [UUID: UUID]]) throws
    /// Deja estas filas pendientes para subirlas.
    func queue(_ refs: [InitialUpload.Ref]) throws
}

extension SyncEngine {
    /// Primera subida (F10-05): baja todo, une duplicados, escribe lo que gana la nube y sube el resto en lotes.
    /// `progress` recibe (subidas, total). Si la base local no sabe planear, es una sincronización normal.
    func initialUpload(progress: (Int, Int) -> Void = { _, _ in }) async throws -> Report {
        guard let store = local as? any InitialUploadLocal else { return try await run() }
        var report = Report()
        var rowsByTable: [String: [SyncRecord]] = [:]
        var remoteItems: [InitialUpload.Item] = []
        for table in Self.tables {
            let rows = try await remote.pull(table: table, since: nil)
            rowsByTable[table] = rows
            remoteItems += rows.map {
                InitialUpload.Item(table: table, id: $0.id, updatedAt: $0.updatedAt, deleted: $0.deletedAt != nil,
                                   seedKey: InitialUpload.seedKey(table: table, payload: $0.payload))
            }
        }
        let plan = InitialUpload.plan(local: try store.uploadItems(), remote: remoteItems)
        let take = Set(plan.take)
        for table in Self.tables {
            let rows = rowsByTable[table] ?? []
            for row in rows {
                if take.contains(InitialUpload.Ref(table: table, id: row.id)) {
                    try store.apply(row)
                    report.pulled += 1
                } else {
                    report.skipped += 1
                }
            }
            if let newest = rows.map({ $0.serverUpdatedAt ?? $0.updatedAt }).max() {
                store.setCursor(newest, table: table)
            }
        }
        try store.resolveDuplicates(plan.remap)
        try store.queue(plan.push)
        let pushed = try await pushPending(batchSize: batchSize, progress: progress)
        report.pushed = pushed.pushed
        report.failed = pushed.failed
        return report
    }
}
