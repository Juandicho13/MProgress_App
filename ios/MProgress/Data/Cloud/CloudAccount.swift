import Foundation
import SwiftData
import Observation

/// Cuenta en la nube y sincronización cifrada (docs/PLAN_F10.md). La app funciona igual sin cuenta.
///
/// Al entrar: el espacio Personal de la nube (lo crea el servidor) pasa a ser el de los datos locales,
/// este dispositivo se registra con su llave pública y:
/// - si es el primer dispositivo de la cuenta, crea la llave del espacio, la envuelve para sí mismo y para
///   el código de recuperación, y muestra el código;
/// - si ya hay otros, espera a que uno lo apruebe (o a que escriba el código de recuperación).
@MainActor
@Observable
final class CloudAccount {
    static let shared = CloudAccount()

    enum Phase: Equatable {
        case signedOut
        case linkSent(email: String)
        case connecting
        /// Ya hay otro dispositivo en la cuenta: este espera la aprobación o el código de recuperación.
        case needsApproval
        case ready
    }

    /// Código de recuperación recién creado, para mostrarlo una vez.
    struct RecoveryPrompt: Identifiable, Equatable {
        let id = UUID()
        let code: String
    }

    private(set) var phase: Phase = .signedOut
    private(set) var email: String?
    private(set) var status: SyncStatus = .sincronizado
    private(set) var lastSyncAt: Date?
    private(set) var devices: [RemoteDevice] = []
    /// Dispositivos de la cuenta que todavía no tienen la llave.
    private(set) var pendingApprovals: [RemoteDevice] = []
    private(set) var isWorking = false
    var errorText: String?
    var recoveryPrompt: RecoveryPrompt?
    /// Aviso "Aprueba tu otro iPhone" (se muestra una vez por dispositivo y por sesión).
    var approvalPrompt: RemoteDevice?

    /// Avance de la primera subida (F10-05): "Subiendo tus datos: 120 de 340".
    struct UploadProgress: Equatable {
        var done: Int
        var total: Int
    }

    private(set) var uploadProgress: UploadProgress?
    /// La primera subida de este usuario a este espacio ya se hizo: "Tus datos ya están en la nube, cifrados".
    private(set) var initialUploadDone = false
    /// Cambios sin subir por tabla (pastilla y hoja de estado, F10-04).
    private(set) var pendingCounts: [String: Int] = [:]
    /// Los que no subieron después de 3 intentos.
    private(set) var failedCount = 0
    /// Último error de la nube en palabras (los de conexión no: esos los dice la pastilla).
    private(set) var lastError: String?
    /// Lo que dice NWPathMonitor.
    private(set) var isOnline = true
    /// La nube no respondió por la red aunque el sistema diga que hay ruta (portal cautivo, red caída).
    private var offlineByError = false
    /// Errores seguidos de la nube, para esperar más antes de reintentar (`SyncBackoff`).
    private var failures = 0
    private var retryTask: Task<Void, Never>?

    private var session: CloudSession?
    private var spaceId: UUID?
    private var isSyncing = false
    private var scheduled: Task<Void, Never>?
    private var dismissedApprovals: Set<UUID> = []
    private let crypto: CryptoProvider = CryptoKitProvider()
    private static let spaceIdKey = "cloud.espacio"

    var isSignedIn: Bool { session != nil }
    var thisDeviceId: UUID { deviceId() }

    /// Hay internet y la nube responde.
    var isReachable: Bool { isOnline && !offlineByError }
    var pendingTotal: Int { pendingCounts.values.reduce(0, +) }

    /// Estado de la pastilla de Inicio. Nil sin cuenta (o mientras este dispositivo no tiene la llave).
    var pill: SyncPill? {
        SyncPill.state(signedIn: phase == .ready, online: isReachable, running: isSyncing, pending: pendingTotal,
                       failed: failedCount, hasError: lastError != nil)
    }

    /// Marca "Pendiente" junto a un movimiento: con cuenta y con un cambio que todavía no sube.
    func showsPendingMark(_ model: some SyncTracked) -> Bool {
        phase == .ready && model.syncStateRaw != SyncState.synced.rawValue
    }

    private var api: CloudAPI { CloudAPI(accessToken: { [unowned self] in try await self.validAccessToken() }) }

    private var context: ModelContext? { try? Persistence.shared().mainContext }

    // MARK: Arranque

