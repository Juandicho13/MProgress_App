import Foundation
import SwiftData
import Security

/// Base local (HANDOFF 9). Vive en el App Group para que widgets y reloj la lean (F12).
enum Persistence {
    static let appGroup = "group.com.olarte.mprogress"

    static let schema = Schema([
        Space.self, SpendCategory.self, Institution.self, Product.self, Recurring.self, Entry.self,
        Split.self, Transfer.self, Reminder.self, Budget.self, SavingsGoal.self, GoalContribution.self, RewardProgram.self,
    ])

    @MainActor private static var sharedContainer: ModelContainer?

    /// El contenedor de la app. La app y sus App Intents usan el mismo para no abrir la base dos veces.
    @MainActor
    static func shared() throws -> ModelContainer {
        if let sharedContainer { return sharedContainer }
        let container = try makeContainer()
        sharedContainer = container
        return container
    }

    @MainActor
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            configuration = ModelConfiguration(schema: schema, url: group.appending(path: "MProgress.store"), cloudKitDatabase: .none)
        } else {
            // Sin App Group (todavía sin firma): carpeta normal de la app.
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

/// Usuario local mientras no hay cuenta (HANDOFF 8.1). Se guarda en el llavero.
enum LocalIdentity {
    private static let service = "com.olarte.mprogress.local-user"

    static var userId: UUID {
        if let stored = read() { return stored }
        let new = UUID()
        save(new)
        return new
    }

    private static func read() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return UUID(uuidString: text)
    }

    private static func save(_ id: UUID) {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(id.uuidString.utf8),
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
