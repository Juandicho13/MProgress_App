package com.olarte.mprogress.ui.planning

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

private fun money(m: Long) = Money(m).formatted()

@Composable
private fun levelColor(l: BudgetLevel) = when (l) { BudgetLevel.BIEN -> Palette.brasa; BudgetLevel.CERCA -> Palette.oroRelleno; BudgetLevel.SUPERADO -> Palette.peligro }

@Composable
private fun Bar(ratio: Double, color: Color, height: androidx.compose.ui.unit.Dp = 6.dp) {
    Box(Modifier.fillMaxWidth().height(height).clip(CircleShape).background(Palette.superficie3)) {
        Box(Modifier.fillMaxWidth(ratio.toFloat().coerceIn(0.02f, 1f)).height(height).clip(CircleShape).background(color))
    }
}

/** Página con volver, título y botón opcional arriba a la derecha (Límites, Ahorro). */
@Composable
fun PlanningPage(title: String, onBack: () -> Unit, action: (@Composable () -> Unit)? = null, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BackButton("Volver", onBack); Spacer(Modifier.weight(1f)); action?.let { Box(Modifier.padding(top = Spacing.s2)) { it() } }
        }
        T(title, Type.titulo1)
        content()
    }
}

/** Límites (pantalla 27): anillo del total del mes, barras por categoría y aviso de exceso. */
@Composable
fun BudgetsScreen(store: Store, onBack: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val today = LocalDate.now()
    val statuses = BudgetMath.statuses(ledger.budgets, ledger.entries, today)
    val total = statuses.firstOrNull { it.budget.categoryId == null }
    val byCategory = statuses.filter { it.budget.categoryId != null }
    var editing by remember { mutableStateOf<BudgetRecord?>(null) }
    var isNew by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize()) {
        PlanningPage("Límites", onBack) {
            if (total != null) Box(Modifier.clickable { editing = total.budget; isNew = false }) { RingCard(total, today) }
            else Card {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    T("Ponle un tope al mes", Type.titulo3)
                    T("Te avisamos al llegar al 80 % y al pasarte.", Type.cuerpo2, Palette.texto2)
                    SecondaryButton("Límite del mes") { editing = BudgetRecord(categoryId = null, limitMinor = 0); isNew = true }
                }
            }
            if (byCategory.isNotEmpty()) {
                SectionLabel("Por categoría")
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                        byCategory.forEach { s ->
                            Column(Modifier.clickable { editing = s.budget; isNew = false }, verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                                    T(Categories.byId(s.budget.categoryId)?.name ?: "Categoría", Type.cuerpo, modifier = Modifier.weight(1f))
                                    T(money(s.spentMinor), Type.cifraPequena, levelColor(s.level))
                                    T("de ${money(s.budget.limitMinor)}", Type.cuerpo2, Palette.texto2)
                                }
                                Bar(s.ratio, levelColor(s.level))
                            }
                        }
                    }
                }
            }
            byCategory.firstOrNull { it.level == BudgetLevel.SUPERADO }?.let { over ->
                T("Te pasaste en ${Categories.byId(over.budget.categoryId)?.name} por ${money(-over.remainingMinor)}. Toca la categoría si quieres ajustar el límite.", Type.cuerpo2,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.boton)).background(Palette.brasaVelo).padding(Spacing.s4))
            }
            SecondaryButton("Nuevo límite") {
                val used = ledger.budgets.mapNotNull { it.categoryId }.toSet()
                editing = BudgetRecord(categoryId = Categories.available().firstOrNull { it.id !in used }?.id, limitMinor = 0); isNew = true
            }
        }
        editing?.let { b -> BudgetForm(store, b, isNew) { editing = null } }
    }
}

@Composable
private fun RingCard(s: BudgetStatus, today: LocalDate) {
    val color = levelColor(s.level)
    val track = Palette.superficie3
    Card {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s5)) {
            Box(Modifier.size(104.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.size(104.dp)) {
                    val w = 12.dp.toPx(); val inset = w / 2
                    drawArc(track, 0f, 360f, false, Offset(inset, inset), Size(size.width - w, size.height - w), style = Stroke(w))
                    drawArc(color, -90f, (360 * minOf(1.0, s.ratio)).toFloat(), false, Offset(inset, inset), Size(size.width - w, size.height - w), style = Stroke(w, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) { T("${Math.round(s.ratio * 100)} %", Type.cifraPequena); T("usado", Type.leyenda, Palette.texto2) }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                T("Límite del mes", Type.cuerpo2, Palette.texto2)
                T(money(s.budget.limitMinor), Type.cifra)
                T(if (s.remainingMinor >= 0) "Te quedan ${money(s.remainingMinor)} · ${money(BudgetMath.dailyAllowance(s.remainingMinor, today))} al día" else "Te pasaste por ${money(-s.remainingMinor)}",
                    Type.cuerpo2, if (s.remainingMinor >= 0) Palette.texto2 else Palette.peligro)
            }
        }
    }
}

