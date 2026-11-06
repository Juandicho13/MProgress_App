import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

/// Cifrador falso para probar el formato y la lógica sin CryptoKit (no existe en Linux).
/// Cumple lo que importa: el acuerdo de llaves es simétrico, abrir con otra llave u otros datos asociados
/// falla, y derivar con lo mismo da lo mismo. No es seguro: solo sirve para pruebas.
struct FakeCrypto: CryptoProvider {
    struct Failure: Error {}

    /// Diffie-Hellman de juguete módulo el primo de Mersenne 2^61 - 1.
    private static let prime: UInt64 = (1 << 61) - 1
    private static let generator: UInt64 = 37

    func randomBytes(_ count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) })
    }

    func newAgreementKeyPair() -> DeviceKeyPair {
        var generator = SystemRandomNumberGenerator()
        let secret = UInt64.random(in: 2...(Self.prime - 2), using: &generator)
        return DeviceKeyPair(privateKey: Self.pad(secret), publicKey: Self.pad(Self.power(Self.generator, secret)))
    }

    func sharedSecret(privateKey: Data, peerPublicKey: Data) throws -> Data {
        Self.pad(Self.power(Self.unpad(peerPublicKey), Self.unpad(privateKey)))
    }

    func hkdf(inputKeyMaterial: Data, salt: Data, info: Data, outputByteCount: Int) -> Data {
        var output = Data()
        var counter: UInt8 = 0
        while output.count < outputByteCount {
            counter &+= 1
            var block = Data([counter])
            block.append(inputKeyMaterial)
            block.append(0xFF)
            block.append(salt)
            block.append(0xFE)
            block.append(info)
            var hash = Self.fnv(block)
            withUnsafeBytes(of: &hash) { output.append(contentsOf: $0) }
        }
        return output.prefix(outputByteCount)
    }

    func seal(_ plaintext: Data, key: Data, associatedData: Data) throws -> Data {
        let nonce = randomBytes(12)
        let stream = hkdf(inputKeyMaterial: key, salt: nonce, info: Data("flujo".utf8), outputByteCount: plaintext.count)
        let cipher = Data(zip(plaintext, stream).map { $0 ^ $1 })
        return nonce + cipher + tag(key: key, nonce: nonce, ad: associatedData, cipher: cipher)
    }

    func open(_ combined: Data, key: Data, associatedData: Data) throws -> Data {
        guard combined.count >= 28 else { throw Failure() }
        let nonce = Data(combined.prefix(12))
        let cipher = Data(combined.dropFirst(12).dropLast(16))
        guard Data(combined.suffix(16)) == tag(key: key, nonce: nonce, ad: associatedData, cipher: cipher) else { throw Failure() }
        let stream = hkdf(inputKeyMaterial: key, salt: nonce, info: Data("flujo".utf8), outputByteCount: cipher.count)
        return Data(zip(cipher, stream).map { $0 ^ $1 })
    }

    func sha256(_ data: Data) -> Data {
        hkdf(inputKeyMaterial: data, salt: Data(), info: Data("sha".utf8), outputByteCount: 32)
    }

    private func tag(key: Data, nonce: Data, ad: Data, cipher: Data) -> Data {
        hkdf(inputKeyMaterial: key, salt: nonce + ad + Data([0]) + cipher, info: Data("etiqueta".utf8), outputByteCount: 16)
    }

    private static func fnv(_ data: Data) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private static func multiply(_ a: UInt64, _ b: UInt64) -> UInt64 {
        let product = a.multipliedFullWidth(by: b)
        return prime.dividingFullWidth((product.high, product.low)).remainder
    }

    private static func power(_ base: UInt64, _ exponent: UInt64) -> UInt64 {
        var result: UInt64 = 1
        var base = base % prime
        var exponent = exponent
        while exponent > 0 {
            if exponent & 1 == 1 { result = multiply(result, base) }
            base = multiply(base, base)
            exponent >>= 1
        }
        return result
    }

    private static func pad(_ value: UInt64) -> Data {
        var data = Data(count: 32)
        for index in 0..<8 { data[index] = UInt8((value >> (UInt64(index) * 8)) & 0xFF) }
        return data
    }

    private static func unpad(_ data: Data) -> UInt64 {
        var value: UInt64 = 0
        for (index, byte) in data.prefix(8).enumerated() { value |= UInt64(byte) << (UInt64(index) * 8) }
        return value
    }
}

