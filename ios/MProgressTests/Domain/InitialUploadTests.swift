import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

/// Base local en memoria que sabe hacer la primera subida. Cada fila es un JSON pequeño como el del respaldo.
@MainActor
final class UploadLocal: InitialUploadLocal {
    var rows: [String: [UUID: SyncRecord]] = [:]
    var pendingIds: [UUID] = []
    var failures: [UUID: Int] = [:]
    var cursors: [String: Date] = [:]
    var resolved: [String: [UUID: UUID]] = [:]

    func json(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }

    func add(_ table: String, _ id: UUID = UUID(), at date: Date, _ fields: [String: Any] = [:], pending: Bool = true) -> UUID {
        var object = fields
        object["id"] = E2EEFormat.id(id)
        rows[table, default: [:]][id] = SyncRecord(table: table, id: id, updatedAt: date, deletedAt: nil, payload: json(object))
        if pending { pendingIds.append(id) }
        return id
    }

    func field(_ table: String, _ id: UUID, _ key: String) -> String? {
        guard let payload = rows[table]?[id]?.payload,
              let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] else { return nil }
        return object[key] as? String
    }

    func pending() throws -> [SyncRecord] {
        pendingIds.compactMap { id in rows.values.compactMap { $0[id] }.first }
    }

    func markSynced(_ records: [SyncRecord]) throws {
        let ids = Set(records.map(\.id))
        pendingIds.removeAll { ids.contains($0) }
    }

    func markFailed(_ records: [SyncRecord], attempts: Int) throws {
        for record in records { failures[record.id] = attempts }
    }

    func attempts(for record: SyncRecord) -> Int { failures[record.id] ?? 0 }
    func local(table: String, id: UUID) throws -> SyncRecord? { rows[table]?[id] }

    func apply(_ record: SyncRecord) throws {
        rows[record.table, default: [:]][record.id] = record
        pendingIds.removeAll { $0 == record.id }
    }

    func cursor(table: String) -> Date? { cursors[table] }
    func setCursor(_ date: Date, table: String) { cursors[table] = date }

    func uploadItems() throws -> [InitialUpload.Item] {
        SyncEngine.tables.flatMap { table in
            (rows[table] ?? [:]).values.sorted { $0.updatedAt < $1.updatedAt }.map {
                InitialUpload.Item(table: table, id: $0.id, updatedAt: $0.updatedAt, deleted: $0.deletedAt != nil,
                                   seedKey: InitialUpload.seedKey(table: table, payload: $0.payload))
            }
        }
    }

    func resolveDuplicates(_ remap: [String: [UUID: UUID]]) throws {
        resolved = remap
        let categories = remap["categories"] ?? [:]
        for table in ["entries", "recurring", "budgets", "merchant_alias"] {
            for (id, record) in rows[table] ?? [:] {
                guard var object = (try? JSONSerialization.jsonObject(with: record.payload)) as? [String: Any],
                      let raw = object["categoryId"] as? String, let old = UUID(uuidString: raw), let new = categories[old] else { continue }
                object["categoryId"] = E2EEFormat.id(new)
                var changed = record
                changed.payload = json(object)
                rows[table]?[id] = changed
                if !pendingIds.contains(id) { pendingIds.append(id) }
            }
        }
        for (table, map) in remap {
            for id in map.keys {
                rows[table]?[id] = nil
                pendingIds.removeAll { $0 == id }
            }
        }
    }

    func queue(_ refs: [InitialUpload.Ref]) throws {
        for ref in refs where !pendingIds.contains(ref.id) && rows[ref.table]?[ref.id] != nil { pendingIds.append(ref.id) }
    }
}

@MainActor
struct InitialUploadTests {
    typealias Item = InitialUpload.Item
    typealias Ref = InitialUpload.Ref

    @Test("Plan: sube lo que la nube no tiene o lo que cambió aquí después; baja lo nuevo de allá")
    func planBasico() {
        let mio = UUID(), viejoAqui = UUID(), nuevoAqui = UUID(), igual = UUID(), soloNube = UUID()
        let plan = InitialUpload.plan(
            local: [Item(table: "entries", id: mio, updatedAt: fecha(2026, 11, 1)),
                    Item(table: "entries", id: viejoAqui, updatedAt: fecha(2026, 11, 1)),
                    Item(table: "entries", id: nuevoAqui, updatedAt: fecha(2026, 11, 5)),
                    Item(table: "entries", id: igual, updatedAt: fecha(2026, 11, 3))],
            remote: [Item(table: "entries", id: viejoAqui, updatedAt: fecha(2026, 11, 4)),
                     Item(table: "entries", id: nuevoAqui, updatedAt: fecha(2026, 11, 2)),
                     Item(table: "entries", id: igual, updatedAt: fecha(2026, 11, 3)),
                     Item(table: "entries", id: soloNube, updatedAt: fecha(2026, 11, 2))])
        #expect(plan.push == [Ref(table: "entries", id: mio), Ref(table: "entries", id: nuevoAqui)])
        #expect(plan.take == [Ref(table: "entries", id: viejoAqui), Ref(table: "entries", id: soloNube)])
        #expect(plan.unchanged == 1)
        #expect(plan.remap.isEmpty)
    }

