package com.olarte.mprogress.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.material.icons.outlined.CloudOff
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.QuestionMark
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
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
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.BalanceCalculator
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.Forecast
import com.olarte.mprogress.domain.IncomeCheck
import com.olarte.mprogress.domain.RecurringRecord
import com.olarte.mprogress.domain.UpcomingFold
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.QuickActionKind
import com.olarte.mprogress.domain.UpcomingCharge
import com.olarte.mprogress.domain.Urgency
import com.olarte.mprogress.ui.components.Avatar
import com.olarte.mprogress.ui.components.Badge
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.CircleIconButton
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.Sym
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Inicio (pantalla 1) e Inicio vacío (38), igual que en iOS. */
@Composable
fun HomeScreen(store: Store, onAction: (QuickActionKind) -> Unit, onMore: () -> Unit, onOpenFixed: () -> Unit, onOpenHistory: () -> Unit, onOpenEntry: (String) -> Unit = {}) {
    val ledger by store.ledger.collectAsState()
    val actions by store.actions.collectAsState()
    val currency by store.currency.collectAsState()
    val checkedIncomes by store.checkedIncomes.collectAsState()
    val upcomingExpanded by store.upcomingExpanded.collectAsState()
    var charge by remember { mutableStateOf<UpcomingCharge?>(null) }
    var payingId by remember { mutableStateOf<String?>(null) }
    val today = LocalDate.now()
    val active = ledger.recurring.filter { it.active }
    val summary = BalanceCalculator.monthSummary(ledger.entries, active, today)
    // Todos los próximos cargos (hasta 20); la tarjeta muestra 3 si está cerrada.
    val upcoming = BalanceCalculator.upcoming(active, today, kind = null, limit = UpcomingFold.EXPANDED_LIMIT)
    val suspicious = IncomeCheck.suspicious(active, currency, checkedIncomes)
    val staleEntries = IncomeCheck.staleEntries(ledger.entries, active, currency, checkedIncomes)
    val recent = ledger.entries.sortedByDescending { it.occurredAt }.take(5)
    val isEmpty = ledger.entries.isEmpty() && active.isEmpty()

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
            .padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = Size.barra + Spacing.s8 + Spacing.s4),
        verticalArrangement = Arrangement.spacedBy(Spacing.s6),
    ) {
        // Encabezado: espacio y campana.
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.clip(CircleShape).background(Palette.superficie1).padding(start = 6.dp, top = 6.dp, bottom = 6.dp, end = Spacing.s4),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2),
            ) {
                Avatar("Personal", 32.dp)
                T("Personal", Type.titulo3)
                Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(16.dp), tint = Palette.texto2)
            }
            Spacer(Modifier.weight(1f))
            CircleIconButton(Sym.bell, "Avisos") { }
        }

        SyncPill()

        // Te quedan.
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            T("Te quedan en ${DueText.monthName(today)}", Type.cuerpo2, Palette.texto2)
            T(Money(summary.remainingMinor).formatted(), Type.cifraHeroe,
                if (isEmpty) Palette.texto2 else if (summary.remainingMinor < 0) Palette.peligro else Palette.texto1, maxLines = 1)
            if (isEmpty) {
                T("Agrega tu ingreso para calcularlo", Type.titulo3, Palette.brasaTinta,
                    Modifier.heightIn(min = Size.toqueMinimo).clickable { onAction(QuickActionKind.SUELDO) }.padding(vertical = Spacing.s3))
            } else {
                Box(Modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Palette.superficie3)) {
                    Box(Modifier.fillMaxWidth(summary.spentRatio.toFloat().coerceAtLeast(0.02f)).height(8.dp).clip(CircleShape).background(Palette.brasa))
                }
                T("Gastado ${Money(summary.spentMinor).formatted()} de ${Money(summary.expectedIncomeMinor).formatted()} · faltan ${summary.daysLeft} días", Type.cuerpo2, Palette.texto2)
                // PLAN_F12B Paso 4, sin predicciones: la línea roja solo sale si Te quedan ya es negativo.
                Forecast.overText(summary.remainingMinor, currency)?.let { alert ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                        Icon(Icons.Rounded.Warning, null, Modifier.size(16.dp), tint = Palette.peligro)
                        T(alert, Type.cuerpo2, Palette.peligro)
                    }
                }
            }
        }

        // Accesos rápidos.
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            actions.pinned.forEachIndexed { i, kind ->
                QuickButton(Sym.of(kind), kind.shortTitle, primary = i == 0, Modifier.weight(1f)) { onAction(kind) }
            }
            QuickButton(Sym.more, "Más", false, Modifier.weight(1f), onMore)
        }

        if (isEmpty) {
            Card {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    EmptyArt()
                    T("Empieza con un gasto", Type.titulo3)
                    T("Anota lo que pagas y te digo cuánto te queda en el mes.", Type.cuerpo2, Palette.texto2, align = androidx.compose.ui.text.style.TextAlign.Center)
                    com.olarte.mprogress.ui.components.PrimaryButton("Agregar gasto") { onAction(QuickActionKind.GASTO) }
                }
            }
        } else {
            suspicious.forEach { r -> IncomeCheckCard(store, r, ledger.entries) }
            staleEntries.forEach { stale -> StaleEntryCard(store, stale) }
            if (upcoming.isNotEmpty()) {
                Card {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T("Próximos cargos", Type.titulo3, modifier = Modifier.weight(1f))
                        T("Pagos fijos", Type.etiqueta, Palette.brasaTinta, Modifier.heightIn(min = Size.toqueMinimo).clickable(onClick = onOpenFixed).padding(vertical = 15.dp, horizontal = 4.dp))
                    }
                    UpcomingFold.visible(upcoming, upcomingExpanded).forEach { c ->
                        val income = c.kind == EntryKind.INGRESO
                        val cycle = ledger.recurring.firstOrNull { it.id == c.recurringId }?.cycle?.title.orEmpty()
                        ListRow(c.name, title = c.name, subtitle = "${DueText.describe(c.date, today)} · $cycle",
                            tint = if (income) Palette.hieloVelo else Palette.superficie3, fg = if (income) Palette.hielo else Palette.texto1,
                            onClick = { charge = c }) {
                            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                T((if (income) "+ " else "") + Money(c.amountMinor).formatted(), Type.cifra, if (income) Palette.hielo else Palette.texto1)
                                when (c.urgency) {
                                    Urgency.HOY -> Badge("Hoy", Palette.peligroVelo, Palette.peligro)
                                    Urgency.PRONTO -> Badge("Pronto", Palette.oroRelleno, Palette.sobreOro)
                                    else -> {}
                                }
                            }
                        }
                    }
                    UpcomingFold.toggleTitle(upcoming.size, upcomingExpanded)?.let { toggle ->
                        Row(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.boton))
                            .clickable { store.setUpcomingExpanded(!upcomingExpanded) },
                            horizontalArrangement = Arrangement.spacedBy(Spacing.s1, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                            T(toggle, Type.etiqueta, Palette.brasaTinta)
                            Icon(if (upcomingExpanded) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown, null, Modifier.size(16.dp), tint = Palette.brasaTinta)
                        }
                    }
                }
            } else if (active.isNotEmpty()) {
                Card {
                    ListRow(icon = Sym.repeat, title = "Pagos fijos", subtitle = "${active.size} ${if (active.size == 1) "pago" else "pagos"} · nada por cobrar pronto",
                        tint = Palette.brasaVelo, fg = Palette.brasaTinta, chevron = true, onClick = onOpenFixed)
                }
            }
            if (recent.isNotEmpty()) {
                Card {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T("Movimientos", Type.titulo3, modifier = Modifier.weight(1f))
                        T("Ver todo", Type.etiqueta, Palette.brasaTinta, Modifier.heightIn(min = Size.toqueMinimo).clickable(onClick = onOpenHistory).padding(vertical = 15.dp, horizontal = 4.dp))
                    }
                    recent.forEach { e ->
                        val income = e.kind == EntryKind.INGRESO
                        val name = e.name.ifBlank { if (income) "Ingreso" else "Gasto" }
                        ListRow(name, title = name, subtitle = DueText.describe(e.occurredAt, today),
                            tint = if (income) Palette.hieloVelo else Palette.superficie3, fg = if (income) Palette.hielo else Palette.texto1, onClick = { onOpenEntry(e.id) }) {
                            T((if (income) Money(e.amountMinor) else Money(-e.amountMinor)).formatted(sign = income), Type.cifra, if (income) Palette.hielo else Palette.texto1)
                        }
                    }
                }
            }
        }
    }

    charge?.let { c ->
        AlertDialog(
            onDismissRequest = { charge = null },
            title = { T(c.name, Type.titulo3) },
            text = { T("${Money(c.amountMinor).formatted()} · ${DueText.describe(c.date, today)}", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ payingId = c.recurringId; charge = null }) { T(if (c.kind == EntryKind.INGRESO) "Marcar recibido" else "Marcar pagado", Type.etiqueta, Palette.brasaTinta) } },
            dismissButton = { TextButton({ charge = null }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
    payingId?.let { id -> MarkPaidSheet(store, id) { payingId = null } }
}

/** "¿Tu sueldo es $ 2?": arreglo rápido de un ingreso fijo que parece mal escrito (igual que iOS). */
@Composable
private fun IncomeCheckCard(store: Store, r: RecurringRecord, entries: List<com.olarte.mprogress.domain.EntryRecord>) {
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                IconTile(Icons.Rounded.QuestionMark, Palette.oro.copy(alpha = 0.16f), Palette.oro)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    T(IncomeCheck.question(r.name, r.amountMinor), Type.titulo3)
                    T("Parece muy poco para un ingreso fijo. Si le faltaron ceros, arréglalo aquí.", Type.cuerpo2, Palette.texto2)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                IncomeCheck.factors.forEach { factor ->
                    SecondaryButton(IncomeCheck.fixTitle(r.amountMinor, factor)) {
                        val previous = r.amountMinor
                        // También los movimientos ya anotados con ese monto, así "Te quedan" cambia de una vez.
                        val linked = IncomeCheck.entriesToFix(entries, r, previous)
                        store.setRecurringAmount(r.id, previous * factor)
                        store.setEntryAmounts(linked, previous * factor)
                        store.showUndo("${r.name} quedó en ${Money(previous * factor).formatted()}") {
                            store.setRecurringAmount(r.id, previous)
                            store.setEntryAmounts(linked, previous)
                        }
                    }
                }
                SecondaryButton("Sí, es correcto") { store.markIncomeChecked(r.id) }
            }
        }
    }
}