@Composable
private fun BudgetForm(store: Store, budget: BudgetRecord, isNew: Boolean, onDone: () -> Unit) {
    var categoryId by remember { mutableStateOf(budget.categoryId) }
    var limit by remember { mutableStateOf(budget.limitMinor) }
    var menu by remember { mutableStateOf(false) }
    FormSheet(if (isNew) "Nuevo límite" else "Cambiar límite", onDone, canConfirm = limit > 0, full = false, onConfirm = {
        store.saveBudget(budget.copy(categoryId = categoryId, limitMinor = limit)); onDone()
    }) {
        if (isNew) Card(padding = Spacing.s2) {
            Box {
                FormRow("Categoría", Categories.byId(categoryId)?.name ?: "Total del mes", onClick = { menu = true })
                DropdownMenu(menu, { menu = false }, containerColor = Palette.superficie2) {
                    DropdownMenuItem({ T("Total del mes", Type.cuerpo) }, { categoryId = null; menu = false })
                    Categories.available().forEach { c -> DropdownMenuItem({ T(c.name, Type.cuerpo) }, { categoryId = c.id; menu = false }) }
                }
            }
        }
        MoneyField("Tope del mes", limit) { limit = it }
        if (!isNew) SecondaryButton("Quitar límite", danger = true) { store.deleteBudget(budget.id); onDone() }
    }
}

/** Ahorro (pantalla 26): total ahorrado, metas con barra y aportar. Una meta ligada a una cajita toma su saldo. */
@Composable
fun SavingsScreen(store: Store, onBack: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val today = LocalDate.now()
    val progress = ledger.goals.map { g -> SavingsMath.progress(g, ledger.contributions, ledger.product(g.productId)?.let { ledger.balance(it) }, today) }
    val total = progress.sumOf { it.savedMinor }
    val month = SavingsMath.savedThisMonth(ledger.contributions, today)
    var editing by remember { mutableStateOf<GoalRecord?>(null) }
    var creating by remember { mutableStateOf(false) }
    var contributing by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize()) {
        PlanningPage("Ahorro", onBack, action = { CircleIconButton(Icons.Rounded.Add, "Nueva meta", filled = true) { creating = true } }) {
            Card {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    T("Ahorrado en total", Type.cuerpo2, Palette.texto2)
                    T(money(total), Type.cifraGrande)
                    if (month != 0L) T("${Money(month).formatted(sign = true)} este mes", Type.leyenda, Palette.hielo)
                }
            }
            if (ledger.goals.isEmpty()) Card {
                EmptyState("Tu primera meta", "Un viaje, un fondo de emergencia o lo que quieras. Puedes ligarla a una cajita para que se llene sola.",
                    art = { IconTile(Icons.Rounded.TrackChanges, Palette.hieloVelo, Palette.hielo, size = 64.dp) }, actions = { PrimaryButton("Crear meta") { creating = true } })
            } else {
                progress.forEach { p ->
                    val product = ledger.product(p.goal.productId)
                    val lines = listOfNotNull("${money(p.savedMinor)} de ${money(p.goal.targetMinor)}", product?.let { "ligada a ${it.name}" },
                        p.monthlyNeededMinor?.let { "aporta ${money(it)} al mes" })
                    val subtitle = "Personal" + (p.goal.targetDate?.let { " · meta ${DueText.months[it.monthValue - 1]} ${it.year}" } ?: "")
                    Box(Modifier.clickable { editing = p.goal }) {
                        Card {
                            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                                ListRow(p.goal.name, title = p.goal.name, subtitle = subtitle, tint = Palette.hieloVelo, fg = Palette.hielo) { T("${Math.round(p.ratio * 100)} %", Type.cifraPequena) }
                                Bar(p.ratio, if (p.ratio >= 1) Palette.exito else Palette.hielo, 8.dp)
                                T(lines.joinToString(" · "), Type.leyenda, Palette.texto2)
                            }
                        }
                    }
                }
                SecondaryButton("Aportar a una meta", enabled = ledger.goals.any { it.productId == null }) { contributing = true }
            }
        }
        if (creating) GoalForm(store, null) { creating = false }
        editing?.let { g -> GoalForm(store, g) { editing = null } }
        if (contributing) ContributeSheet(store, ledger.goals.filter { it.productId == null }) { contributing = false }
    }
}

