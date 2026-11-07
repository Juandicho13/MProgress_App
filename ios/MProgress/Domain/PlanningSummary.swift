import Foundation

/// Textos cortos de la sección "Límites y ahorro" de Dinero: "2 límites · 1 pasado" y "1 meta · 45%".
enum PlanningSummary {
    static func budgets(_ statuses: [BudgetStatus]) -> String {
        guard !statuses.isEmpty else { return "Sin límites" }
        let count = statuses.count == 1 ? "1 límite" : "\(statuses.count) límites"
        let over = statuses.filter { $0.level == .superado }.count
        if over > 0 { return "\(count) · \(over) \(over == 1 ? "pasado" : "pasados")" }
        let near = statuses.filter { $0.level == .cerca }.count
        if near > 0 { return "\(count) · \(near) cerca" }
        return "\(count) · al día"
    }

    /// Porcentaje de todas las metas juntas: lo ahorrado (sin pasar de cada meta) sobre lo que se busca, redondeado hacia abajo.
    static func goals(_ progress: [GoalProgress]) -> String {
        guard !progress.isEmpty else { return "Sin metas" }
        let count = progress.count == 1 ? "1 meta" : "\(progress.count) metas"
        let target = progress.reduce(Int64(0)) { $0 + max(0, $1.goal.targetMinor) }
        let saved = progress.reduce(Int64(0)) { $0 + min(max(0, $1.savedMinor), max(0, $1.goal.targetMinor)) }
        let percent = target > 0 ? Int(saved * 100 / target) : 0
        return "\(count) · \(percent)%"
    }
}
