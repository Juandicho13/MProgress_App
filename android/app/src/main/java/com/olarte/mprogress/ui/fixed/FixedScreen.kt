package com.olarte.mprogress.ui.fixed

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.FixedMath
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Pagos fijos: total al mes, los que faltan por fecha y cada uno con su próximo cobro. */
@Composable
fun FixedScreen(store: Store, onBack: () -> Unit, onAdd: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val today = LocalDate.now()
    val totals = FixedMath.totals(ledger.recurring)
    val items = ledger.recurring.sortedWith(compareBy({ it.dateUnset }, { it.nextDate }))

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        T("‹ Inicio", Type.etiqueta, Palette.brasaTinta, Modifier.padding(top = Spacing.s4).clip(CircleShape).clickable(onClick = onBack).padding(4.dp))
        T("Pagos fijos", Type.titulo1)
        Card {
            T("Al mes", Type.cuerpo2, Palette.texto2)
            T("${Money(totals.expenseMinor).formatted()} en gastos", Type.titulo2)
            T("${Money(totals.incomeMinor).formatted()} en ingresos", Type.cuerpo, Palette.exito)
            if (totals.withoutDate > 0) T("${totals.withoutDate} todavía sin fecha.", Type.cuerpo2, Palette.oro)
        }
        Card {
            if (items.isEmpty()) T("Aún no tienes pagos fijos.", Type.cuerpo2, Palette.texto2)
            items.forEach { r ->
                val income = r.kind == EntryKind.INGRESO
                ListRow(if (income) "↓" else "↻", r.name, FixedMath.scheduleText(r.cycle, r.nextDate, r.dateUnset, today)) {
                    Column(horizontalAlignment = Alignment.End) {
                        T(Money(r.amountMinor).formatted(), Type.titulo3, if (income) Palette.exito else Palette.texto1)
                        if (!r.dateUnset) T("Pagado", Type.etiqueta, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { store.markPaid(r.id) }.padding(4.dp))
                    }
                }
            }
        }
        SecondaryButton("Agregar pago fijo", onClick = onAdd)
    }
}
