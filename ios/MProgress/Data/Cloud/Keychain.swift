import Foundation
import Security

/// Llavero del iPhone para la cuenta y el cifrado (F10): sesión, llaves del dispositivo y llaves de los espacios.
/// Todo queda solo en este dispositivo (sin iCloud) y disponible después del primer desbloqueo, para que el
/// registro rápido y la sincronización funcionen con la pantalla bloqueada.
enum Keychain {
    static let session = "com.olarte.mprogress.cloud.session"
    static let deviceKey = "com.olarte.mprogress.cloud.device-key"
    static let deviceId = "com.olarte.mprogress.cloud.device-id"
    static let pkceVerifier = "com.olarte.mprogress.cloud.pkce"
    static func spaceKey(_ spaceId: UUID) -> String { "com.olarte.mprogress.cloud.space-key.\(E2EEFormat.id(spaceId))" }
    /// Prefijo de todas las llaves de espacio, para borrarlas al cerrar sesión.
    static let spaceKeyPrefix = "com.olarte.mprogress.cloud.space-key."

    static func read(_ service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func write(_ data: Data, _ service: String) -> Bool {
        delete(service)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Borra todas las llaves de espacio guardadas.
    static func deleteAllSpaceKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return }
        for item in items {
            if let service = item[kSecAttrService as String] as? String, service.hasPrefix(spaceKeyPrefix) {
                delete(service)
            }
        }
    }
}
