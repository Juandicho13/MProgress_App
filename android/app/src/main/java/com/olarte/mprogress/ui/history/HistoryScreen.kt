package com.olarte.mprogress.ui.history

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.EntryRecord
import com.olarte.mprogress.domain.HistoryMath
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Historial (pantalla 17): búsqueda y movimientos por día. Tocar uno permite borrarlo. */
@Composable
fun HistoryScreen(store: Store, onBack: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    var query by remember { mutableStateOf("") }
    var deleting by remember { mutableStateOf<EntryRecord?>(null) }
    val today = LocalDate.now()
    val days = HistoryMath.days(HistoryMath.filter(ledger.entries, query))

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        T("‹ Inicio", Type.etiqueta, Palette.brasaTinta, Modifier.padding(top = Spacing.s4).clip(CircleShape).clickable(onClick = onBack).padding(4.dp))
        T("Historial", Type.titulo1)
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(Spacing.s4)) {
            if (query.isEmpty()) T("Buscar por nombre o monto", Type.cuerpo, Palette.texto2)
            BasicTextField(query, { query = it }, Modifier.fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true)
        }
        if (days.isEmpty()) T(if (query.isBlank()) "Todavía no hay movimientos." else "Nada coincide con \"$query\".", Type.cuerpo2, Palette.texto2)
        days.forEach { day ->
            Card {
                Row {
                    T(DueText.describe(day.day, today), Type.titulo3, modifier = Modifier.weight(1f))
                    T(Money(day.netMinor).formatted(sign = true), Type.etiqueta, Palette.texto2)
                }
                day.entries.forEach { e ->
                    val income = e.kind == EntryKind.INGRESO
                    ListRow(if (income) "↓" else "↑", e.name.ifBlank { if (income) "Ingreso" else "Gasto" }, null, onClick = { deleting = e }) {
                        T((if (income) Money(e.amountMinor) else Money(-e.amountMinor)).formatted(sign = income), Type.titulo3, if (income) Palette.exito else Palette.texto1)
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