    @Test("Plan: la misma categoría creada en dos teléfonos se une con la de la nube")
    func planUneCategorias() {
        let aqui = UUID(), nube = UUID(), otra = UUID()
        let plan = InitialUpload.plan(
            local: [Item(table: "categories", id: aqui, updatedAt: fecha(2026, 11, 5), seedKey: InitialUpload.categoryKey(name: "Mascotas ")),
                    Item(table: "categories", id: otra, updatedAt: fecha(2026, 11, 5), seedKey: InitialUpload.categoryKey(name: "Viajes"))],
            remote: [Item(table: "categories", id: nube, updatedAt: fecha(2026, 11, 1), seedKey: InitialUpload.categoryKey(name: "MASCOTÁS"))])
        #expect(plan.remap == ["categories": [aqui: nube]])
        #expect(plan.push == [Ref(table: "categories", id: otra)])
        #expect(plan.take == [Ref(table: "categories", id: nube)])
    }

    @Test("Plan: una categoría borrada en la nube no se usa para unir, y la nube manda en los ajustes del espacio")
    func planBorradaYEspacio() {
        let aqui = UUID(), borrada = UUID(), espacio = UUID()
        let plan = InitialUpload.plan(
            local: [Item(table: "categories", id: aqui, updatedAt: fecha(2026, 11, 5), seedKey: "mascotas"),
                    Item(table: "spaces", id: espacio, updatedAt: fecha(2026, 11, 6))],
            remote: [Item(table: "categories", id: borrada, updatedAt: fecha(2026, 11, 1), deleted: true, seedKey: "mascotas"),
                     Item(table: "spaces", id: espacio, updatedAt: fecha(2026, 11, 1))])
        #expect(plan.remap.isEmpty)
        #expect(plan.push == [Ref(table: "categories", id: aqui)])
        #expect(plan.take.contains(Ref(table: "spaces", id: espacio)))
    }

    @Test("Plan: con dos iguales en la nube todos eligen la más vieja")
    func planDosIgualesEnLaNube() {
        let aqui = UUID(), vieja = UUID(), nueva = UUID()
        let plan = InitialUpload.plan(
            local: [Item(table: "merchant_alias", id: aqui, updatedAt: fecha(2026, 11, 5), seedKey: "pepepollo")],
            remote: [Item(table: "merchant_alias", id: nueva, updatedAt: fecha(2026, 11, 3), seedKey: "pepepollo"),
                     Item(table: "merchant_alias", id: vieja, updatedAt: fecha(2026, 11, 2), seedKey: "pepepollo")])
        #expect(plan.remap == ["merchant_alias": [aqui: vieja]])
    }