struct E2EETests {
    let crypto = FakeCrypto()
    let space = UUID()
    let deviceB = UUID()

    @Test("Envolver y desenvolver la llave del espacio entre dos pares X25519")
    func envolver() throws {
        let alice = crypto.newAgreementKeyPair()
        let bob = crypto.newAgreementKeyPair()
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let wrapped = try SpaceKeyWrap.wrap(key, spaceId: space, recipientDeviceId: deviceB, recipientPublicKey: bob.publicKey,
                                            sender: alice, crypto: crypto)
        let opened = try SpaceKeyWrap.unwrap(wrapped, spaceId: space, recipientDeviceId: deviceB, recipient: bob,
                                             trustedSenders: [alice.publicKey], crypto: crypto)
        #expect(opened.spaceKey == key)
        #expect(opened.senderPublicKey == alice.publicKey)
        #expect(Data(base64Encoded: wrapped)?.first == 1)
    }

    @Test("La llave envuelta no abre para otro dispositivo, otro espacio ni de un remitente ajeno")
    func envolverFalla() throws {
        let alice = crypto.newAgreementKeyPair()
        let bob = crypto.newAgreementKeyPair()
        let mallory = crypto.newAgreementKeyPair()
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let wrapped = try SpaceKeyWrap.wrap(key, spaceId: space, recipientDeviceId: deviceB, recipientPublicKey: bob.publicKey,
                                            sender: alice, crypto: crypto)
        #expect(throws: E2EEError.cannotOpen) {
            try SpaceKeyWrap.unwrap(wrapped, spaceId: space, recipientDeviceId: deviceB, recipient: mallory, crypto: crypto)
        }
        #expect(throws: E2EEError.cannotOpen) {
            try SpaceKeyWrap.unwrap(wrapped, spaceId: UUID(), recipientDeviceId: deviceB, recipient: bob, crypto: crypto)
        }
        #expect(throws: E2EEError.cannotOpen) {
            try SpaceKeyWrap.unwrap(wrapped, spaceId: space, recipientDeviceId: UUID(), recipient: bob, crypto: crypto)
        }
        #expect(throws: E2EEError.untrustedSender) {
            try SpaceKeyWrap.unwrap(wrapped, spaceId: space, recipientDeviceId: deviceB, recipient: bob,
                                    trustedSenders: [mallory.publicKey], crypto: crypto)
        }
        #expect(throws: E2EEError.badFormat) {
            try SpaceKeyWrap.unwrap("no-es-base64", spaceId: space, recipientDeviceId: deviceB, recipient: bob, crypto: crypto)
        }
    }

    @Test("Cifrar y descifrar un sobre; falla si cambian el espacio, el tipo o el id")
    func sobre() throws {
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let id = UUID()
        let json = Data(#"{"name":"Mercado","amountMinor":8430000}"#.utf8)
        let sealed = try Envelope.seal(json, spaceId: space, entity: "entries", id: id, key: key, crypto: crypto)
        #expect(!sealed.contains("Mercado"))
        #expect(try Envelope.open(sealed, spaceId: space, entity: "entries", id: id, key: key, crypto: crypto) == json)
        #expect(throws: E2EEError.cannotOpen) { try Envelope.open(sealed, spaceId: UUID(), entity: "entries", id: id, key: key, crypto: crypto) }
        #expect(throws: E2EEError.cannotOpen) { try Envelope.open(sealed, spaceId: space, entity: "recurring", id: id, key: key, crypto: crypto) }
        #expect(throws: E2EEError.cannotOpen) { try Envelope.open(sealed, spaceId: space, entity: "entries", id: UUID(), key: key, crypto: crypto) }
        #expect(throws: E2EEError.cannotOpen) {
            try Envelope.open(sealed, spaceId: space, entity: "entries", id: id, key: SpaceKeyWrap.newSpaceKey(crypto: crypto), crypto: crypto)
        }
    }

    @Test("Los datos asociados usan los UUID en minúscula, como Postgres")
    func datosAsociados() {
        let space = UUID(uuidString: "A1B2C3D4-0000-4000-8000-00000000000A")!
        let id = UUID(uuidString: "0A000000-0000-4000-8000-000000000001")!
        #expect(String(data: Envelope.ad(spaceId: space, entity: "entries", id: id), encoding: .utf8)
                == "a1b2c3d4-0000-4000-8000-00000000000a|entries|0a000000-0000-4000-8000-000000000001")
        #expect(String(data: SpaceKeyWrap.recoveryAD(spaceId: space), encoding: .utf8) == "a1b2c3d4-0000-4000-8000-00000000000a|recuperacion")
    }

    @Test("Código de recuperación: 24 caracteres en grupos de 4, sin ambiguos, y la misma llave con el mismo código")
    func codigo() throws {
        let code = RecoveryCode.generate(crypto: crypto)
        #expect(code.count == 29)
        #expect(code.split(separator: "-").count == 6)
        #expect(code.split(separator: "-").allSatisfy { $0.count == 4 })
        #expect(!code.contains { "01IO".contains($0) })
        let clean = try #require(RecoveryCode.normalize(code))
        #expect(clean.count == 24)
        #expect(RecoveryCode.normalize(code.lowercased().replacingOccurrences(of: "-", with: " ")) == clean)
        #expect(RecoveryCode.normalize("ABCD-EFGH") == nil)
        #expect(RecoveryCode.normalize("ABCD-EFGH-JKLM-NPQR-STUV-WXY0") == nil)
        #expect(try RecoveryCode.key(code, crypto: crypto) == RecoveryCode.key(code.lowercased(), crypto: crypto))
        #expect(try RecoveryCode.key(code, crypto: crypto) != RecoveryCode.key(RecoveryCode.generate(crypto: crypto), crypto: crypto))
        #expect(throws: E2EEError.badRecoveryCode) { try RecoveryCode.key("hola", crypto: crypto) }
        #expect(RecoveryCode.encode(Data(repeating: 0, count: 15)) == String(repeating: "A", count: 24))
        #expect(RecoveryCode.encode(Data(repeating: 0xFF, count: 15)) == String(repeating: "9", count: 24))
    }

    @Test("Con el código se recupera la llave del espacio en un dispositivo nuevo")
    func recuperar() throws {
        let code = RecoveryCode.generate(crypto: crypto)
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let wrapped = try SpaceKeyWrap.wrapForRecovery(key, spaceId: space, recoveryKey: RecoveryCode.key(code, crypto: crypto), crypto: crypto)
        #expect(Data(base64Encoded: wrapped)?.first == 2)
        let again = try SpaceKeyWrap.unwrapWithRecovery(wrapped, spaceId: space, recoveryKey: RecoveryCode.key(code, crypto: crypto), crypto: crypto)
        #expect(again == key)
        let other = try RecoveryCode.key(RecoveryCode.generate(crypto: crypto), crypto: crypto)
        #expect(throws: E2EEError.badRecoveryCode) {
            try SpaceKeyWrap.unwrapWithRecovery(wrapped, spaceId: space, recoveryKey: other, crypto: crypto)
        }
    }

    @Test("PKCE: verificador base64url de 64 caracteres y reto S256 estable")
    func pkce() {
        let verifier = PKCE.newVerifier(crypto: crypto)
        #expect(verifier.count == 64)
        #expect(!verifier.contains { "+/=".contains($0) })
        #expect(PKCE.challenge(for: verifier, crypto: crypto) == PKCE.challenge(for: verifier, crypto: crypto))
        #expect(PKCE.base64URL(Data([0xFB, 0xFF, 0xFE])) == "-__-")
    }
}

