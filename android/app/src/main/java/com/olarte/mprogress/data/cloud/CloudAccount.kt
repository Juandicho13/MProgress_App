package com.olarte.mprogress.data.cloud

import android.content.Context
import com.olarte.mprogress.data.LedgerSyncStore
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.CryptoProvider
import com.olarte.mprogress.domain.DeviceKeyPair
import com.olarte.mprogress.domain.E2EEFormat
import com.olarte.mprogress.domain.EncryptedRemote
import com.olarte.mprogress.domain.PKCE
import com.olarte.mprogress.domain.RecoveryCode
import com.olarte.mprogress.domain.SpaceKeyWrap
import com.olarte.mprogress.domain.SyncEngine
import com.olarte.mprogress.domain.SyncStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.net.URLDecoder
import java.time.Instant
import java.util.UUID

/** En qué va la cuenta. */
sealed class CloudPhase {
    data object SignedOut : CloudPhase()
    data class LinkSent(val email: String) : CloudPhase()
    data object Connecting : CloudPhase()
    /** Ya hay otro dispositivo en la cuenta: este espera la aprobación o el código de recuperación. */
    data object NeedsApproval : CloudPhase()
    data object Ready : CloudPhase()
}

/** Todo lo que muestran Ajustes › Cuenta y nube, Inicio y los avisos. Las pantallas solo leen esto (y así salen en las capturas). */
data class CloudUi(
    val phase: CloudPhase = CloudPhase.SignedOut,
    val email: String? = null,
    val status: SyncStatus = SyncStatus.Sincronizado,
    val lastSyncAt: Instant? = null,
    val devices: List<RemoteDevice> = emptyList(),
    /** Dispositivos de la cuenta que todavía no tienen la llave. */
    val pendingApprovals: List<RemoteDevice> = emptyList(),
    val isWorking: Boolean = false,
    val errorText: String? = null,
    /** Código de recuperación recién creado, para mostrarlo una vez. */
    val recoveryCode: String? = null,
    /** Aviso "¿Apruebas tu otro dispositivo?" (una vez por dispositivo y por sesión). */
    val approvalPrompt: RemoteDevice? = null,
    val thisDeviceId: String = "",
) {
    val isSignedIn get() = phase != CloudPhase.SignedOut && phase !is CloudPhase.LinkSent
}

/**
 * Cuenta en la nube y sincronización cifrada (docs/PLAN_F10.md), como CloudAccount.swift. La app funciona igual sin cuenta.
 *
 * Al entrar: el espacio Personal de la nube (lo crea el servidor) pasa a ser el de los datos locales, este dispositivo se registra
 * con su llave pública y: si es el primero de la cuenta crea la llave del espacio, la envuelve para sí y para el código de
 * recuperación, y muestra el código; si ya hay otros, espera a que uno lo apruebe (o a que escriba el código).
 * Todo corre en el hilo principal; solo la red va en segundo plano.
 */
