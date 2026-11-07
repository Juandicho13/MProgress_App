package com.olarte.mprogress.ui.money

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.runtime.Composable
import com.olarte.mprogress.data.Ledger
import com.olarte.mprogress.domain.BudgetMath
import com.olarte.mprogress.domain.PlanningSummary
import com.olarte.mprogress.domain.SavingsMath
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Límites y ahorro (Dinero): "2 límites · 1 pasado" y "1 meta · 45%", que abren sus pantallas. Igual que PlanningSection de iOS. */
@Composable
fun PlanningSection(ledger: Ledger, onOpen: (String) -> Unit = { com.olarte.mprogress.auto.LaunchAction.pending.value = it }) {
    val today = LocalDate.now()
    val statuses = BudgetMath.statuses(ledger.budgets, ledger.entries, today)
    val progress = ledger.goals.map { g -> SavingsMath.progress(g, ledger.contributions, ledger.product(g.productId)?.let { ledger.balance(it) }, today) }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        SectionLabel("Límites y ahorro")
        Card(padding = Spacing.s3) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                ListRow(icon = Icons.Rounded.Speed, title = "Límites", subtitle = PlanningSummary.budgets(statuses), chevron = true, onClick = { onOpen("limites") })
                ListRow(icon = Icons.Rounded.TrackChanges, title = "Ahorro", subtitle = PlanningSummary.goals(progress), chevron = true, onClick = { onOpen("ahorro") })
            }
        }
    }
}
