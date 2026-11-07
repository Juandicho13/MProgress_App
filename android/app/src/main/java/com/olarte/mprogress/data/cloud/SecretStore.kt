package com.olarte.mprogress.data.cloud

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Secretos de la cuenta (F10): sesión, llaves del dispositivo, llaves de los espacios y el verificador PKCE. */
interface SecretStore {
    fun read(name: String): ByteArray?
    fun write(name: String, data: ByteArray)
    fun delete(name: String)
    fun names(): List<String>

    fun readText(name: String) = read(name)?.toString(Charsets.UTF_8)
    fun writeText(name: String, text: String) = write(name, text.toByteArray(Charsets.UTF_8))

    companion object {
        const val SESSION = "sesion"
        const val DEVICE_KEY = "llave-dispositivo"
        const val DEVICE_ID = "id-dispositivo"
        const val PKCE = "pkce"
        const val PENDING_EMAIL = "correo-pendiente"
        const val SPACE_KEY_PREFIX = "llave-espacio."
        fun spaceKey(spaceId: String) = SPACE_KEY_PREFIX + spaceId.lowercase()
    }
}

/**
 * Cada secreto es un archivo privado de la app cifrado con AES-256-GCM, con una llave que vive en el Android Keystore y nunca sale
 * de él (igual que el llavero del iPhone con "solo este dispositivo"). Los archivos no entran en copias de seguridad
 * (allowBackup=false en el manifiesto).
 */
class KeystoreSecretStore(context: Context) : SecretStore {
    private val folder = File(context.noBackupFilesDir, "nube").apply { mkdirs() }

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
        return gen.generateKey()
    }

    private fun file(name: String) = File(folder, name.replace(Regex("[^a-zA-Z0-9._-]"), "_") + ".bin")

    @Synchronized override fun read(name: String): ByteArray? {
        val f = file(name)
        if (!f.exists()) return null
        return runCatching {
            val bytes = f.readBytes()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes, 0, 12)) }
            cipher.updateAAD(name.toByteArray())
            cipher.doFinal(bytes, 12, bytes.size - 12)
        }.getOrNull()
    }

    @Synchronized override fun write(name: String, data: ByteArray) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        cipher.updateAAD(name.toByteArray())
        val out = cipher.iv + cipher.doFinal(data)
        val tmp = File(folder, file(name).name + ".tmp")
        tmp.writeBytes(out)
        tmp.renameTo(file(name))
    }

    @Synchronized override fun delete(name: String) { file(name).delete() }

    override fun names(): List<String> = folder.listFiles()?.filter { it.name.endsWith(".bin") }?.map { it.name.removeSuffix(".bin") } ?: emptyList()

    private companion object { const val ALIAS = "mprogress.nube" }
}

/** En memoria, para las pruebas y las capturas (Robolectric no tiene Android Keystore). */
class MemorySecretStore : SecretStore {
    private val map = mutableMapOf<String, ByteArray>()
    override fun read(name: String) = map[name]
    override fun write(name: String, data: ByteArray) { map[name] = data }
    override fun delete(name: String) { map.remove(name) }
    override fun names() = map.keys.toList()
}