/** "Tu movimiento Sueldo sigue en $ 2": se arregla igual que el pago fijo (igual que iOS). */
@Composable
private fun StaleEntryCard(store: Store, stale: IncomeCheck.StaleEntry) {
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                IconTile(Icons.Rounded.QuestionMark, Palette.oro.copy(alpha = 0.16f), Palette.oro)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    T("Tu movimiento ${stale.name} sigue en ${Money(stale.amountMinor).formatted()}", Type.titulo3)
                    T("En Pagos fijos ya quedó en ${Money(stale.fixedAmountMinor).formatted()}. ¿Lo cambiamos también aquí?", Type.cuerpo2, Palette.texto2)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                SecondaryButton("Cambiar a ${Money(stale.fixedAmountMinor).formatted()}") {
                    store.setEntryAmounts(listOf(stale.entryId), stale.fixedAmountMinor)
                    store.showUndo("${stale.name} quedó en ${Money(stale.fixedAmountMinor).formatted()}") {
                        store.setEntryAmounts(listOf(stale.entryId), stale.amountMinor)
                    }
                }
                SecondaryButton("Dejarlo así") { store.markIncomeChecked(stale.entryId) }
            }
        }
    }
}

@Composable
private fun QuickButton(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, primary: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.heightIn(min = 76.dp).clip(RoundedCornerShape(Radius.boton))
            .background(if (primary) Palette.brasa else Palette.superficie1).clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s1, Alignment.CenterVertically),
    ) {
        val fg = if (primary) Palette.sobreBrasa else Palette.texto1
        Icon(icon, null, Modifier.size(22.dp), tint = fg)
        T(title, Type.etiqueta, fg, maxLines = 1)
    }
}