    /// Lee la sesión del llavero. Si ya tenía la llave, queda lista sin esperar a la red.
    func start() {
        // Sin conexión la pastilla lo dice; al volver el internet se sincroniza (F10-04).
        Connectivity.shared.start { online in CloudAccount.shared.connectivityChanged(online) }
        guard let data = Keychain.read(Keychain.session), let saved = try? JSONDecoder().decode(CloudSession.self, from: data) else { return }
        session = saved
        email = saved.email
        if let stored = UserDefaults.standard.string(forKey: Self.spaceIdKey), let id = UUID(uuidString: stored), spaceKey(id) != nil {
            spaceId = id
            phase = .ready
            initialUploadDone = UserDefaults.standard.bool(forKey: InitialUpload.storageKey(spaceId: id, userId: saved.userId))
            refreshPending()
        } else {
            phase = .connecting
        }
        Task { await connect() }
    }

    // MARK: Entrar

    /// Paso 1: manda el enlace mágico al correo.
    func sendLink(email raw: String) async {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.contains("@"), clean.contains(".") else {
            errorText = "Escribe un correo válido."
            return
        }
        isWorking = true
        defer { isWorking = false }
        let verifier = PKCE.newVerifier(crypto: crypto)
        do {
            try await AuthClient.sendMagicLink(email: clean, codeChallenge: PKCE.challenge(for: verifier, crypto: crypto))
            Keychain.write(Data(verifier.utf8), Keychain.pkceVerifier)
            UserDefaults.standard.set(clean, forKey: "cloud.correoPendiente")
            phase = .linkSent(email: clean)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Paso 2: el enlace del correo abre la app con `mprogress://auth-callback?code=...`.
    /// Devuelve true si la URL era del inicio de sesión.
    @discardableResult
    func handle(url: URL) async -> Bool {
        guard url.host() == CloudConfig.callbackHost else { return false }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let description = items.first(where: { $0.name == "error_description" })?.value {
            errorText = description.replacingOccurrences(of: "+", with: " ")
            return true
        }
        guard let code = items.first(where: { $0.name == "code" })?.value,
              let verifierData = Keychain.read(Keychain.pkceVerifier),
              let verifier = String(data: verifierData, encoding: .utf8) else {
            errorText = CloudError.linkExpired.localizedDescription
            return true
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let pendingEmail = UserDefaults.standard.string(forKey: "cloud.correoPendiente")
            let newSession = try await AuthClient.exchange(code: code, verifier: verifier, email: pendingEmail)
            Keychain.delete(Keychain.pkceVerifier)
            save(newSession)
            await connect()
        } catch {
            errorText = error.localizedDescription
        }
        return true
    }

    /// Escribir el código de 6 dígitos (solo con `CloudConfig.allowsCodeEntry`).
    func verify(code: String) async {
        guard case .linkSent(let pendingEmail) = phase else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            save(try await AuthClient.verify(email: pendingEmail, code: code.filter(\.isNumber)))
            await connect()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func cancelLink() {
        Keychain.delete(Keychain.pkceVerifier)
        phase = .signedOut
    }

    // MARK: Conectar con el espacio y las llaves

    /// Adopta el espacio de la nube, registra este dispositivo y consigue la llave del espacio.
    func connect() async {
        guard let session, let context else { return }
        if phase != .ready { phase = .connecting }
        do {
            let remoteSpace = try await api.personalSpaceId(userId: session.userId)
            try SpaceAdoption.adopt(remoteSpace, ownerId: session.userId, context: context)
            spaceId = remoteSpace
            UserDefaults.standard.set(E2EEFormat.id(remoteSpace), forKey: Self.spaceIdKey)
            initialUploadDone = UserDefaults.standard.bool(forKey: InitialUpload.storageKey(spaceId: remoteSpace, userId: session.userId))

            let keys = deviceKeys()
            try await api.registerDevice(id: deviceId(), userId: session.userId, publicKey: keys.publicKey, name: "iPhone")
            let wrapped = try await api.spaceKeys(spaceId: remoteSpace)
            devices = try await api.devices()
            let mine = wrapped.first { $0.deviceId == deviceId() }

            if let mine {
                if spaceKey(remoteSpace) == nil {
                    let trusted = Set(devices.compactMap(\.publicKeyData))
                    let opened = try SpaceKeyWrap.unwrap(mine.wrappedKey, spaceId: remoteSpace, recipientDeviceId: deviceId(),
                                                         recipient: keys, trustedSenders: trusted, crypto: crypto)
                    storeSpaceKey(opened.spaceKey, remoteSpace)
                }
                phase = .ready
            } else if wrapped.isEmpty {
                // Primer dispositivo de la cuenta: crea la llave y el código de recuperación.
                let spaceKey = SpaceKeyWrap.newSpaceKey(crypto: crypto)
                let forMe = try SpaceKeyWrap.wrap(spaceKey, spaceId: remoteSpace, recipientDeviceId: deviceId(),
                                                  recipientPublicKey: keys.publicKey, sender: keys, crypto: crypto)
                let code = RecoveryCode.generate(crypto: crypto)
                let forRecovery = try SpaceKeyWrap.wrapForRecovery(spaceKey, spaceId: remoteSpace,
                                                                   recoveryKey: RecoveryCode.key(code, crypto: crypto), crypto: crypto)
                try await api.addSpaceKey(spaceId: remoteSpace, deviceId: deviceId(), wrappedKey: forMe)
                try await api.addSpaceKey(spaceId: remoteSpace, deviceId: nil, wrappedKey: forRecovery)
                storeSpaceKey(spaceKey, remoteSpace)
                recoveryPrompt = RecoveryPrompt(code: code)
                phase = .ready
            } else {
                // Hay otros dispositivos: si este tenía una llave que ya no está en la nube, se quita.
                Keychain.delete(Keychain.spaceKey(remoteSpace))
                phase = .needsApproval
            }
            errorText = nil
            if phase == .ready { await sync() }
        } catch CloudError.notSignedIn {
            forgetSession()
            errorText = CloudError.notSignedIn.localizedDescription
        } catch {
            // Sin conexión con la llave ya guardada se sigue trabajando; al volver la red se sincroniza.
            if let spaceId, spaceKey(spaceId) != nil { phase = .ready }
            let offline = (error as? CloudError) == .offline
            if offline { offlineByError = true }
            refreshPending()
            status = offline ? .sinConexion(pending: pendingCount()) : .error(error.localizedDescription)
            errorText = error.localizedDescription
        }
    }

    /// "Ya lo aprobé": vuelve a buscar la llave.
    func checkApproval() async {
        await connect()
        if phase == .needsApproval { errorText = "Todavía no llega la aprobación. Ábrela en tu otro iPhone: Ajustes › Cuenta › Dispositivos." }
    }

    /// Recuperar las llaves con el código en un dispositivo nuevo.
    func useRecoveryCode(_ text: String) async -> Bool {
        guard let spaceId else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let recoveryKey = try RecoveryCode.key(text, crypto: crypto)
            guard let row = try await api.spaceKeys(spaceId: spaceId).first(where: { $0.deviceId == nil }) else {
                errorText = "Tu cuenta no tiene código de recuperación. Aprueba este iPhone desde tu otro dispositivo."
                return false
            }
            let spaceKey = try SpaceKeyWrap.unwrapWithRecovery(row.wrappedKey, spaceId: spaceId, recoveryKey: recoveryKey, crypto: crypto)
            let keys = deviceKeys()
            let forMe = try SpaceKeyWrap.wrap(spaceKey, spaceId: spaceId, recipientDeviceId: deviceId(),
                                              recipientPublicKey: keys.publicKey, sender: keys, crypto: crypto)
            try await api.addSpaceKey(spaceId: spaceId, deviceId: deviceId(), wrappedKey: forMe)
            storeSpaceKey(spaceKey, spaceId)
            phase = .ready
            errorText = nil
            await sync()
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    /// Cambia el código de recuperación: el anterior deja de servir.
    func newRecoveryCode() async {
        guard let spaceId, let key = spaceKey(spaceId) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let code = RecoveryCode.generate(crypto: crypto)
            let wrapped = try SpaceKeyWrap.wrapForRecovery(key, spaceId: spaceId, recoveryKey: RecoveryCode.key(code, crypto: crypto), crypto: crypto)
            try await api.deleteRecoveryKey(spaceId: spaceId)
            try await api.addSpaceKey(spaceId: spaceId, deviceId: nil, wrappedKey: wrapped)
            recoveryPrompt = RecoveryPrompt(code: code)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: Dispositivos

    func refreshDevices() async {
        guard let spaceId, phase == .ready else { return }
        do {
            devices = try await api.devices()
            let withKey = Set(try await api.spaceKeys(spaceId: spaceId).compactMap(\.deviceId))
            pendingApprovals = devices.filter { $0.id != deviceId() && !withKey.contains($0.id) && $0.publicKeyData != nil }
            if approvalPrompt == nil, let next = pendingApprovals.first(where: { !dismissedApprovals.contains($0.id) }) {
                approvalPrompt = next
            }
        } catch {
            // Se reintenta en la próxima sincronización.
        }
    }

    /// Le envuelve la llave del espacio al otro dispositivo: con eso ya puede leer los datos.
    func approve(_ device: RemoteDevice) async {
        guard let spaceId, let key = spaceKey(spaceId), let publicKey = device.publicKeyData else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let wrapped = try SpaceKeyWrap.wrap(key, spaceId: spaceId, recipientDeviceId: device.id, recipientPublicKey: publicKey,
                                                sender: deviceKeys(), crypto: crypto)
            try await api.addSpaceKey(spaceId: spaceId, deviceId: device.id, wrappedKey: wrapped)
            dismissedApprovals.insert(device.id)
            await refreshDevices()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func dismissApproval(_ device: RemoteDevice) {
        dismissedApprovals.insert(device.id)
        approvalPrompt = nil
    }

    /// Quita un dispositivo de la cuenta (y su llave). No puede volver a bajar datos nuevos sin aprobarlo otra vez.
    func remove(_ device: RemoteDevice) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.deleteDevice(device.id)
            await refreshDevices()
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: Sincronizar

    /// Al abrir, al volver a primer plano, después de guardar (con retraso), al volver el internet y con "Sincronizar ahora".
    /// La primera vez de este usuario en este espacio es la primera subida (F10-05): baja primero, une duplicados y sube
    /// todo lo local una sola vez, con avance.
    func sync() async {
        guard phase == .ready, !isSyncing, let spaceId, let key = spaceKey(spaceId), let context, let userId = session?.userId else { return }
        retryTask?.cancel()
        retryTask = nil
        isSyncing = true
        status = .sincronizando
        defer {
            isSyncing = false
            uploadProgress = nil
            refreshPending()
        }
        let local = SwiftDataSyncStore(context: context)
        let remote = EncryptedRemote(transport: PostgrestEnvelopeTransport(api: api), crypto: crypto, defaultSpaceId: spaceId) { id in
            id == spaceId ? key : nil
        }
        let doneKey = InitialUpload.storageKey(spaceId: spaceId, userId: userId)
        do {
            if UserDefaults.standard.bool(forKey: doneKey) {
                _ = try await SyncEngine(local: local, remote: remote).run()
            } else {
                uploadProgress = UploadProgress(done: 0, total: 0)
                let engine = SyncEngine(local: local, remote: remote, batchSize: InitialUpload.batchSize)
                _ = try await engine.initialUpload { [weak self] done, total in
                    self?.uploadProgress = UploadProgress(done: done, total: total)
                }
                UserDefaults.standard.set(true, forKey: doneKey)
                initialUploadDone = true
            }
            lastSyncAt = .now
            let failed = local.failedCount()
            status = SyncEngine.status(online: true, pending: 0, failed: failed, running: false)
            errorText = nil
            lastError = nil
            offlineByError = false
            failures = 0
            if local.appliedChanges > 0 {
                WidgetPublisher.publish(context: context)
                await NotificationScheduler.reschedule(context: context)
            }
            await refreshDevices()
        } catch CloudError.notSignedIn {
            forgetSession()
            errorText = CloudError.notSignedIn.localizedDescription
        } catch CloudError.offline {
            // Sin internet no se reintenta con reloj: se espera a que vuelva la conexión (connectivityChanged).
            offlineByError = true
            status = .sinConexion(pending: local.pendingCount())
        } catch {
            let text = Self.describe(error)
            lastError = text
            status = .error(text)
            scheduleRetry()
        }
    }

    /// Sincroniza unos segundos después del último cambio guardado.
    func scheduleSync() {
        refreshPending()
        guard phase == .ready, !isSyncing else { return }
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Vuelve a intentar lo que no subió después de 3 intentos ("Reintentar" en la hoja de estado).
    func retryFailed() async {
        guard let context else { return }
        try? SwiftDataSyncStore(context: context).retryFailed()
        failures = 0
        lastError = nil
        await sync()
    }

    /// NWPathMonitor cambió. Al volver el internet se sincroniza de una vez (o se vuelve a conectar si no alcanzó).
    func connectivityChanged(_ online: Bool) {
        let cameBack = online && (!isOnline || offlineByError)
        isOnline = online
        if !online {
            if phase == .ready { status = .sinConexion(pending: pendingTotal) }
            return
        }
        guard cameBack else { return }
        offlineByError = false
        failures = 0
        Task { [weak self] in
            guard let self else { return }
            if self.phase == .ready { await self.sync() } else if self.isSignedIn, self.phase == .connecting { await self.connect() }
        }
    }

    /// Vuelve a intentar después de un error de la nube, cada vez esperando más (5 s hasta 5 min). Una sola espera a la vez.
    private func scheduleRetry() {
        failures += 1
        let wait = SyncBackoff.delay(failures: failures)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Cuenta lo que falta por subir, por tipo (para la pastilla, la hoja y las marcas).
    func refreshPending() {
        guard phase == .ready, let context else {
            if !pendingCounts.isEmpty { pendingCounts = [:] }
            if failedCount != 0 { failedCount = 0 }
            return
        }
        let store = SwiftDataSyncStore(context: context)
        let counts = store.pendingCounts()
        if counts != pendingCounts { pendingCounts = counts }
        let failed = store.failedCount()
        if failed != failedCount { failedCount = failed }
    }

    /// El error en palabras para la persona.
    private static func describe(_ error: Error) -> String {
        if let cloud = error as? CloudError { return cloud.localizedDescription }
        if let e2ee = error as? E2EEError { return e2ee == .missingKey ? SyncText.missingKeyError : e2ee.localizedDescription }
        return SyncText.genericError
    }

    func pendingCount() -> Int {
        guard let context else { return 0 }
        return SwiftDataSyncStore(context: context).pendingCount()
    }

    // MARK: Salir y borrar

    /// Cierra la sesión: quita este dispositivo de la cuenta y sus llaves. Los datos se quedan en el iPhone.
    func signOut() async {
        isWorking = true
        defer { isWorking = false }
        if session != nil {
            try? await api.deleteDevice(deviceId())
            if let token = session?.accessToken { await AuthClient.signOut(accessToken: token) }
        }
        forgetEverything()
    }

    /// Borra la cuenta en la nube (todo lo de la persona en Supabase). Lanza si no se pudo.
    func deleteRemoteAccount() async throws {
        guard session != nil else { return }
        try await api.deleteMyAccount()
        forgetEverything()
    }

    /// Olvida todo lo de la nube en este iPhone: sesión, llaves e identidad del dispositivo.
    func forgetEverything() {
        forgetSession()
        Keychain.deleteAllSpaceKeys()
        Keychain.delete(Keychain.deviceKey)
        Keychain.delete(Keychain.deviceId)
        Keychain.delete(Keychain.pkceVerifier)
        UserDefaults.standard.removeObject(forKey: Self.spaceIdKey)
        SwiftDataSyncStore.resetCursors()
        spaceId = nil
        devices = []
        pendingApprovals = []
        lastSyncAt = nil
        status = .sincronizado
        retryTask?.cancel()
        retryTask = nil
        failures = 0
        lastError = nil
        offlineByError = false
        uploadProgress = nil
        initialUploadDone = false
        pendingCounts = [:]
        failedCount = 0
    }

    private func forgetSession() {
        Keychain.delete(Keychain.session)
        session = nil
        email = nil
        phase = .signedOut
    }

    // MARK: Sesión y llaves

    private func save(_ newSession: CloudSession) {
        session = newSession
        email = newSession.email
        if let data = try? JSONEncoder().encode(newSession) { Keychain.write(data, Keychain.session) }
    }

    /// Access token vigente; lo renueva si vence en menos de un minuto.
    private func validAccessToken() async throws -> String {
        guard let current = session else { throw CloudError.notSignedIn }
        guard current.needsRefresh() else { return current.accessToken }
        let renewed = try await AuthClient.refresh(current)
        save(renewed)
        return renewed.accessToken
    }

    private func deviceId() -> UUID {
        if let data = Keychain.read(Keychain.deviceId), let text = String(data: data, encoding: .utf8), let id = UUID(uuidString: text) {
            return id
        }
        let id = UUID()
        Keychain.write(Data(id.uuidString.utf8), Keychain.deviceId)
        return id
    }

    /// Par X25519 de este dispositivo: 32 bytes de privada y 32 de pública en el llavero.
    private func deviceKeys() -> DeviceKeyPair {
        if let data = Keychain.read(Keychain.deviceKey), data.count == 64 {
            return DeviceKeyPair(privateKey: Data(data.prefix(32)), publicKey: Data(data.suffix(32)))
        }
        let pair = crypto.newAgreementKeyPair()
        Keychain.write(pair.privateKey + pair.publicKey, Keychain.deviceKey)
        return pair
    }

    private func spaceKey(_ spaceId: UUID) -> Data? {
        Keychain.read(Keychain.spaceKey(spaceId)).flatMap { $0.count == E2EEFormat.keyLength ? $0 : nil }
    }

    private func storeSpaceKey(_ key: Data, _ spaceId: UUID) {
        Keychain.write(key, Keychain.spaceKey(spaceId))
    }
}
