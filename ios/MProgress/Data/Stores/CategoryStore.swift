import Foundation
import SwiftData

/// Categorías propias (las crea la persona en el selector de categoría). Las de la app (globales, sin espacio)
/// no se cambian ni se borran. Todo cambio pone la fecha y queda pendiente de sincronizar, como en las demás stores;
/// van en el respaldo y en la nube con las demás categorías del espacio.
@MainActor
final class CategoryStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Las vivas que ve un espacio: las de la app y las propias.
    func categories(spaceId: UUID) throws -> [SpendCategory] {
        try context.fetch(FetchDescriptor<SpendCategory>(predicate: #Predicate<SpendCategory> { $0.deletedAt == nil },
                                                         sortBy: [SortDescriptor(\.sort)]))
            .filter { $0.ownerSpaceId == nil || $0.ownerSpaceId == spaceId }
    }

    /// Crea una categoría propia (el nombre ya pasó por `CategoryForm.problem`), antes de "Otros".
    @discardableResult
    func add(name: String, icon: String, spaceId: UUID, now: Date = .now) throws -> SpendCategory {
        let sorts = try categories(spaceId: spaceId).map(\.sort)
        let category = SpendCategory(ownerSpaceId: spaceId, name: CategoryForm.cleanName(name), icon: icon,
                                     sort: CategoryForm.nextSort(existing: sorts))
        category.touch(now)
        context.insert(category)
        try context.save()
        return category
    }

    func update(_ category: SpendCategory, name: String, icon: String, now: Date = .now) throws {
        let clean = CategoryForm.cleanName(name)
        guard !category.isGlobal, !clean.isEmpty else { return }
        guard category.name != clean || category.icon != icon else { return }
        category.name = clean
        category.icon = icon
        category.touch(now)
        try context.save()
    }

    /// Borrado suave, con deshacer. Los movimientos conservan el id y quedan sin categoría a la vista.
    func delete(_ category: SpendCategory, now: Date = .now) throws {
        guard !category.isGlobal else { return }
        category.deletedAt = now
        category.touch(now)
        try context.save()
    }

    func restore(_ category: SpendCategory, now: Date = .now) throws {
        category.deletedAt = nil
        category.touch(now)
        try context.save()
    }
}