@Composable
private fun EmptyArt() {
    Box(Modifier.size(120.dp, 80.dp)) {
        Box(Modifier.padding(top = 18.dp).size(88.dp, 58.dp).clip(RoundedCornerShape(16.dp)).background(Palette.superficie3))
        Box(Modifier.padding(start = 30.dp).size(88.dp, 58.dp).clip(RoundedCornerShape(16.dp)).background(Palette.brasaVelo)) {
            Box(Modifier.align(Alignment.TopCenter).padding(top = 18.dp).size(40.dp, 6.dp).clip(CircleShape).background(Palette.brasa))
        }
    }
}

/** Pastilla de sincronización (F10): solo con cuenta, sin conexión o con error. "Sin conexión · 3 cambios sin sincronizar". */
@Composable
fun SyncPill() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val cloud = remember { runCatching { com.olarte.mprogress.data.cloud.CloudAccount.get(context) }.getOrNull() } ?: return
    val ui by cloud.ui.collectAsState()
    if (!ui.isSignedIn) return
    val text = com.olarte.mprogress.domain.SyncEngine.pillText(ui.status) ?: return
    Row(Modifier.heightIn(min = 36.dp).clip(CircleShape).background(Palette.vidrioTinte.copy(alpha = 0.78f))
        .androidxBorder().padding(horizontal = Spacing.s4), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        Icon(androidx.compose.material.icons.Icons.Outlined.CloudOff, null, Modifier.size(16.dp), tint = Palette.texto1)
        T(text, Type.etiqueta, maxLines = 1)
    }
}

@Composable
private fun Modifier.androidxBorder() = this.then(Modifier.border(1.dp, Palette.vidrioBorde, CircleShape))
