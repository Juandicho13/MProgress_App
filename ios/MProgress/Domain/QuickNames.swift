import Foundation

/// Un nombre que la persona usa seguido en el registro rápido, con la categoría que le puso la última vez.
struct QuickName: Hashable, Sendable {
    var name: String
    var categoryId: UUID?
}

/// Sugerencias de "¿En qué?" en el registro rápido: los nombres más usados entre los movimientos recientes.
/// Igual en Android (`domain/QuickAdd.kt`).
enum QuickNames {
    /// Cuántas sugerencias se muestran.
    static let limit = 6
    /// Cuántos movimientos recientes del mismo tipo se miran.
    static let window = 150

    /// Nombres que pone la app sola: no se sugieren.
    private static let defaults: Set<String> = ["gasto rapido", "ingreso rapido", "gasto", "ingreso"]

    static func isDefault(_ name: String) -> Bool {
        defaults.contains(InitialUpload.normalizedName(name))
    }

    /// Los nombres más usados entre los últimos movimientos de ese tipo (sin pagos fijos ni nombres por defecto).
    /// Empate: el más reciente primero. Se muestra como se escribió la última vez.
    static func recent(_ entries: [EntryRecord], kind: EntryKind, limit: Int = limit) -> [QuickName] {
        let candidates = entries.enumerated()
            .filter { item in
                let entry = item.element
                let clean = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return entry.kind == kind && entry.recurringId == nil && !clean.isEmpty && !isDefault(clean)
            }
            .sorted { a, b in
                a.element.occurredAt != b.element.occurredAt ? a.element.occurredAt > b.element.occurredAt : a.offset > b.offset
            }
            .prefix(window)
            .map(\.element)

        struct Group { var name: String; var categoryId: UUID?; var count: Int; var firstSeen: Int }
        var groups: [String: Group] = [:]
        for (position, entry) in candidates.enumerated() {
            let key = InitialUpload.normalizedName(entry.name)
            guard !key.isEmpty else { continue }
            if var group = groups[key] {
                group.count += 1
                if group.categoryId == nil { group.categoryId = entry.categoryId }
                groups[key] = group
            } else {
                groups[key] = Group(name: entry.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    categoryId: entry.categoryId, count: 1, firstSeen: position)
            }
        }
        return groups.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.firstSeen < $1.firstSeen }
            .prefix(limit)
            .map { QuickName(name: $0.name, categoryId: $0.categoryId) }
    }

    /// Las sugerencias que siguen sirviendo mientras se escribe: las que empiezan por lo escrito (sin tildes ni
    /// mayúsculas) y no son exactamente lo escrito. Sin texto, todas.
    static func matching(_ names: [QuickName], typed: String) -> [QuickName] {
        let key = InitialUpload.normalizedName(typed)
        guard !key.isEmpty else { return names }
        return names.filter {
            let candidate = InitialUpload.normalizedName($0.name)
            return candidate.hasPrefix(key) && candidate != key
        }
    }

    /// La categoría que se usó la última vez con ese nombre, si el nombre es una de las sugerencias.
    static func categoryId(for name: String, in names: [QuickName]) -> UUID? {
        let key = InitialUpload.normalizedName(name)
        guard !key.isEmpty else { return nil }
        return names.first { InitialUpload.normalizedName($0.name) == key }?.categoryId
    }
}
