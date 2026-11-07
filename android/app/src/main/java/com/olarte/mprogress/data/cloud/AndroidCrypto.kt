package com.olarte.mprogress.data.cloud

import com.google.crypto.tink.subtle.X25519
import com.olarte.mprogress.domain.CryptoProvider
import com.olarte.mprogress.domain.DeviceKeyPair
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Primitivas reales de F10 en Android, equivalentes a CryptoKitProvider de iOS: X25519 de Tink (minSdk 26 no lo trae),
 * HKDF-SHA256 (RFC 5869) con HmacSHA256, AES-256-GCM y SHA-256 del sistema. `random` se cambia solo en las pruebas,
 * para comparar byte por byte con los vectores hechos desde el algoritmo de iOS.
 */
class AndroidCrypto(private val random: (Int) -> ByteArray = { n -> ByteArray(n).also { secure.nextBytes(it) } }) : CryptoProvider {
    override fun randomBytes(count: Int) = random(count)

    override fun newAgreementKeyPair(): DeviceKeyPair {
        val privateKey = X25519.generatePrivateKey()
        return DeviceKeyPair(privateKey, X25519.publicFromPrivate(privateKey))
    }

    fun publicKey(privateKey: ByteArray): ByteArray = X25519.publicFromPrivate(privateKey)

    override fun sharedSecret(privateKey: ByteArray, peerPublicKey: ByteArray): ByteArray = X25519.computeSharedSecret(privateKey, peerPublicKey)

    override fun hkdf(inputKeyMaterial: ByteArray, salt: ByteArray, info: ByteArray, outputByteCount: Int): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        // Extraer. Una sal vacía es 32 ceros (RFC 5869), igual que CryptoKit.
        mac.init(SecretKeySpec(if (salt.isEmpty()) ByteArray(32) else salt, "HmacSHA256"))
        val prk = mac.doFinal(inputKeyMaterial)
        // Expandir.
        mac.init(SecretKeySpec(prk, "HmacSHA256"))
        val out = ByteArray(outputByteCount)
        var previous = ByteArray(0)
        var offset = 0
        var counter = 1
        while (offset < outputByteCount) {
            mac.update(previous); mac.update(info); mac.update(counter.toByte())
            previous = mac.doFinal()
            val n = minOf(previous.size, outputByteCount - offset)
            System.arraycopy(previous, 0, out, offset, n)
            offset += n; counter++
        }
        return out
    }

    override fun seal(plaintext: ByteArray, key: ByteArray, associatedData: ByteArray): ByteArray {
        val nonce = random(12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        cipher.updateAAD(associatedData)
        // doFinal devuelve cifrado | etiqueta: con el nonce delante queda el formato combinado de CryptoKit.
        return nonce + cipher.doFinal(plaintext)
    }

    override fun open(combined: ByteArray, key: ByteArray, associatedData: ByteArray): ByteArray {
        require(combined.size >= 12 + 16) { "Dato cifrado muy corto" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, combined, 0, 12))
        cipher.updateAAD(associatedData)
        return cipher.doFinal(combined, 12, combined.size - 12)
    }

    override fun sha256(data: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(data)

    companion object { private val secure = SecureRandom() }
}