class CloudAccount(
    private val store: Store,
    private val secrets: SecretStore,
    private val crypto: CryptoProvider = AndroidCrypto(),
    private val deviceName: String = "Android",
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
    private val syncDelayMillis: Long = 3000,
) {
    private val _ui = MutableStateFlow(CloudUi())
    val ui: StateFlow<CloudUi> = _ui

    private var session: CloudSession? = null
    private var spaceId: String? = null
    private var isSyncing = false
    private var scheduled: Job? = null
    private val dismissedApprovals = mutableSetOf<String>()
    private val refreshLock = Mutex()

    private val api = CloudApi { validAccessToken() }

    private fun set(change: (CloudUi) -> CloudUi) { _ui.value = change(_ui.value) }

    /** Solo para las capturas: muestra un estado escrito a mano. */
    fun preview(ui: CloudUi) { _ui.value = ui }
    private fun error(text: String?) = set { it.copy(errorText = text) }
    private suspend fun <T> working(block: suspend () -> T): T {
        set { it.copy(isWorking = true) }
        try { return block() } finally { set { it.copy(isWorking = false) } }
    }

    // ---------- Arranque ----------

    /** Lee la sesión guardada. Si ya tenía la llave, queda lista sin esperar a la red. */
    fun start() {
        set { it.copy(thisDeviceId = deviceId()) }
        val saved = secrets.readText(SecretStore.SESSION)?.let(CloudSession::fromJson)
        if (saved == null) {
            secrets.readText(SecretStore.PENDING_EMAIL)?.takeIf { secrets.read(SecretStore.PKCE) != null }?.let { email -> set { it.copy(phase = CloudPhase.LinkSent(email)) } }
            return
        }
        session = saved
        val stored = store.prefs.getString(KEY_SPACE, null)
        if (stored != null && spaceKey(stored) != null) {
            spaceId = stored
            set { it.copy(phase = CloudPhase.Ready, email = saved.email, status = statusNow()) }
        } else set { it.copy(phase = CloudPhase.Connecting, email = saved.email) }
        scope.launch { connect() }
    }

    // ---------- Entrar ----------

    /** Paso 1: manda el enlace mágico al correo. */
    fun sendLink(raw: String) = scope.launch {
        val clean = raw.trim().lowercase()
        if (!clean.contains("@") || !clean.contains(".")) { error("Escribe un correo válido."); return@launch }
        working {
            val verifier = PKCE.newVerifier(crypto)
            try {
                AuthClient.sendMagicLink(clean, PKCE.challenge(verifier, crypto))
                secrets.writeText(SecretStore.PKCE, verifier)
                secrets.writeText(SecretStore.PENDING_EMAIL, clean)
                set { it.copy(phase = CloudPhase.LinkSent(clean), errorText = null) }
            } catch (e: Exception) { error(message(e)) }
        }
    }

    /**
     * Paso 2: el enlace del correo abre la app con `mprogress://auth-callback?code=...`.
     * Devuelve true si la dirección era del inicio de sesión.
     */
    fun handle(uri: String): Boolean {
        val params = callbackParams(uri) ?: return false
        // Ya entró con este enlace (se abrió dos veces): no hay nada que hacer.
        if (session != null && params["error_description"] == null) return true
        params["error_description"]?.let { error(it); return true }
        val code = params["code"]
        val verifier = secrets.readText(SecretStore.PKCE)
        if (code == null || verifier == null) { error(CloudError.LinkExpired().message); return true }
        scope.launch {
            working {
                try {
                    val newSession = AuthClient.exchange(code, verifier, secrets.readText(SecretStore.PENDING_EMAIL))
                    secrets.delete(SecretStore.PKCE)
                    save(newSession)
                    set { it.copy(phase = CloudPhase.Connecting, errorText = null) }
                } catch (e: Exception) { error(message(e)); return@working }
                connect()
            }
        }
        return true
    }

    fun cancelLink() {
        secrets.delete(SecretStore.PKCE)
        secrets.delete(SecretStore.PENDING_EMAIL)
        set { it.copy(phase = CloudPhase.SignedOut, errorText = null) }
    }

    // ---------- Conectar con el espacio y las llaves ----------

    /** Adopta el espacio de la nube, registra este dispositivo y consigue la llave del espacio. */
    suspend fun connect() {
        val current = session ?: return
        if (_ui.value.phase != CloudPhase.Ready) set { it.copy(phase = CloudPhase.Connecting) }
        try {
            val remoteSpace = api.personalSpaceId(current.userId)
            // Adoptar el espacio: si es otro (otra cuenta), todo lo local vuelve a quedar pendiente para subirlo.
            store.journal.resetForSpace(remoteSpace)
            spaceId = remoteSpace
            store.prefs.edit().putString(KEY_SPACE, remoteSpace).apply()

            val keys = deviceKeys()
            api.registerDevice(deviceId(), current.userId, keys.publicKey, deviceName)
            val wrapped = api.spaceKeys(remoteSpace)
            val devices = api.devices()
            set { it.copy(devices = devices) }
            val mine = wrapped.firstOrNull { it.deviceId == deviceId() }
            when {
                mine != null -> {
                    if (spaceKey(remoteSpace) == null) {
                        val trusted = devices.mapNotNull { it.publicKeyData }
                        val opened = SpaceKeyWrap.unwrap(mine.wrappedKey, remoteSpace, deviceId(), keys, trusted, crypto)
                        storeSpaceKey(opened.spaceKey, remoteSpace)
                    }
                    set { it.copy(phase = CloudPhase.Ready) }
                }
                wrapped.isEmpty() -> {
                    // Primer dispositivo de la cuenta: crea la llave y el código de recuperación.
                    val spaceKey = SpaceKeyWrap.newSpaceKey(crypto)
                    val forMe = SpaceKeyWrap.wrap(spaceKey, remoteSpace, deviceId(), keys.publicKey, keys, crypto)
                    val code = RecoveryCode.generate(crypto)
                    val forRecovery = SpaceKeyWrap.wrapForRecovery(spaceKey, remoteSpace, RecoveryCode.key(code, crypto), crypto)
                    api.addSpaceKey(remoteSpace, deviceId(), forMe)
                    api.addSpaceKey(remoteSpace, null, forRecovery)
                    storeSpaceKey(spaceKey, remoteSpace)
                    set { it.copy(phase = CloudPhase.Ready, recoveryCode = code) }
                }
                else -> {
                    // Hay otros dispositivos: si este tenía una llave que ya no está en la nube, se quita.
                    secrets.delete(SecretStore.spaceKey(remoteSpace))
                    set { it.copy(phase = CloudPhase.NeedsApproval) }
                }
            }
            error(null)
            if (_ui.value.phase == CloudPhase.Ready) sync()
        } catch (e: CloudError.NotSignedIn) {
            forgetSession()
            error(e.message)
        } catch (e: Exception) {
            // Sin conexión con la llave ya guardada se sigue trabajando; al volver la red se sincroniza.
            val space = spaceId
            if (space != null && spaceKey(space) != null) set { it.copy(phase = CloudPhase.Ready) }
            set { it.copy(status = if (e is CloudError.Offline) SyncStatus.SinConexion(pendingCount()) else SyncStatus.Error(message(e)), errorText = message(e)) }
        }
    }

    /** "Ya lo aprobé": vuelve a buscar la llave. */
    fun checkApproval() = scope.launch {
        working { connect() }
        if (_ui.value.phase == CloudPhase.NeedsApproval) error("Todavía no llega la aprobación. Ábrela en tu otro teléfono: Ajustes › Cuenta y nube › Dispositivos.")
    }

    /** Recuperar las llaves con el código en un dispositivo nuevo. `done` recibe true si funcionó. */
    fun useRecoveryCode(text: String, done: (Boolean) -> Unit = {}) = scope.launch {
        val space = spaceId ?: run { done(false); return@launch }
        val ok = working {
            try {
                val recoveryKey = RecoveryCode.key(text, crypto)
                val row = api.spaceKeys(space).firstOrNull { it.deviceId == null }
                if (row == null) {
                    error("Tu cuenta no tiene código de recuperación. Aprueba este teléfono desde tu otro dispositivo.")
                    return@working false
                }
                val spaceKey = SpaceKeyWrap.unwrapWithRecovery(row.wrappedKey, space, recoveryKey, crypto)
                val keys = deviceKeys()
                api.addSpaceKey(space, deviceId(), SpaceKeyWrap.wrap(spaceKey, space, deviceId(), keys.publicKey, keys, crypto))
                storeSpaceKey(spaceKey, space)
                set { it.copy(phase = CloudPhase.Ready, errorText = null) }
                true
            } catch (e: Exception) { error(message(e)); false }
        }
        done(ok)
        if (ok) sync()
    }

    /** Cambia el código de recuperación: el anterior deja de servir. */
    fun newRecoveryCode() = scope.launch {
        val space = spaceId ?: return@launch
        val key = spaceKey(space) ?: return@launch
        working {
            try {
                val code = RecoveryCode.generate(crypto)
                val wrapped = SpaceKeyWrap.wrapForRecovery(key, space, RecoveryCode.key(code, crypto), crypto)
                api.deleteRecoveryKey(space)
                api.addSpaceKey(space, null, wrapped)
                set { it.copy(recoveryCode = code, errorText = null) }
            } catch (e: Exception) { error(message(e)) }
        }
    }

    /** "Ya lo guardé". */
    fun dismissRecoveryCode() = set { it.copy(recoveryCode = null) }

    // ---------- Dispositivos ----------

    fun refreshDevices() = scope.launch { refreshDevicesNow() }

    private suspend fun refreshDevicesNow() {
        val space = spaceId ?: return
        if (_ui.value.phase != CloudPhase.Ready) return
        try {
            val devices = api.devices()
            val withKey = api.spaceKeys(space).mapNotNull { it.deviceId }.toSet()
            val waiting = devices.filter { it.id != deviceId() && it.id !in withKey && it.publicKeyData != null }
            set { ui ->
                val prompt = ui.approvalPrompt ?: waiting.firstOrNull { it.id !in dismissedApprovals }
                ui.copy(devices = devices, pendingApprovals = waiting, approvalPrompt = prompt)
            }
        } catch (e: Exception) {
            // Se reintenta en la próxima sincronización.
        }
    }

    /** Le envuelve la llave del espacio al otro dispositivo: con eso ya puede leer los datos. */
    fun approve(device: RemoteDevice) = scope.launch {
        val space = spaceId ?: return@launch
        val key = spaceKey(space) ?: return@launch
        val publicKey = device.publicKeyData ?: return@launch
        working {
            try {
                api.addSpaceKey(space, device.id, SpaceKeyWrap.wrap(key, space, device.id, publicKey, deviceKeys(), crypto))
                dismissedApprovals += device.id
                set { it.copy(approvalPrompt = null) }
                refreshDevicesNow()
            } catch (e: Exception) { error(message(e)) }
        }
    }

    fun dismissApproval(device: RemoteDevice) {
        dismissedApprovals += device.id
        set { it.copy(approvalPrompt = null) }
    }

    /** Quita un dispositivo de la cuenta (y su llave). */
    fun remove(device: RemoteDevice) = scope.launch {
        working {
            try { api.deleteDevice(device.id); refreshDevicesNow() } catch (e: Exception) { error(message(e)) }
        }
    }

    // ---------- Sincronizar ----------

    /** Al abrir, al volver a primer plano, después de guardar (con retraso), al volver el internet y con "Sincronizar ahora". */
    fun syncNow() = scope.launch { sync() }

    suspend fun sync() {
        val space = spaceId ?: return
        val current = session ?: return
        if (_ui.value.phase != CloudPhase.Ready || isSyncing) return
        val key = spaceKey(space) ?: return
        isSyncing = true
        set { it.copy(status = SyncStatus.Sincronizando) }
        val local = LedgerSyncStore(store, space, current.userId)
        val remote = EncryptedRemote(PostgrestEnvelopeTransport(api), crypto, space) { id -> if (id == space) key else null }
        try {
            SyncEngine(local, remote).run()
            set { it.copy(lastSyncAt = Instant.now(), status = SyncEngine.status(true, 0, local.failedCount(), false), errorText = null) }
            refreshDevicesNow()
        } catch (e: CloudError.NotSignedIn) {
            forgetSession()
            error(e.message)
        } catch (e: CloudError.Offline) {
            set { it.copy(status = SyncStatus.SinConexion(local.pendingCount())) }
        } catch (e: Exception) {
            set { it.copy(status = SyncStatus.Error(message(e))) }
        } finally {
            isSyncing = false
        }
    }

    /** Sincroniza unos segundos después del último cambio guardado. */
    fun scheduleSync() {
        if (_ui.value.phase != CloudPhase.Ready) return
        scheduled?.cancel()
        scheduled = scope.launch {
            delay(syncDelayMillis)
            sync()
        }
    }

    /** Vuelve a intentar lo que no subió después de 3 intentos. */
    fun retryFailed() = scope.launch {
        val space = spaceId ?: return@launch
        val current = session ?: return@launch
        LedgerSyncStore(store, space, current.userId).retryFailed()
        sync()
    }

    fun pendingCount(): Int {
        val space = spaceId ?: return 0
        val current = session ?: return 0
        return LedgerSyncStore(store, space, current.userId).pendingCount()
    }

    private fun statusNow(): SyncStatus {
        val space = spaceId ?: return SyncStatus.Sincronizado
        val current = session ?: return SyncStatus.Sincronizado
        val failed = LedgerSyncStore(store, space, current.userId).failedCount()
        return SyncEngine.status(true, 0, failed, false)
    }

    // ---------- Salir y borrar ----------

    /** Cierra la sesión: quita este dispositivo de la cuenta y sus llaves. Los datos se quedan en el teléfono. */
    fun signOut() = scope.launch {
        working {
            if (session != null) {
                runCatching { api.deleteDevice(deviceId()) }
                session?.accessToken?.let { AuthClient.signOut(it) }
            }
            forgetEverything()
        }
    }

    /** Borra la cuenta en la nube (todo lo de la persona en Supabase). Lanza si no se pudo. */
    suspend fun deleteRemoteAccount() {
        if (session == null) return
        api.deleteMyAccount()
        forgetEverything()
    }

    /** Olvida todo lo de la nube en este teléfono: sesión, llaves e identidad del dispositivo. */
    fun forgetEverything() {
        forgetSession()
        secrets.names().filter { it.startsWith(SecretStore.SPACE_KEY_PREFIX) }.forEach(secrets::delete)
        listOf(SecretStore.DEVICE_KEY, SecretStore.DEVICE_ID, SecretStore.PKCE, SecretStore.PENDING_EMAIL).forEach(secrets::delete)
        store.prefs.edit().remove(KEY_SPACE).apply()
        store.journal.resetCursors()
        spaceId = null
        dismissedApprovals.clear()
        set { CloudUi(thisDeviceId = deviceId()) }
    }

    private fun forgetSession() {
        secrets.delete(SecretStore.SESSION)
        session = null
        scheduled?.cancel()
        set { it.copy(phase = CloudPhase.SignedOut, email = null, status = SyncStatus.Sincronizado, devices = emptyList(), pendingApprovals = emptyList(), approvalPrompt = null) }
    }

    // ---------- Sesión y llaves ----------

    private fun save(newSession: CloudSession) {
        session = newSession
        secrets.writeText(SecretStore.SESSION, newSession.toJson())
        secrets.delete(SecretStore.PENDING_EMAIL)
        set { it.copy(email = newSession.email) }
    }

    /** Access token vigente; lo renueva si vence en menos de un minuto. */
    private suspend fun validAccessToken(): String = refreshLock.withLock {
        val current = session ?: throw CloudError.NotSignedIn()
        if (!current.needsRefresh()) return current.accessToken
        val renewed = AuthClient.refresh(current)
        save(renewed)
        renewed.accessToken
    }

    private fun deviceId(): String {
        secrets.readText(SecretStore.DEVICE_ID)?.takeIf { it.length == 36 }?.let { return it }
        val id = UUID.randomUUID().toString()
        secrets.writeText(SecretStore.DEVICE_ID, id)
        return id
    }

    /** Par X25519 de este dispositivo: 32 bytes de privada y 32 de pública, cifrados con la llave del Keystore. */
    private fun deviceKeys(): DeviceKeyPair {
        secrets.read(SecretStore.DEVICE_KEY)?.takeIf { it.size == 64 }?.let { return DeviceKeyPair(it.copyOfRange(0, 32), it.copyOfRange(32, 64)) }
        val pair = crypto.newAgreementKeyPair()
        secrets.write(SecretStore.DEVICE_KEY, pair.privateKey + pair.publicKey)
        return pair
    }

    private fun spaceKey(spaceId: String) = secrets.read(SecretStore.spaceKey(spaceId))?.takeIf { it.size == E2EEFormat.KEY_LENGTH }
    private fun storeSpaceKey(key: ByteArray, spaceId: String) = secrets.write(SecretStore.spaceKey(spaceId), key)

    private fun message(e: Exception) = e.message ?: "Algo falló. Intenta de nuevo."

    companion object {
        const val KEY_SPACE = "nube.espacio"

        /** Lee `mprogress://auth-callback?code=...` (o con el error en el fragmento). Null si no es del inicio de sesión. */
        fun callbackParams(uri: String): Map<String, String>? {
            val prefix = "${CloudConfig.CALLBACK_SCHEME}://${CloudConfig.CALLBACK_HOST}"
            if (!uri.startsWith(prefix)) return null
            val rest = uri.removePrefix(prefix)
            val parts = rest.substringAfter('?', "").substringBefore('#') + "&" + rest.substringAfter('#', "")
            return parts.split('&').filter { it.contains('=') }.associate {
                val (k, v) = it.split('=', limit = 2)
                URLDecoder.decode(k, "UTF-8") to URLDecoder.decode(v, "UTF-8")
            }
        }

        @Volatile private var instance: CloudAccount? = null

        fun get(context: Context): CloudAccount = instance ?: synchronized(this) {
            instance ?: CloudAccount(Store.get(context), KeystoreSecretStore(context.applicationContext), deviceName = deviceName(context)).also { instance = it }
        }

        /** Solo para las capturas: una cuenta con un estado escrito a mano. */
        fun install(account: CloudAccount) { instance = account }

        /** El nombre que la persona le puso al teléfono ("Galaxy S24 de Juan"); si no hay, el modelo. */
        fun deviceName(context: Context): String =
            runCatching { android.provider.Settings.Global.getString(context.contentResolver, android.provider.Settings.Global.DEVICE_NAME) }.getOrNull()
                ?.takeIf { it.isNotBlank() }?.take(60) ?: android.os.Build.MODEL ?: "Android"
    }
}
