import Foundation

// Cifrado de extremo a extremo (docs/PLAN_F10.md). Aquí va solo la lógica y el formato: las primitivas
// (X25519, HKDF-SHA256, AES-GCM, SHA-256) entran por `CryptoProvider`. En la app las da CryptoKit
// (Data/Crypto/CryptoKitProvider.swift); en las pruebas de Linux, un cifrador falso.

/// Primitivas criptográficas. Las llaves y los textos van como bytes crudos.
protocol CryptoProvider: Sendable {
    func randomBytes(_ count: Int) -> Data
    /// Par X25519: privada y pública de 32 bytes.
    func newAgreementKeyPair() -> DeviceKeyPair
    /// Secreto compartido X25519 (32 bytes).
    func sharedSecret(privateKey: Data, peerPublicKey: Data) throws -> Data
    func hkdf(inputKeyMaterial: Data, salt: Data, info: Data, outputByteCount: Int) -> Data
    /// AES-256-GCM en formato combinado: nonce (12) | texto cifrado | etiqueta (16).
    func seal(_ plaintext: Data, key: Data, associatedData: Data) throws -> Data
    func open(_ combined: Data, key: Data, associatedData: Data) throws -> Data
    func sha256(_ data: Data) -> Data
}

/// Llaves X25519 de un dispositivo. La privada vive en el llavero y nunca sale del teléfono.
struct DeviceKeyPair: Hashable, Sendable {
    var privateKey: Data
    var publicKey: Data
}

enum E2EEError: Error, Equatable, LocalizedError {
    case badFormat
    case cannotOpen
    case untrustedSender
    case badRecoveryCode
    case missingKey

    var errorDescription: String? {
        switch self {
        case .badFormat: "El dato cifrado no tiene el formato esperado."
        case .cannotOpen: "No se pudo descifrar: la llave no corresponde o el dato cambió."
        case .untrustedSender: "La llave la envió un dispositivo que no es de tu cuenta."
        case .badRecoveryCode: "Ese código de recuperación no es válido. Son 24 letras y números en grupos de 4."
        case .missingKey: "Este dispositivo todavía no tiene la llave de tus datos."
        }
    }
}

/// Textos que se usan como datos asociados y para derivar llaves. Los UUID van en minúscula
/// (como los devuelve Postgres), así iOS y Android producen exactamente los mismos bytes.
enum E2EEFormat {
    static let spaceKeyInfo = Data("mprogress-space-key".utf8)
    static let recoverySalt = Data("mprogress-recovery".utf8)
    static let recoveryInfo = Data("mprogress-recovery-key".utf8)
    /// Primer byte del sobre de una llave envuelta para un dispositivo.
    static let deviceWrapVersion: UInt8 = 1
    /// Primer byte de una llave envuelta con el código de recuperación.
    static let recoveryWrapVersion: UInt8 = 2
    static let publicKeyLength = 32
    static let keyLength = 32

    static func id(_ uuid: UUID) -> String { uuid.uuidString.lowercased() }
    static func data(_ text: String) -> Data { Data(text.utf8) }
}

/// La llave del espacio (256 bits, AES-GCM) envuelta para cada dispositivo o para el código de recuperación.
enum SpaceKeyWrap {
    /// Llave nueva para un espacio.
    static func newSpaceKey(crypto: CryptoProvider) -> Data { crypto.randomBytes(E2EEFormat.keyLength) }

    /// Envuelve la llave para otro dispositivo (o para sí mismo):
    /// X25519(privada del que comparte, pública del que recibe) → HKDF-SHA256(sal = id del espacio,
    /// info = "mprogress-space-key") → AES-GCM con datos asociados "espacio|dispositivo".
    /// Resultado en base64: 0x01 | pública del que comparte (32) | AES-GCM combinado.
    static func wrap(_ spaceKey: Data, spaceId: UUID, recipientDeviceId: UUID, recipientPublicKey: Data,
                     sender: DeviceKeyPair, crypto: CryptoProvider) throws -> String {
        guard spaceKey.count == E2EEFormat.keyLength, sender.publicKey.count == E2EEFormat.publicKeyLength else { throw E2EEError.badFormat }
        let key = try wrappingKey(own: sender.privateKey, peer: recipientPublicKey, spaceId: spaceId, crypto: crypto)
        let sealed = try crypto.seal(spaceKey, key: key, associatedData: deviceAD(spaceId: spaceId, deviceId: recipientDeviceId))
        var blob = Data([E2EEFormat.deviceWrapVersion])
        blob.append(sender.publicKey)
        blob.append(sealed)
        return blob.base64EncodedString()
    }

