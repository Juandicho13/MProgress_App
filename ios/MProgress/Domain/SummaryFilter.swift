import Foundation

/// Barra de filtros del Resumen: el periodo, "Todas" y una pastilla por categoría con gasto en el periodo,
/// de la que más gasta a la que menos. Se pueden elegir varias categorías; "Todas" es el conjunto vacío.
/// Igual que domain/SummaryFilter.kt de Android.
enum SummaryFilter {
    /// Toca una categoría: si estaba, sale; si no, entra.
    static func toggle(_ selected: Set<UUID>, _ id: UUID) -> Set<UUID> {
        var next = selected
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        return next
    }

    /// Lo que de verdad se filtra: solo las elegidas que tienen pastilla en este periodo. Nil es "Todas".
    static func effective(_ selected: Set<UUID>, chips: [UUID]) -> Set<UUID>? {
        let kept = selected.intersection(chips)
        return kept.isEmpty ? nil : kept
    }

    /// Título de la tarjeta de gastos con filtro: "Gastos de Mercado", "Gastos de Mercado y Salidas",
    /// "Gastos de 3 categorías". Los nombres llegan en el orden de las pastillas.
    static func spendTitle(_ names: [String]) -> String {
        switch names.count {
        case 0: return "Ingresos y gastos"
        case 1: return "Gastos de \(names[0])"
        case 2: return "Gastos de \(names[0]) y \(names[1])"
        default: return "Gastos de \(names.count) categorías"
        }
    }
}
