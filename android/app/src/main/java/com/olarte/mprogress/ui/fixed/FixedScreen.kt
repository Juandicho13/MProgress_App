package com.olarte.mprogress.ui.fixed

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.CallMade
import androidx.compose.material.icons.automirrored.rounded.CallReceived
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.FixedMath
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.RecurringRecord
import com.olarte.mprogress.ui.components.BackButton
import com.olarte.mprogress.ui.components.Badge
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.EmptyState
import com.olarte.mprogress.ui.components.EntryRow
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.components.signedAmount
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Pagos fijos, igual que FixedView de iOS: total al mes y listas Falta la fecha, Gastos e Ingresos. */
@Composable
fun FixedScreen(store: Store, onBack: () -> Unit, onAdd: (EntryKind) -> Unit, onEdit: (String) -> Unit = {}) {
    val ledger by store.ledger.collectAsState()
    val today = LocalDate.now()
    val items = ledger.recurring.filter { it.cycle != Cycle.Puntual }.sortedBy { it.nextDate }
    val totals = FixedMath.totals(items)
    val withoutDate = items.filter { it.dateUnset && it.active && !it.finished }
    val expenses = items.filter { it.kind == EntryKind.GASTO && !(it.dateUnset && it.active) && !it.finished }
    val incomes = items.filter { it.kind == EntryKind.INGRESO && !(it.dateUnset && it.active) && !it.finished }
    val done = items.filter { it.finished }
    var menu by remember { mutableStateOf(false) }
    var paying by remember { mutableStateOf<RecurringRecord?>(null) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BackButton("Volver a Inicio", onBack)
            Spacer(Modifier.weight(1f))
            Box(Modifier.padding(top = Spacing.s2)) {
                Box(Modifier.size(Size.toqueMinimo).clip(CircleShape).background(Palette.brasa).clickable { menu = true }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Add, "Agregar pago fijo", Modifier.size(22.dp), tint = Palette.sobreBrasa)
                }
                DropdownMenu(menu, { menu = false }, containerColor = Palette.superficie2) {
                    DropdownMenuItem({ T("Gasto fijo", Type.cuerpo) }, { menu = false; onAdd(EntryKind.GASTO) },
                        leadingIcon = { Icon(Icons.AutoMirrored.Rounded.CallMade, null, tint = Palette.texto1) })
                    DropdownMenuItem({ T("Ingreso fijo", Type.cuerpo) }, { menu = false; onAdd(EntryKind.INGRESO) },
                        leadingIcon = { Icon(Icons.AutoMirrored.Rounded.CallReceived, null, tint = Palette.texto1) })
                }
            }
        }
        Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                T("Al mes se te van", Type.cuerpo2, Palette.texto2)
                T(Money(totals.expenseMinor).formatted(), Type.cifraGrande)
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    if (totals.incomeMinor > 0) T("Te llegan ${Money(totals.incomeMinor).formatted()}", Type.leyenda, Palette.hielo)
                    if (totals.paused > 0) T("${totals.paused} pausado${if (totals.paused == 1) "" else "s"}", Type.leyenda, Palette.texto2)
                }
            }
        }
        if (items.isEmpty()) {
            Card {
                EmptyState("Sin pagos fijos", "Arriendo, servicios, suscripciones o tu sueldo. Los agregas una vez y la app te avisa cada mes.",
                    art = { IconTile(Icons.Rounded.Repeat, Palette.brasaVelo, Palette.brasaTinta, size = 64.dp) },
                    actions = { PrimaryButton("Agregar pago fijo") { onAdd(EntryKind.GASTO) } })
            }
        }
        listOf(Triple("Falta la fecha", withoutDate, true), Triple("Gastos", expenses, false), Triple("Ingresos", incomes, false), Triple("Terminados", done, false)).forEach { (title, list, highlight) ->
            if (list.isNotEmpty()) {
                SectionLabel(title)
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        list.forEach { item ->
                            val product = ledger.products.firstOrNull { it.id == item.productId }
                            val paidWith = product?.let { p -> p.last4?.let { "${p.name} ·· $it" } ?: p.name }
                            val subtitle = listOfNotNull(FixedMath.scheduleText(item, today), paidWith).joinToString(" · ")
                            Box(Modifier.alpha(if (item.active && !item.finished) 1f else 0.55f)) {
                                EntryRow(item.name, item.kind, item.amountMinor, subtitle, onClick = { onEdit(item.id) }) {
                                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                        T(signedAmount(item.amountMinor, item.kind), Type.cifra, if (item.kind == EntryKind.INGRESO) Palette.hielo else Palette.texto1)
                                        when {
                                            item.finished -> Badge("Terminado", Palette.superficie3, Palette.texto2)
                                            !item.active -> Badge("Pausado", Palette.superficie3, Palette.texto2)
                                            highlight -> Badge("Poner fecha", Palette.oroRelleno, Palette.sobreOro)
                                            else -> T(DueText.describe(item.nextDate, today), Type.leyenda, Palette.texto2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    paying?.let { item ->
        val income = item.kind == EntryKind.INGRESO
        AlertDialog(
            onDismissRequest = { paying = null },
            title = { T("¿Marcar ${item.name} como ${if (income) "recibido" else "pagado"}?", Type.titulo3) },
            text = { T("Se registra ${Money(item.amountMinor).formatted()} hoy y pasa al siguiente cobro.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ com.olarte.mprogress.ui.home.markPaidWithUndo(store, item.id); paying = null }) { T(if (income) "Marcar recibido" else "Marcar pagado", Type.etiqueta, Palette.brasaTinta) } },
            dismissButton = { TextButton({ paying = null }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}
