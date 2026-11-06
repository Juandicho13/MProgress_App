import Foundation
import SwiftData
import Testing
@testable import MProgress

/// F10 en la base: la tienda de sincronización con SwiftData, adoptar el espacio de la nube y dos teléfonos
/// sincronizando sobres cifrados con CryptoKit a través de un servidor falso.
@MainActor
struct CloudSyncTests {
    private func phone() throws -> (ModelContainer, Space, UserDefaults) {
        let container = try Persistence.makeContainer(inMemory: true)
        let space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        let defaults = UserDefaults(suiteName: "pruebas.\(UUID().uuidString)")!
        return (container, space, defaults)
    }

    @Test("Lo local queda pendiente; las categorías globales no se suben; marcar subido lo saca")
    func pendientes() throws {
        let (container, space, defaults) = try phone()
        let entry = try LedgerStore(context: container.mainContext, calendar: bogota)
            .addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(84_300), name: "Mercado")
        let store = SwiftDataSyncStore(context: container.mainContext, defaults: defaults)
        let pending = try store.pending()
        #expect(pending.contains { $0.table == "entries" && $0.id == entry.id })
        #expect(pending.contains { $0.table == "spaces" && $0.id == space.id })
        #expect(!pending.contains { $0.table == "categories" })
        let json = try #require(pending.first { $0.id == entry.id })
        #expect(String(data: json.payload, encoding: .utf8)?.contains("Mercado") == true)
        #expect(json.spaceId == space.id)
        try store.markSynced(pending)
        #expect(try store.pending().isEmpty)
        #expect(entry.syncState == .synced)
    }

    @Test("Adoptar el espacio de la nube mueve todo lo local a ese id")
    func adoptar() throws {
        let (container, space, _) = try phone()
        let context = container.mainContext
        let entry = try LedgerStore(context: context, calendar: bogota).addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(10_000), name: "Taxi")
        let bank = try MoneyStore(context: context).addInstitution(spaceId: space.id, name: "Nu")
        let remote = UUID()
        let owner = UUID()
        try SpaceAdoption.adopt(remote, ownerId: owner, context: context)
        #expect(space.id == remote)
        #expect(space.ownerId == owner)
        #expect(entry.spaceId == remote)
        #expect(bank.spaceId == remote)
        #expect(try LedgerStore(context: context).entries(spaceId: remote).count == 1)
    }

    @Test("Dos teléfonos con la misma llave: lo que anota uno lo ve el otro, y el servidor no ve nada")
    func dosTelefonos() async throws {
        let crypto = CryptoKitProvider()
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let server = FakeEnvelopeServer()
        let spaceId = UUID()

        let (containerA, _, defaultsA) = try phone()
        try SpaceAdoption.adopt(spaceId, ownerId: UUID(), context: containerA.mainContext)
        try LedgerStore(context: containerA.mainContext, calendar: bogota)
            .addEntry(spaceId: spaceId, kind: .gasto, amountMinor: pesos(84_300), name: "Mercado")
        let storeA = SwiftDataSyncStore(context: containerA.mainContext, defaults: defaultsA)
        let remoteA = EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: spaceId) { $0 == spaceId ? key : nil }
        let first = try await SyncEngine(local: storeA, remote: remoteA).run()
        #expect(first.pushed >= 2)
        #expect(!server.rows.values.contains { $0.payload.contains("Mercado") })

        let (containerB, _, defaultsB) = try phone()
        try SpaceAdoption.adopt(spaceId, ownerId: UUID(), context: containerB.mainContext)
        let storeB = SwiftDataSyncStore(context: containerB.mainContext, defaults: defaultsB)
        let remoteB = EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: spaceId) { $0 == spaceId ? key : nil }
        _ = try await SyncEngine(local: storeB, remote: remoteB).run()
        let entriesB = try LedgerStore(context: containerB.mainContext).entries(spaceId: spaceId)
        #expect(entriesB.map(\.name) == ["Mercado"])
        #expect(entriesB.first?.amountMinor == pesos(84_300))
        #expect(entriesB.first?.syncState == .synced)

        // Bajar otra vez no cambia nada.
        let again = SwiftDataSyncStore(context: containerB.mainContext, defaults: defaultsB)
        _ = try await SyncEngine(local: again, remote: remoteB).run()
        #expect(again.appliedChanges == 0)

        // Borrar en B llega a A.
        let target = try #require(entriesB.first)
        try LedgerStore(context: containerB.mainContext).softDelete(target)
        _ = try await SyncEngine(local: SwiftDataSyncStore(context: containerB.mainContext, defaults: defaultsB), remote: remoteB).run()
        _ = try await SyncEngine(local: SwiftDataSyncStore(context: containerA.mainContext, defaults: defaultsA), remote: remoteA).run()
        #expect(try LedgerStore(context: containerA.mainContext).entries(spaceId: spaceId).isEmpty)
    }
}
