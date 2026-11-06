import Foundation
import SwiftData

/// Datos de la primera apertura: espacio Personal y categorías globales (las mismas de la migración SQL).
enum Seed {
    struct CategorySeed: Sendable {
        let id: UUID
        let name: String
        let icon: String
        let sort: Int
    }

    /// Ids fijos para que coincidan en todos los dispositivos.
    static let categories: [CategorySeed] = [
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000001")!, name: "Entretenimiento", icon: "play.rectangle", sort: 1),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000002")!, name: "Música", icon: "music.note", sort: 2),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000003")!, name: "Productividad", icon: "briefcase", sort: 3),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000004")!, name: "Servicios", icon: "wrench.and.screwdriver", sort: 4),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000005")!, name: "Renta", icon: "house", sort: 5),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000006")!, name: "Mercado", icon: "cart", sort: 6),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000007")!, name: "Transporte", icon: "car", sort: 7),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000008")!, name: "Salidas", icon: "fork.knife", sort: 8),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000009")!, name: "Deporte", icon: "dumbbell", sort: 9),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000010")!, name: "Salud", icon: "cross.case", sort: 10),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000011")!, name: "Educación", icon: "graduationcap", sort: 11),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000012")!, name: "Social", icon: "person.2", sort: 12),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000013")!, name: "Negocios", icon: "building.2", sort: 13),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000014")!, name: "Finanzas", icon: "banknote", sort: 14),
        CategorySeed(id: UUID(uuidString: "0A000000-0000-4000-8000-000000000099")!, name: "Otros", icon: "square.grid.2x2", sort: 99),
    ]

    /// Crea lo que falte. Se puede llamar en cada apertura: no duplica.
    @MainActor
    @discardableResult
    static func runIfNeeded(context: ModelContext, localUser: UUID) throws -> Space {
        let spaces = try context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil }))
        let personal: Space
        if let existing = spaces.first(where: { $0.kindRaw == "personal" }) {
            personal = existing
        } else {
            personal = Space(ownerId: localUser, name: "Personal")
            context.insert(personal)
        }

        let existingIds = Set(try context.fetch(FetchDescriptor<SpendCategory>()).map(\.id))
        for seed in categories where !existingIds.contains(seed.id) {
            context.insert(SpendCategory(id: seed.id, ownerSpaceId: nil, name: seed.name, icon: seed.icon, sort: seed.sort))
        }

        if context.hasChanges { try context.save() }
        return personal
    }
}
