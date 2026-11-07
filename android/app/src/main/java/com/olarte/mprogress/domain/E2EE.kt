package com.olarte.mprogress.domain

import java.util.Base64

// Cifrado de extremo a extremo (docs/PLAN_F10.md). Es el mismo formato de ios/MProgress/Domain/E2EE.swift, byte por byte:
// aquí va solo la lógica; las primitivas (X25519, HKDF-SHA256, AES-GCM, SHA-256) entran por CryptoProvider.

/** Primitivas criptográficas. Las llaves y los textos van como bytes crudos. */
interface CryptoProvider {
    fun randomBytes(count: Int): ByteArray
    /** Par X25519: privada y pública de 32 bytes. */
    fun newAgreementKeyPair(): DeviceKeyPair
    /** Secreto compartido X25519 (32 bytes). */
    fun sharedSecret(privateKey: ByteArray, peerPublicKey: ByteArray): ByteArray
    fun hkdf(inputKeyMaterial: ByteArray, salt: ByteArray, info: ByteArray, outputByteCount: Int): ByteArray
    /** AES-256-GCM en formato combinado: nonce (12) | texto cifrado | etiqueta (16). */
    fun seal(plaintext: ByteArray, key: ByteArray, associatedData: ByteArray): ByteArray
    fun open(combined: ByteArray, key: ByteArray, associatedData: ByteArray): ByteArray
    fun sha256(data: ByteArray): ByteArray
}

/** Llaves X25519 de un dispositivo. La privada vive en el almacén seguro y nunca sale del teléfono. */
class DeviceKeyPair(val privateKey: ByteArray, val publicKey: ByteArray) {
    override fun equals(other: Any?) = other is DeviceKeyPair && privateKey.contentEquals(other.privateKey) && publicKey.contentEquals(other.publicKey)
    override fun hashCode() = publicKey.contentHashCode()
}

/** Errores del cifrado con el mismo texto de iOS. */
sealed class E2EEError(message: String) : Exception(message) {
    class BadFormat : E2EEError("El dato cifrado no tiene el formato esperado.")
    class CannotOpen : E2EEError("No se pudo descifrar: la llave no corresponde o el dato cambió.")
    class UntrustedSender : E2EEError("La llave la envió un dispositivo que no es de tu cuenta.")
    class BadRecoveryCode : E2EEError("Ese código de recuperación no es válido. Son 24 letras y números en grupos de 4.")
    class MissingKey : E2EEError("Este dispositivo todavía no tiene la llave de tus datos.")
}

/**
 * Textos que se usan como datos asociados y para derivar llaves. Los UUID van en minúscula (como los devuelve Postgres),
 * así iOS y Android producen exactamente los mismos bytes.
 */
object E2EEFormat {
    val spaceKeyInfo = "mprogress-space-key".toByteArray(Charsets.UTF_8)
    val recoverySalt = "mprogress-recovery".toByteArray(Charsets.UTF_8)
    val recoveryInfo = "mprogress-recovery-key".toByteArray(Charsets.UTF_8)
    /** Primer byte de una llave envuelta para un dispositivo. */
    const val DEVICE_WRAP_VERSION: Byte = 1
    /** Primer byte de una llave envuelta con el código de recuperación. */
    const val RECOVERY_WRAP_VERSION: Byte = 2
    const val PUBLIC_KEY_LENGTH = 32
    const val KEY_LENGTH = 32

    fun id(uuid: String) = uuid.lowercase()
    fun data(text: String) = text.toByteArray(Charsets.UTF_8)
    /** Base64 estándar con relleno, como `base64EncodedString()` de iOS. */
    fun b64(bytes: ByteArray): String = Base64.getEncoder().encodeToString(bytes)
    /** Base64 estándar estricto, como `Data(base64Encoded:)`: nil si no es válido. */
    fun unb64(text: String): ByteArray? = try { Base64.getDecoder().decode(text) } catch (e: IllegalArgumentException) { null }
}

/** La llave del espacio (256 bits, AES-GCM) envuelta para cada dispositivo o para el código de recuperación. */
object SpaceKeyWrap {
    class Opened(val spaceKey: ByteArray, val senderPublicKey: ByteArray)

    fun newSpaceKey(crypto: CryptoProvider) = crypto.randomBytes(E2EEFormat.KEY_LENGTH)

