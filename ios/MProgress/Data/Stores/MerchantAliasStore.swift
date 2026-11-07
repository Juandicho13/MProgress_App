import Foundation
import SwiftData

/// Nombres de comercios aprendidos (Ajustes › Nombres de comercios). Todo cambio pone la fecha y queda
/// pendiente de sincronizar, como en las demás stores.
@MainActor
final class MerchantAliasStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Las reglas vivas del espacio, por nombre.
    func aliases(spaceId: UUID) throws -> [MerchantAlias] {
        try context.fetch(FetchDescriptor<MerchantAlias>(
            predicate: #Predicate<MerchantAlias> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.name)]
        ))
    }

    func rules(spaceId: UUID) -> [MerchantAliasRule] {
        ((try? aliases(spaceId: spaceId)) ?? []).map(\.rule)
    }

    /// La regla del comercio que llega, si hay una.
    func match(_ raw: String?, spaceId: UUID) -> MerchantAliasRule? {
        MerchantAliasMath.match(raw, rules: rules(spaceId: spaceId))
    }

    /// Guarda lo aprendido: crea la regla o cambia la de la misma clave (aunque estuviera borrada).
    /// Si no cambió nada no la toca, así no sube a la nube sin razón.
    @discardableResult
    func save(_ rule: MerchantAliasRule, spaceId: UUID, now: Date = .now) throws -> MerchantAlias {
        let key = rule.key
        let descriptor = FetchDescriptor<MerchantAlias>(predicate: #Predicate<MerchantAlias> { $0.spaceId == spaceId && $0.merchantKey == key })
        if let existing = try context.fetch(descriptor).first {
            if existing.deletedAt == nil && existing.name == rule.name && existing.categoryId == rule.categoryId { return existing }
            existing.name = rule.name
            existing.categoryId = rule.categoryId
            existing.deletedAt = nil
            existing.touch(now)
            try context.save()
            return existing
        }
        let alias = MerchantAlias(spaceId: spaceId, key: key, name: rule.name, categoryId: rule.categoryId)
        alias.touch(now)
        context.insert(alias)
        try context.save()
        return alias
    }

    /// Aprende de un movimiento que llegó solo (SMS, Apple Pay o recibo) y que la persona acaba de guardar o editar.
    func learn(from entry: Entry, now: Date = .now) throws {
        let automatic = entry.sourceRaw != EntrySource.manual.rawValue
        guard let rule = MerchantAliasMath.learn(raw: entry.merchant, automatic: automatic, name: entry.name, categoryId: entry.categoryId) else { return }
        try save(rule, spaceId: entry.spaceId, now: now)
    }

    /// Cambia el nombre o la categoría desde Ajustes.
    func update(_ alias: MerchantAlias, name: String, categoryId: UUID?, now: Date = .now) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        alias.name = clean
        alias.categoryId = categoryId
        alias.touch(now)
        try context.save()
    }

    /// Borrado suave, con deshacer.
    func delete(_ alias: MerchantAlias, now: Date = .now) throws {
        alias.deletedAt = now
        alias.touch(now)
        try context.save()
    }

    func restore(_ alias: MerchantAlias, now: Date = .now) throws {
        alias.deletedAt = nil
        alias.touch(now)
        try context.save()
    }
}