/// Servidor de sobres en memoria: hace lo mismo que el disparador de `sync_records`.
@MainActor
final class FakeEnvelopeServer: EnvelopeTransport {
    var rows: [UUID: SyncEnvelope] = [:]
    var clock = Date(timeIntervalSince1970: 1_800_000_000)

    func upsert(_ incoming: [SyncEnvelope]) async throws {
        for var row in incoming {
            if let old = rows[row.id], row.changedAt < old.changedAt { continue }
            clock = clock.addingTimeInterval(1)
            row.updatedAt = clock
            rows[row.id] = row
        }
    }

    func fetch(entity: String, since: Date?) async throws -> [SyncEnvelope] {
        rows.values
            .filter { $0.entity == entity && (since == nil || ($0.updatedAt ?? .distantPast) > since!) }
            .sorted { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
    }
}

@MainActor
struct EncryptedSyncTests {
    let crypto = FakeCrypto()
    let space = UUID()

    private func record(_ id: UUID, _ name: String, _ at: Date) -> SyncRecord {
        SyncRecord(table: "entries", id: id, updatedAt: at, payload: Data(#"{"name":"\#(name)"}"#.utf8))
    }

    @Test("SyncEngine con sobres: el servidor solo ve texto cifrado y otro teléfono con la llave lo lee")
    func sincronizar() async throws {
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let server = FakeEnvelopeServer()
        let id = UUID()

        let phoneA = FakeLocal()
        phoneA.edit(record(id, "Mercado", fecha(2026, 11, 8, 10)))
        let remoteA = EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: space) { $0 == space ? key : nil }
        let pushed = try await SyncEngine(local: phoneA, remote: remoteA).run()
        #expect(pushed.pushed == 1)
        #expect(server.rows[id]?.spaceId == space)
        #expect(server.rows[id]?.payload.contains("Mercado") == false)

        let phoneB = FakeLocal()
        let remoteB = EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: space) { $0 == space ? key : nil }
        let pulled = try await SyncEngine(local: phoneB, remote: remoteB).run()
        #expect(pulled.pulled == 1)
        let row = try #require(phoneB.rows["entries"]?[id])
        #expect(String(data: row.payload, encoding: .utf8)?.contains("Mercado") == true)
        #expect(phoneB.cursors["entries"] == server.rows[id]?.updatedAt)
    }

