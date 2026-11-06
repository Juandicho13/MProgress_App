import Foundation
import CryptoKit

/// Primitivas reales del cifrado de extremo a extremo (docs/PLAN_F10.md) con CryptoKit:
/// Curve25519 (X25519), HKDF-SHA256, AES-256-GCM y SHA-256. La lógica y el formato están en Domain/E2EE.swift.
struct CryptoKitProvider: CryptoProvider {
    struct InvalidSealedBox: Error {}

    func randomBytes(_ count: Int) -> Data {
        // SymmetricKey usa el generador seguro del sistema.
        var data = Data()
        while data.count < count {
            let chunk = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            data.append(chunk)
        }
        return data.prefix(count)
    }

    func newAgreementKeyPair() -> DeviceKeyPair {
        let key = Curve25519.KeyAgreement.PrivateKey()
        return DeviceKeyPair(privateKey: key.rawRepresentation, publicKey: key.publicKey.rawRepresentation)
    }

    func sharedSecret(privateKey: Data, peerPublicKey: Data) throws -> Data {
        let own = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let secret = try own.sharedSecretFromKeyAgreement(with: peer)
        return secret.withUnsafeBytes { Data($0) }
    }

    func hkdf(inputKeyMaterial: Data, salt: Data, info: Data, outputByteCount: Int) -> Data {
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: inputKeyMaterial), salt: salt, info: info,
                                         outputByteCount: outputByteCount)
        return key.withUnsafeBytes { Data($0) }
    }

    func seal(_ plaintext: Data, key: Data, associatedData: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: associatedData)
        guard let combined = box.combined else { throw InvalidSealedBox() }
        return combined
    }

    func open(_ combined: Data, key: Data, associatedData: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: associatedData)
    }

    func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}