@Composable
private fun GoalForm(store: Store, goal: GoalRecord?, onDone: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    var name by remember { mutableStateOf(goal?.name ?: "") }
    var target by remember { mutableStateOf(goal?.targetMinor ?: 0L) }
    var hasDate by remember { mutableStateOf(goal?.targetDate != null) }
    var date by remember { mutableStateOf(goal?.targetDate ?: LocalDate.now().plusMonths(6)) }
    var productId by remember { mutableStateOf(goal?.productId) }
    var menu by remember { mutableStateOf(false) }
    var picking by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }
    FormSheet(if (goal == null) "Nueva meta" else "Editar meta", onDone, canConfirm = name.isNotBlank() && target > 0, onConfirm = {
        store.saveGoal((goal ?: GoalRecord(name = name, targetMinor = target)).copy(name = name.trim(), targetMinor = target, targetDate = if (hasDate) date else null, productId = productId))
        onDone()
    }) {
        Card(padding = Spacing.s2) { FormTextField(name, "Nombre: viaje, emergencias…") { name = it } }
        MoneyField("¿Cuánto quieres juntar?", target) { target = it }
        Card(padding = Spacing.s2) {
            FormToggle("Con fecha", hasDate) { hasDate = it }
            if (hasDate) { FormDivider(); FormRow("Para", "${date.dayOfMonth} ${DueText.months[date.monthValue - 1]} ${date.year}", onClick = { picking = true }) }
        }
        FormGroup(footer = "Si la ligas, lo ahorrado es el saldo de esa cajita.") {
            Box {
                FormRow("Ligada a una cajita", ledger.product(productId)?.name ?: "No, sumo aportes", onClick = { menu = true })
                DropdownMenu(menu, { menu = false }, containerColor = Palette.superficie2) {
                    DropdownMenuItem({ T("No, sumo aportes", Type.cuerpo) }, { productId = null; menu = false })
                    ledger.products.filter { it.kind.earnsYield || it.kind == ProductKind.CUENTA }.forEach { p ->
                        DropdownMenuItem({ T(p.name, Type.cuerpo) }, { productId = p.id; menu = false })
                    }
                }
            }
        }
        if (goal != null) SecondaryButton("Borrar meta", danger = true) { confirm = true }
    }
    if (picking) DatePickDialog(date, { picking = false }) { date = it; picking = false }
    if (confirm && goal != null) AlertDialog(onDismissRequest = { confirm = false }, title = { T("¿Borrar ${goal.name}?", Type.titulo3) },
        confirmButton = { TextButton({ store.deleteGoal(goal.id); confirm = false; onDone() }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
        dismissButton = { TextButton({ confirm = false }) { T("Cancelar", Type.etiqueta) } }, containerColor = Palette.superficie2)
}

@Composable
private fun ContributeSheet(store: Store, goals: List<GoalRecord>, onDone: () -> Unit) {
    var goalId by remember { mutableStateOf(goals.firstOrNull()?.id) }
    var amount by remember { mutableStateOf(AmountInput()) }
    var withdraw by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    OverlaySheet(onDone, Modifier.fillMaxSize().padding(top = 48.dp)) {
        Column(Modifier.weight(1f).padding(horizontal = Spacing.margen).padding(bottom = Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            Row(Modifier.padding(top = Spacing.s4), verticalAlignment = Alignment.CenterVertically) {
                CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onDone)
                T("Aportar", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
                CircleIconButton(Icons.Rounded.Check, "Guardar", filled = true, enabled = amount.money.minor > 0 && goalId != null) {
                    val v = amount.money.minor
                    store.addContribution(ContributionRecord(goalId = goalId!!, amountMinor = if (withdraw) -v else v, occurredAt = LocalDate.now())); onDone()
                }
            }
            Segmented(listOf("a" to "Aportar", "r" to "Retirar"), if (withdraw) "r" else "a") { withdraw = it == "r" }
            Box(Modifier.align(Alignment.CenterHorizontally)) {
                Chip(goals.firstOrNull { it.id == goalId }?.name ?: "Meta") { menu = true }
                DropdownMenu(menu, { menu = false }, containerColor = Palette.superficie2) {
                    goals.forEach { g -> DropdownMenuItem({ T(g.name, Type.cuerpo) }, { goalId = g.id; menu = false }) }
                }
            }
            AmountDisplay(Currency.current.symbol, amount.display, true, empty = amount.text.isEmpty())
            Spacer(Modifier.weight(1f))
            Keypad(amount.allowsDecimals, { amount = amount.press(it) }, { amount = amount.deleteLast() })
        }
    }
}