    /**
     * Envuelve la llave para otro dispositivo (o para sí mismo): X25519(privada del que comparte, pública del que recibe) →
     * HKDF-SHA256(sal = id del espacio, info = "mprogress-space-key") → AES-GCM con datos asociados "espacio|dispositivo".
     * Resultado en base64: 0x01 | pública del que comparte (32) | AES-GCM combinado.
     */
    fun wrap(spaceKey: ByteArray, spaceId: String, recipientDeviceId: String, recipientPublicKey: ByteArray, sender: DeviceKeyPair, crypto: CryptoProvider): String {
        if (spaceKey.size != E2EEFormat.KEY_LENGTH || sender.publicKey.size != E2EEFormat.PUBLIC_KEY_LENGTH) throw E2EEError.BadFormat()
        val key = wrappingKey(sender.privateKey, recipientPublicKey, spaceId, crypto)
        val sealed = crypto.seal(spaceKey, key, deviceAD(spaceId, recipientDeviceId))
        return E2EEFormat.b64(byteArrayOf(E2EEFormat.DEVICE_WRAP_VERSION) + sender.publicKey + sealed)
    }

    /** Abre una llave envuelta para este dispositivo. Si `trustedSenders` no es null, la pública del que la envolvió tiene que estar ahí. */
    fun unwrap(text: String, spaceId: String, recipientDeviceId: String, recipient: DeviceKeyPair, trustedSenders: List<ByteArray>? = null,
               crypto: CryptoProvider): Opened {
        val blob = E2EEFormat.unb64(text)
        if (blob == null || blob.size <= 1 + E2EEFormat.PUBLIC_KEY_LENGTH || blob[0] != E2EEFormat.DEVICE_WRAP_VERSION) throw E2EEError.BadFormat()
        val senderKey = blob.copyOfRange(1, 1 + E2EEFormat.PUBLIC_KEY_LENGTH)
        if (trustedSenders != null && trustedSenders.none { it.contentEquals(senderKey) }) throw E2EEError.UntrustedSender()
        val sealed = blob.copyOfRange(1 + E2EEFormat.PUBLIC_KEY_LENGTH, blob.size)
        val key = wrappingKey(recipient.privateKey, senderKey, spaceId, crypto)
        val spaceKey = try { crypto.open(sealed, key, deviceAD(spaceId, recipientDeviceId)) } catch (e: E2EEError) { throw e } catch (e: Exception) { throw E2EEError.CannotOpen() }
        if (spaceKey.size != E2EEFormat.KEY_LENGTH) throw E2EEError.BadFormat()
        return Opened(spaceKey, senderKey)
    }

    /** Envuelve la llave con el código de recuperación. Resultado en base64: 0x02 | AES-GCM combinado ("espacio|recuperacion"). */
    fun wrapForRecovery(spaceKey: ByteArray, spaceId: String, recoveryKey: ByteArray, crypto: CryptoProvider): String {
        if (spaceKey.size != E2EEFormat.KEY_LENGTH) throw E2EEError.BadFormat()
        return E2EEFormat.b64(byteArrayOf(E2EEFormat.RECOVERY_WRAP_VERSION) + crypto.seal(spaceKey, recoveryKey, recoveryAD(spaceId)))
    }

    fun unwrapWithRecovery(text: String, spaceId: String, recoveryKey: ByteArray, crypto: CryptoProvider): ByteArray {
        val blob = E2EEFormat.unb64(text)
        if (blob == null || blob.size <= 1 || blob[0] != E2EEFormat.RECOVERY_WRAP_VERSION) throw E2EEError.BadFormat()
        val spaceKey = try { crypto.open(blob.copyOfRange(1, blob.size), recoveryKey, recoveryAD(spaceId)) } catch (e: Exception) { throw E2EEError.BadRecoveryCode() }
        if (spaceKey.size != E2EEFormat.KEY_LENGTH) throw E2EEError.BadRecoveryCode()
        return spaceKey
    }

