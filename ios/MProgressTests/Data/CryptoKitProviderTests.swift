import Foundation
import Testing
@testable import MProgress

/// Las mismas reglas de Domain/E2EE.swift, ahora con CryptoKit de verdad (solo corre en Xcode).
struct CryptoKitProviderTests {
    let crypto = CryptoKitProvider()
    let space = UUID()
    let device = UUID()

    @Test("X25519 + HKDF + AES-GCM: envolver y desenvolver la llave del espacio")
    func envolver() throws {
        let alice = crypto.newAgreementKeyPair()
        let bob = crypto.newAgreementKeyPair()
        #expect(alice.publicKey.count == 32)
        #expect(try crypto.sharedSecret(privateKey: alice.privateKey, peerPublicKey: bob.publicKey)
                == crypto.sharedSecret(privateKey: bob.privateKey, peerPublicKey: alice.publicKey))
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let wrapped = try SpaceKeyWrap.wrap(key, spaceId: space, recipientDeviceId: device, recipientPublicKey: bob.publicKey,
                                            sender: alice, crypto: crypto)
        let opened = try SpaceKeyWrap.unwrap(wrapped, spaceId: space, recipientDeviceId: device, recipient: bob,
                                             trustedSenders: [alice.publicKey], crypto: crypto)
        #expect(opened.spaceKey == key)
        #expect(throws: E2EEError.cannotOpen) {
            try SpaceKeyWrap.unwrap(wrapped, spaceId: space, recipientDeviceId: device, recipient: crypto.newAgreementKeyPair(), crypto: crypto)
        }
    }

    @Test("Sobre con AES-GCM: abre igual y falla si cambia el id")
    func sobre() throws {
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let id = UUID()
        let json = Data(#"{"name":"Mercado"}"#.utf8)
        let sealed = try Envelope.seal(json, spaceId: space, entity: "entries", id: id, key: key, crypto: crypto)
        #expect(try Envelope.open(sealed, spaceId: space, entity: "entries", id: id, key: key, crypto: crypto) == json)
        #expect(throws: E2EEError.cannotOpen) { try Envelope.open(sealed, spaceId: space, entity: "entries", id: UUID(), key: key, crypto: crypto) }
    }

    @Test("Código de recuperación y PKCE con SHA-256 de verdad")
    func codigoYPKCE() throws {
        let code = RecoveryCode.generate(crypto: crypto)
        let key = SpaceKeyWrap.newSpaceKey(crypto: crypto)
        let wrapped = try SpaceKeyWrap.wrapForRecovery(key, spaceId: space, recoveryKey: RecoveryCode.key(code, crypto: crypto), crypto: crypto)
        #expect(try SpaceKeyWrap.unwrapWithRecovery(wrapped, spaceId: space, recoveryKey: RecoveryCode.key(code, crypto: crypto), crypto: crypto) == key)
        // Ejemplo del RFC 7636, apéndice B.
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", crypto: crypto) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(crypto.randomBytes(15).count == 15)
        #expect(crypto.randomBytes(48).count == 48)
    }
}