    /// Abre una llave envuelta para este dispositivo. Si `trustedSenders` no es nil, la pública del que la
    /// envolvió tiene que estar ahí (los dispositivos de la cuenta); si no, se rechaza.
    static func unwrap(_ text: String, spaceId: UUID, recipientDeviceId: UUID, recipient: DeviceKeyPair,
                       trustedSenders: Set<Data>? = nil, crypto: CryptoProvider) throws -> (spaceKey: Data, senderPublicKey: Data) {
        guard let blob = Data(base64Encoded: text), blob.count > 1 + E2EEFormat.publicKeyLength,
              blob.first == E2EEFormat.deviceWrapVersion else { throw E2EEError.badFormat }
        let senderKey = Data(blob[blob.startIndex + 1 ..< blob.startIndex + 1 + E2EEFormat.publicKeyLength])
        if let trustedSenders, !trustedSenders.contains(senderKey) { throw E2EEError.untrustedSender }
        let sealed = Data(blob[(blob.startIndex + 1 + E2EEFormat.publicKeyLength)...])
        let key = try wrappingKey(own: recipient.privateKey, peer: senderKey, spaceId: spaceId, crypto: crypto)
        do {
            let spaceKey = try crypto.open(sealed, key: key, associatedData: deviceAD(spaceId: spaceId, deviceId: recipientDeviceId))
            guard spaceKey.count == E2EEFormat.keyLength else { throw E2EEError.badFormat }
            return (spaceKey, senderKey)
        } catch let error as E2EEError {
            throw error
        } catch {
            throw E2EEError.cannotOpen
        }
    }

    /// Envuelve la llave con el código de recuperación: AES-GCM con la llave del código y datos asociados
    /// "espacio|recuperacion". Resultado en base64: 0x02 | AES-GCM combinado.
    static func wrapForRecovery(_ spaceKey: Data, spaceId: UUID, recoveryKey: Data, crypto: CryptoProvider) throws -> String {
        guard spaceKey.count == E2EEFormat.keyLength else { throw E2EEError.badFormat }
        var blob = Data([E2EEFormat.recoveryWrapVersion])
        blob.append(try crypto.seal(spaceKey, key: recoveryKey, associatedData: recoveryAD(spaceId: spaceId)))
        return blob.base64EncodedString()
    }

    static func unwrapWithRecovery(_ text: String, spaceId: UUID, recoveryKey: Data, crypto: CryptoProvider) throws -> Data {
        guard let blob = Data(base64Encoded: text), blob.count > 1, blob.first == E2EEFormat.recoveryWrapVersion else {
            throw E2EEError.badFormat
        }
        do {
            let spaceKey = try crypto.open(Data(blob.dropFirst()), key: recoveryKey, associatedData: recoveryAD(spaceId: spaceId))
            guard spaceKey.count == E2EEFormat.keyLength else { throw E2EEError.badFormat }
            return spaceKey
        } catch {
            throw E2EEError.badRecoveryCode
        }
    }

    private static func wrappingKey(own: Data, peer: Data, spaceId: UUID, crypto: CryptoProvider) throws -> Data {
        guard peer.count == E2EEFormat.publicKeyLength else { throw E2EEError.badFormat }
        let shared = try crypto.sharedSecret(privateKey: own, peerPublicKey: peer)
        return crypto.hkdf(inputKeyMaterial: shared, salt: E2EEFormat.data(E2EEFormat.id(spaceId)),
                           info: E2EEFormat.spaceKeyInfo, outputByteCount: E2EEFormat.keyLength)
    }