    private fun wrappingKey(own: ByteArray, peer: ByteArray, spaceId: String, crypto: CryptoProvider): ByteArray {
        if (peer.size != E2EEFormat.PUBLIC_KEY_LENGTH) throw E2EEError.BadFormat()
        val shared = try { crypto.sharedSecret(own, peer) } catch (e: Exception) { throw E2EEError.BadFormat() }
        return crypto.hkdf(shared, E2EEFormat.data(E2EEFormat.id(spaceId)), E2EEFormat.spaceKeyInfo, E2EEFormat.KEY_LENGTH)
    }

    fun deviceAD(spaceId: String, deviceId: String) = E2EEFormat.data("${E2EEFormat.id(spaceId)}|${E2EEFormat.id(deviceId)}")
    fun recoveryAD(spaceId: String) = E2EEFormat.data("${E2EEFormat.id(spaceId)}|recuperacion")
}

/** Código de recuperación: 24 caracteres en grupos de 4, base32 sin caracteres que se confunden (sin 0, O, 1 ni I). 120 bits al azar. */
object RecoveryCode {
    const val ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    const val LENGTH = 24
    const val GROUP_SIZE = 4

    /** Código nuevo, ya con guiones: "K7QM-3XHD-...". */
    fun generate(crypto: CryptoProvider) = format(encode(crypto.randomBytes(LENGTH * 5 / 8)))

    /** Base32 de 15 bytes: 24 caracteres. */
    fun encode(bytes: ByteArray): String {
        val result = StringBuilder()
        var buffer = 0L
        var bits = 0
        for (byte in bytes) {
            buffer = ((buffer shl 8) or (byte.toLong() and 0xFF)) and 0xFFFFFFFFL
            bits += 8
            while (bits >= 5) {
                bits -= 5
                result.append(ALPHABET[((buffer shr bits) and 31).toInt()])
            }
        }
        if (bits > 0) result.append(ALPHABET[((buffer shl (5 - bits)) and 31).toInt()])
        return result.toString()
    }

    /** "ABCDEFGH..." en grupos de 4 con guiones. */
    fun format(code: String) = code.chunked(GROUP_SIZE).joinToString("-")

    /** Lo que escribió la persona, limpio: mayúsculas, sin espacios ni guiones. Null si no es un código válido. */
    fun normalize(input: String): String? {
        val clean = input.uppercase().filter { !it.isWhitespace() && it != '-' }
        return clean.takeIf { it.length == LENGTH && it.all { c -> c in ALPHABET } }
    }

    /** Llave de 32 bytes del código: HKDF-SHA256(código limpio, sal "mprogress-recovery", info "mprogress-recovery-key"). */
    fun key(input: String, crypto: CryptoProvider): ByteArray {
        val code = normalize(input) ?: throw E2EEError.BadRecoveryCode()
        return crypto.hkdf(E2EEFormat.data(code), E2EEFormat.recoverySalt, E2EEFormat.recoveryInfo, E2EEFormat.KEY_LENGTH)
    }
}

/** Sobre de un registro: AES-GCM(JSON) con datos asociados "espacio|entidad|id", en base64. */
object Envelope {
    fun seal(payload: ByteArray, spaceId: String, entity: String, id: String, key: ByteArray, crypto: CryptoProvider): String =
        E2EEFormat.b64(crypto.seal(payload, key, ad(spaceId, entity, id)))

    fun open(text: String, spaceId: String, entity: String, id: String, key: ByteArray, crypto: CryptoProvider): ByteArray {
        val combined = E2EEFormat.unb64(text) ?: throw E2EEError.BadFormat()
        return try { crypto.open(combined, key, ad(spaceId, entity, id)) } catch (e: Exception) { throw E2EEError.CannotOpen() }
    }

    fun ad(spaceId: String, entity: String, id: String) = E2EEFormat.data("${E2EEFormat.id(spaceId)}|$entity|${E2EEFormat.id(id)}")
}

/** PKCE para el enlace mágico de Supabase Auth: verificador al azar y su reto S256. */
object PKCE {
    /** 64 caracteres base64url sin relleno (48 bytes al azar). */
    fun newVerifier(crypto: CryptoProvider) = base64URL(crypto.randomBytes(48))

    /** Reto S256: base64url(SHA-256(verificador)). */
    fun challenge(verifier: String, crypto: CryptoProvider) = base64URL(crypto.sha256(verifier.toByteArray(Charsets.UTF_8)))

    fun base64URL(data: ByteArray): String = Base64.getUrlEncoder().withoutPadding().encodeToString(data)
}