    @Test("Claves estables: nombre sin tildes ni mayúsculas, regla de comercio por su clave")
    func claves() {
        #expect(InitialUpload.normalizedName("  Mascotás  y   Más! ") == "mascotas y mas")
        #expect(InitialUpload.normalizedName("Niño") == "nino")
        #expect(InitialUpload.categoryKey(name: "Comida", kind: "gasto") == "gasto|comida")
        #expect(InitialUpload.categoryKey(name: "  ") == nil)
        let categoria = Data(#"{"id":"x","name":"Café ","icon":"cup"}"#.utf8)
        #expect(InitialUpload.seedKey(table: "categories", payload: categoria) == "cafe")
        let regla = Data(#"{"id":"x","key":"PEPEPOLLO","name":"El Corral"}"#.utf8)
        #expect(InitialUpload.seedKey(table: "merchant_alias", payload: regla) == "pepepollo")
        #expect(InitialUpload.seedKey(table: "entries", payload: categoria) == nil)
        #expect(InitialUpload.remapped(nil, in: [:]) == nil)
        let a = UUID(), b = UUID()
        #expect(InitialUpload.remapped(a, in: [a: b]) == b)
        #expect(InitialUpload.remapped(b, in: [a: b]) == b)
    }

    @Test("Textos de la primera subida y su marca por espacio y usuario")
    func textos() {
        #expect(InitialUpload.progressText(done: 120, total: 340) == "Subiendo tus datos: 120 de 340")
        #expect(InitialUpload.progressText(done: 400, total: 340) == "Subiendo tus datos: 340 de 340")
        #expect(InitialUpload.progressText(done: 0, total: 0) == "Preparando tus datos…")
        #expect(InitialUpload.doneText == "Tus datos ya están en la nube, cifrados")
        let space = UUID(uuidString: "5A0F3C1E-8D2B-4C6A-9E7F-112233445566")!
        let user = UUID(uuidString: "0E000000-0000-4000-8000-000000000001")!
        #expect(InitialUpload.storageKey(spaceId: space, userId: user)
                == "nube.subidaInicial.5a0f3c1e-8d2b-4c6a-9e7f-112233445566.0e000000-0000-4000-8000-000000000001")
    }

    @Test("Primer dispositivo: sube todo una sola vez, en lotes, con avance")
    func primerDispositivo() async throws {
        let server = FakeRemote()
        let juan = UploadLocal()
        for day in 1...7 { _ = juan.add("entries", at: fecha(2026, 11, day), ["name": "Gasto \(day)"]) }
        _ = juan.add("categories", at: fecha(2026, 11, 1), ["name": "Mascotas"])
        var avance: [String] = []
        let report = try await SyncEngine(local: juan, remote: server, batchSize: 3).initialUpload { done, total in
            avance.append("\(done)/\(total)")
        }
        #expect(report.pushed == 8)
        #expect(avance == ["0/8", "3/8", "6/8", "8/8"])
        #expect(server.rows["entries"]?.count == 7)
        #expect(try juan.pending().isEmpty)
        // Sincronizar otra vez no sube nada.
        #expect(try await SyncEngine(local: juan, remote: server).run().pushed == 0)
    }

    @Test("Segundo dispositivo: baja primero, une la categoría repetida y sube solo lo suyo")
    func segundoDispositivo() async throws {
        let server = FakeRemote()
        let juan = UploadLocal()
        let mascotasJuan = juan.add("categories", at: fecha(2026, 11, 1), ["name": "Mascotas"])
        let comun = juan.add("entries", at: fecha(2026, 11, 2), ["name": "Concentrado", "categoryId": E2EEFormat.id(mascotasJuan)])
        _ = try await SyncEngine(local: juan, remote: server).initialUpload()
        #expect(server.pushes == 1)

        let tablet = UploadLocal()
        let mascotasTablet = tablet.add("categories", at: fecha(2026, 11, 3), ["name": "mascotas "])
        let veterinaria = tablet.add("entries", at: fecha(2026, 11, 4), ["name": "Veterinaria", "categoryId": E2EEFormat.id(mascotasTablet)])
        // El mismo movimiento ya estaba aquí (por un respaldo) pero más viejo: gana la nube y no se sube.
        _ = tablet.add("entries", comun, at: fecha(2026, 11, 1), ["name": "Viejo"])
        let report = try await SyncEngine(local: tablet, remote: server).initialUpload()

        #expect(tablet.resolved == ["categories": [mascotasTablet: mascotasJuan]])
        #expect(tablet.rows["categories"]?[mascotasTablet] == nil)
        #expect(tablet.field("entries", veterinaria, "categoryId") == E2EEFormat.id(mascotasJuan))
        #expect(tablet.field("entries", comun, "name") == "Concentrado")
        #expect(report.pushed == 1)
        #expect(server.rows["categories"]?.count == 1)
        #expect(server.rows["entries"]?.count == 2)
        #expect(tablet.cursors["entries"] != nil)
        #expect(try await SyncEngine(local: tablet, remote: server).run().pushed == 0)
    }

    @Test("Una fila ya sincronizada que la nube no tiene (otra cuenta) se vuelve a subir")
    func filaSincronizadaQueLaNubeNoTiene() async throws {
        let server = FakeRemote()
        let local = UploadLocal()
        let id = local.add("entries", at: fecha(2026, 11, 2), ["name": "Mercado"], pending: false)
        #expect(try local.pending().isEmpty)
        let report = try await SyncEngine(local: local, remote: server).initialUpload()
        #expect(report.pushed == 1)
        #expect(server.rows["entries"]?[id] != nil)
    }

    @Test("Sin conexión la primera subida no se marca y al reintentar no repite lo que ya subió")
    func sinConexion() async throws {
        let server = FakeRemote()
        let local = UploadLocal()
        for day in 1...4 { _ = local.add("entries", at: fecha(2026, 11, day)) }
        server.failNext = 1
        await #expect(throws: FakeRemote.Offline.self) {
            _ = try await SyncEngine(local: local, remote: server, batchSize: 2).initialUpload()
        }
        let report = try await SyncEngine(local: local, remote: server, batchSize: 2).initialUpload()
        #expect(report.pushed == 4)
        #expect(server.rows["entries"]?.count == 4)
        let again = try await SyncEngine(local: local, remote: server).initialUpload()
        #expect(again.pushed == 0)
        #expect(again.skipped == 4)
    }
}
