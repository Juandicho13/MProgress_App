package com.olarte.mprogress.ui.history

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.History
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.EntryRecord
import com.olarte.mprogress.domain.HistoryMath
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.ui.components.BackButton
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.EmptyState
import com.olarte.mprogress.ui.components.EntryRow
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SearchField
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate
import java.time.YearMonth

/** Historial (pantalla 11) por mes con total y buscador, igual que HistoryView de iOS. Tocar uno permite borrarlo. */
@Composable
fun HistoryScreen(store: Store, onAdd: () -> Unit = {}, onOpenEntry: ((String) -> Unit)? = null, onBack: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val cloudUi = com.olarte.mprogress.ui.home.rememberCloudUi()
    var query by remember { mutableStateOf("") }
    var deleting by remember { mutableStateOf<EntryRecord?>(null) }
    val today = LocalDate.now()
    val filtered = HistoryMath.filter(ledger.entries, query) { com.olarte.mprogress.domain.Categories.byId(it)?.name }
    val months = filtered.groupBy { YearMonth.from(it.occurredAt) }.toSortedMap(compareByDescending { it })

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        BackButton("Volver a Inicio", onBack)
        T("Historial", Type.titulo1)
        if (ledger.entries.isEmpty()) {
            Card {
                EmptyState("Tu historial está vacío", "Cada gasto o ingreso que registres queda aquí, ordenado por mes.",
                    art = { IconTile(Icons.Rounded.History, Palette.brasaVelo, Palette.brasaTinta, size = 64.dp) },
                    actions = { PrimaryButton("Agregar movimiento", onClick = onAdd) })
            }
        } else {
            SearchField(query, "Buscar por nombre, categoría o monto") { query = it }
            if (months.isEmpty()) T("Nada coincide con “$query”.", Type.cuerpo, Palette.texto2, Modifier.padding(top = Spacing.s4))
            months.forEach { (month, items) ->
                val income = items.filter { it.kind == EntryKind.INGRESO }.sumOf { it.amountMinor }
                val spent = items.filter { it.kind == EntryKind.GASTO }.sumOf { it.amountMinor }
                val net = income - spent
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        val name = DueText.monthName(month.atDay(1)).replaceFirstChar { it.uppercase() }
                        T(if (month.year == today.year) name else "$name ${month.year}", Type.titulo2, modifier = Modifier.weight(1f))
                        T(Money(net).formatted(sign = true), Type.cifra, if (net < 0) Palette.texto1 else Palette.hielo)
                    }
                    T("Entró ${Money(income).formatted()} · salió ${Money(spent).formatted()}", Type.cuerpo2, Palette.texto2)
                    Card(padding = Spacing.s3) {
                        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                            HistoryMath.days(items).forEach { day ->
                                Column(Modifier.padding(top = Spacing.s2)) {
                                    SectionLabel(when (day.day) { today -> "Hoy"; today.minusDays(1) -> "Ayer"; else -> DueText.shortDate(day.day, today) })
                                }
                                day.entries.forEach { e ->
                                    val sub = listOfNotNull(com.olarte.mprogress.domain.Categories.byId(e.categoryId)?.name, if (e.recurringId != null) "Pago fijo" else null).joinToString(" · ").ifEmpty { "Sin categoría" }
                                    EntryRow(e.name, e.kind, e.amountMinor, sub, onClick = { if (onOpenEntry != null) onOpenEntry(e.id) else deleting = e },
                                        pending = cloudUi?.showsPendingMark(e.id) == true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    deleting?.let { e ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { T("¿Borrar este movimiento?", Type.titulo3) },
            text = { T("${e.name.ifBlank { "Movimiento" }} · ${Money(e.amountMinor).formatted()}", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ store.deleteEntry(e.id); deleting = null }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ deleting = null }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}