    static func deviceAD(spaceId: UUID, deviceId: UUID) -> Data {
        E2EEFormat.data("\(E2EEFormat.id(spaceId))|\(E2EEFormat.id(deviceId))")
    }

    static func recoveryAD(spaceId: UUID) -> Data {
        E2EEFormat.data("\(E2EEFormat.id(spaceId))|recuperacion")
    }
}

/// Código de recuperación: 24 caracteres en grupos de 4, base32 sin caracteres que se confunden
/// (sin 0, O, 1 ni I). Son 120 bits al azar.
enum RecoveryCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 24
    static let groupSize = 4

    /// Código nuevo, ya con guiones: "K7QM-3XHD-...".
    static func generate(crypto: CryptoProvider) -> String {
        format(encode(crypto.randomBytes(length * 5 / 8)))
    }

    /// Base32 de 15 bytes: 24 caracteres.
    static func encode(_ bytes: Data) -> String {
        var result = ""
        var buffer: UInt32 = 0
        var bits = 0
        for byte in bytes {
            buffer = (buffer << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                result.append(alphabet[Int((buffer >> UInt32(bits)) & 31)])
            }
        }
        if bits > 0 { result.append(alphabet[Int((buffer << UInt32(5 - bits)) & 31)]) }
        return result
    }

    /// "ABCDEFGH..." en grupos de 4 con guiones.
    static func format(_ code: String) -> String {
        var groups: [String] = []
        var current = ""
        for character in code {
            current.append(character)
            if current.count == groupSize {
                groups.append(current)
                current = ""
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups.joined(separator: "-")
    }

    /// Lo que escribió la persona, limpio: mayúsculas, sin espacios ni guiones. Nil si no es un código válido.
    static func normalize(_ input: String) -> String? {
        let clean = input.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard clean.count == length, clean.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return clean
    }

    /// Llave de 32 bytes que sale del código: HKDF-SHA256(código limpio, sal "mprogress-recovery",
    /// info "mprogress-recovery-key"). El mismo código da siempre la misma llave.
    static func key(_ input: String, crypto: CryptoProvider) throws -> Data {
        guard let code = normalize(input) else { throw E2EEError.badRecoveryCode }
        return crypto.hkdf(inputKeyMaterial: E2EEFormat.data(code), salt: E2EEFormat.recoverySalt,
                           info: E2EEFormat.recoveryInfo, outputByteCount: E2EEFormat.keyLength)
    }
}

/// Sobre de un registro: AES-GCM(JSON) con datos asociados "espacio|entidad|id", en base64.
/// Si alguien cambia el espacio, el tipo o el id del sobre en el servidor, no abre.
enum Envelope {
    static func seal(_ payload: Data, spaceId: UUID, entity: String, id: UUID, key: Data, crypto: CryptoProvider) throws -> String {
        try crypto.seal(payload, key: key, associatedData: ad(spaceId: spaceId, entity: entity, id: id)).base64EncodedString()
    }

    static func open(_ text: String, spaceId: UUID, entity: String, id: UUID, key: Data, crypto: CryptoProvider) throws -> Data {
        guard let combined = Data(base64Encoded: text) else { throw E2EEError.badFormat }
        do {
            return try crypto.open(combined, key: key, associatedData: ad(spaceId: spaceId, entity: entity, id: id))
        } catch {
            throw E2EEError.cannotOpen
        }
    }

    static func ad(spaceId: UUID, entity: String, id: UUID) -> Data {
        E2EEFormat.data("\(E2EEFormat.id(spaceId))|\(entity)|\(E2EEFormat.id(id))")
    }
}

/// PKCE para el enlace mágico de Supabase Auth: verificador al azar y su reto S256.
enum PKCE {
    /// 64 caracteres base64url sin relleno (48 bytes al azar). RFC 7636 pide de 43 a 128.
    static func newVerifier(crypto: CryptoProvider) -> String {
        base64URL(crypto.randomBytes(48))
    }

    /// Reto S256: base64url(SHA-256(verificador)).
    static func challenge(for verifier: String, crypto: CryptoProvider) -> String {
        base64URL(crypto.sha256(Data(verifier.utf8)))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
