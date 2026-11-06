package com.olarte.mprogress.ui.home

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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.BalanceCalculator
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.QuickActionKind
import com.olarte.mprogress.domain.Urgency
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Inicio (pantalla 7): Te quedan, barra del mes, accesos rápidos y próximos cargos. */
@Composable
fun HomeScreen(store: Store, onAction: (QuickActionKind) -> Unit, onMore: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val actions by store.actions.collectAsState()
    val today = LocalDate.now()
    val summary = BalanceCalculator.monthSummary(ledger.entries, ledger.recurring, today)
    val upcoming = BalanceCalculator.upcoming(ledger.recurring, today, limit = 5)
    val recent = ledger.entries.sortedByDescending { it.occurredAt }.take(5)

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
            .padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        Column {
            T("Te quedan en ${DueText.monthName(today)}", Type.cuerpo, Palette.texto2)
            T(Money(summary.remainingMinor).formatted(), Type.cifra, if (summary.remainingMinor < 0) Palette.peligro else Palette.texto1)
            Spacer(Modifier.height(Spacing.s3))
            Box(Modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Palette.superficie3)) {
                Box(Modifier.fillMaxWidth(summary.spentRatio.toFloat().coerceAtLeast(0.02f)).height(8.dp).clip(CircleShape).background(Palette.brasa))
            }
            Spacer(Modifier.height(Spacing.s2))
            T("Gastado ${Money(summary.spentMinor).formatted()} · faltan ${summary.daysLeft} días", Type.cuerpo2, Palette.texto2)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            actions.pinned.forEachIndexed { i, kind ->
                QuickButton(kind.glyph, kind.shortTitle, primary = i == 0, Modifier.weight(1f)) { onAction(kind) }
            }
            QuickButton("⋯", "Más", false, Modifier.weight(1f), onMore)
        }

        Card {
            T("Próximos cargos", Type.titulo3)
            Spacer(Modifier.height(Spacing.s2))
            if (upcoming.isEmpty()) T("No tienes pagos fijos pendientes.", Type.cuerpo2, Palette.texto2)
            upcoming.forEach { c ->
                val color = when (c.urgency) { Urgency.HOY -> Palette.brasa; Urgency.PRONTO -> Palette.oroRelleno; else -> Palette.superficie3 }
                val fg = when (c.urgency) { Urgency.HOY -> Palette.sobreBrasa; Urgency.PRONTO -> Palette.sobreOro; else -> Palette.texto1 }
                ListRow("↻", c.name, DueText.describe(c.date, today), color, fg) {
                    Column(horizontalAlignment = Alignment.End) {
                        T(Money(c.amountMinor).formatted(), Type.titulo3)
                        T("Pagado", Type.etiqueta, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { store.markPaid(c.recurringId) }.padding(4.dp))
                    }
                }
            }
        }

        if (recent.isEmpty()) {
            Card {
                T("Anota tu primer gasto", Type.titulo3)
                T("Toca Gasto, escribe el monto y listo. Lo demás es opcional.", Type.cuerpo2, Palette.texto2)
                Spacer(Modifier.height(Spacing.s3))
                PrimaryButton("Agregar gasto") { onAction(QuickActionKind.GASTO) }
            }
        } else {
            Card {
                T("Últimos movimientos", Type.titulo3)
                recent.forEach { e ->
                    val income = e.kind == EntryKind.INGRESO
                    ListRow(if (income) "↓" else "↑", e.name.ifBlank { if (income) "Ingreso" else "Gasto" }, DueText.describe(e.occurredAt, today)) {
                        T((if (income) Money(e.amountMinor) else Money(-e.amountMinor)).formatted(sign = income), Type.titulo3, if (income) Palette.exito else Palette.texto1)
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickButton(glyph: String, title: String, primary: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.heightIn(min = 76.dp).clip(RoundedCornerShape(Radius.boton))
            .background(if (primary) Palette.brasa else Palette.superficie1).clickable(onClick = onClick).padding(vertical = Spacing.s3),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        val fg = if (primary) Palette.sobreBrasa else Palette.texto1
        T(glyph, Type.titulo2, fg)
        T(title, Type.etiqueta, fg, maxLines = 1)
    }
}
