package com.olarte.mprogress.domain

/** Textos cortos de la sección "Límites y ahorro" de Dinero, iguales a PlanningSummary de iOS. */
object PlanningSummary {
    fun budgets(statuses: List<BudgetStatus>): String {
        if (statuses.isEmpty()) return "Sin límites"
        val count = if (statuses.size == 1) "1 límite" else "${statuses.size} límites"
        val over = statuses.count { it.level == BudgetLevel.SUPERADO }
        if (over > 0) return "$count · $over ${if (over == 1) "pasado" else "pasados"}"
        val near = statuses.count { it.level == BudgetLevel.CERCA }
        if (near > 0) return "$count · $near cerca"
        return "$count · al día"
    }

    /** Lo ahorrado (sin pasar de cada meta) sobre lo que se busca, redondeado hacia abajo. */
    fun goals(progress: List<GoalProgress>): String {
        if (progress.isEmpty()) return "Sin metas"
        val count = if (progress.size == 1) "1 meta" else "${progress.size} metas"
        val target = progress.sumOf { maxOf(0L, it.goal.targetMinor) }
        val saved = progress.sumOf { minOf(maxOf(0L, it.savedMinor), maxOf(0L, it.goal.targetMinor)) }
        val percent = if (target > 0) saved * 100 / target else 0
        return "$count · $percent%"
    }
}