    @Test("Sin la llave no se lee nada; y gana el cambio más nuevo hecho en el teléfono")
    func sinLlaveYChoques() async throws {
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let server = FakeEnvelopeServer()
        let id = UUID()

        let phoneA = FakeLocal()
        phoneA.edit(record(id, "Nuevo", fecha(2026, 11, 8, 12)))
        try await SyncEngine(local: phoneA, remote: EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: space) { _ in key }).run()

        // Un teléfono con un cambio más viejo del mismo registro no pisa el del servidor.
        let phoneB = FakeLocal()
        phoneB.edit(record(id, "Viejo", fecha(2026, 11, 8, 9)))
        try await SyncEngine(local: phoneB, remote: EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: space) { _ in key }).run()
        let opened = try Envelope.open(try #require(server.rows[id]?.payload), spaceId: space, entity: "entries", id: id, key: key, crypto: crypto)
        #expect(String(data: opened, encoding: .utf8)?.contains("Nuevo") == true)
        #expect(String(data: try #require(phoneB.rows["entries"]?[id]?.payload), encoding: .utf8)?.contains("Nuevo") == true)

        let stranger = FakeLocal()
        let blind = EncryptedRemote(transport: server, crypto: crypto, defaultSpaceId: space) { _ in nil }
        let report = try await SyncEngine(local: stranger, remote: blind).run()
        #expect(report.pulled == 0)
        #expect(blind.unreadable == 1)
        #expect(stranger.rows.isEmpty)
    }

    @Test("Sin la llave no se sube nada")
    func sinLlaveNoSube() async throws {
        let phone = FakeLocal()
        phone.edit(record(UUID(), "Taxi", fecha(2026, 11, 8, 10)))
        let remote = EncryptedRemote(transport: FakeEnvelopeServer(), crypto: crypto, defaultSpaceId: space) { _ in nil }
        await #expect(throws: E2EEError.self) { try await SyncEngine(local: phone, remote: remote).run() }
    }
}
