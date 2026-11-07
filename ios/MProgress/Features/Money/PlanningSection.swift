import SwiftUI
import SwiftData

/// Destinos de la sección "Límites y ahorro" de Dinero (antes estaban en Más acciones).
enum PlanningRoute: Hashable {
    case limites, ahorro
}

/// Límites y ahorro (Dinero): dos filas con un estado corto, "2 límites · 1 pasado" y "1 meta · 45%", que abren sus pantallas.
struct PlanningSection: View {
    let wallet: WalletSnapshot
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil }) private var allBudgets: [Budget]
    @Query(filter: #Predicate<SavingsGoal> { $0.deletedAt == nil }) private var allGoals: [SavingsGoal]
    @Query(filter: #Predicate<GoalContribution> { $0.deletedAt == nil }) private var allContributions: [GoalContribution]

    var body: some View {
        let id = wallet.space?.id
        let statuses = BudgetMath.statuses(budgets: allBudgets.filter { $0.spaceId == id }.map(\.record),
                                           entries: wallet.entryRecords, now: .now, calendar: calendar)
        let contributions = allContributions.filter { $0.spaceId == id }.map { (goalId: $0.goalId, amountMinor: $0.amountMinor) }
        let progress = allGoals.filter { $0.spaceId == id }.map { goal in
            SavingsMath.progress(goal: goal.record, contributions: contributions,
                                 productBalance: goal.productId.flatMap { pid in wallet.products.first { $0.id == pid } }.map(wallet.balance),
                                 now: .now, calendar: calendar)
        }
        VStack(alignment: .leading, spacing: Spacing.s3) {
            SectionLabel(text: "Límites y ahorro")
            Card(padding: Spacing.s3) {
                VStack(spacing: Spacing.s2) {
                    NavigationLink(value: PlanningRoute.limites) {
                        row("gauge.with.dots.needle.33percent", "Límites", PlanningSummary.budgets(statuses))
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: PlanningRoute.ahorro) {
                        row("target", "Ahorro", PlanningSummary.goals(progress))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        ListRow(tile: IconTile(content: .symbol(symbol)), title: title, subtitle: subtitle) {
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.texto2)
        }
        .contentShape(Rectangle())
    }
}
