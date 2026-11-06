package com.olarte.mprogress.ui.summary

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
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
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.FixedMath
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.SummaryMath
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Resumen (pantalla 10): seis meses de entradas y salidas, comparación con el mes pasado, mes normal y lo que viene. */
@Composable
fun SummaryScreen(store: Store) {
    val ledger by store.ledger.collectAsState()
    val today = LocalDate.now()
    val flows = SummaryMath.flows(ledger.entries, today)
    val (now, last) = SummaryMath.versusLastMonth(ledger.entries, today)
    val normal = SummaryMath.normalMonth(ledger.entries, today)
    val (nextIncome, nextExpense) = SummaryMath.nextMonth(ledger.recurring, today)
    val fixed = FixedMath.totals(ledger.recurring)
    val max = flows.maxOf { maxOf(it.incomeMinor, it.spentMinor) }.coerceAtLeast(1)

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        T("Resumen", Type.titulo1)
        Card {
            T("Últimos 6 meses", Type.titulo3)
            Spacer(Modifier.height(Spacing.s3))
            Row(Modifier.fillMaxWidth().height(150.dp), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.Bottom) {
                flows.forEach { f ->
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Row(Modifier.height(120.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            Bar(f.incomeMinor.toFloat() / max, Palette.exito)
                            Bar(f.spentMinor.toFloat() / max, Palette.brasa)
                        }
                        Spacer(Modifier.height(Spacing.s1))
                        T(DueText.months[f.month.monthValue - 1], Type.leyenda, Palette.texto2)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                Legend("Entró", Palette.exito); Legend("Salió", Palette.brasa)
            }
        }
        Card {
            T("Este mes vs el pasado", Type.cuerpo2, Palette.texto2)
            T(Money(now).formatted(), Type.titulo2)
            val diff = now - last
            T(when {
                last == 0L -> "El mes pasado a esta altura no tenías gastos."
                diff > 0 -> "Llevas ${Money(diff).formatted()} más que el mes pasado a esta altura."
                diff < 0 -> "Llevas ${Money(-diff).formatted()} menos que el mes pasado a esta altura."
                else -> "Vas igual que el mes pasado."
            }, Type.cuerpo2, if (diff > 0) Palette.oro else Palette.exito)
        }
        Card {
            T("Tu mes normal", Type.cuerpo2, Palette.texto2)
            T(normal?.let { Money(it).formatted() } ?: "Aún no hay datos", Type.titulo2)
            T("Es la mitad de tus meses: unos gastas más, otros menos.", Type.cuerpo2, Palette.texto2)
        }
        Card {
            T("El mes que viene", Type.cuerpo2, Palette.texto2)
            T("Entran ${Money(nextIncome).formatted()}", Type.titulo3, Palette.exito)
            T("Salen ${Money(nextExpense).formatted()} en fijos", Type.titulo3)
            T("Tus fijos pesan ${Money(fixed.expenseMinor).formatted()} al mes.", Type.cuerpo2, Palette.texto2)
        }
    }
}

@Composable
private fun Bar(ratio: Float, color: androidx.compose.ui.graphics.Color) {
    Box(Modifier.width(12.dp).fillMaxHeight(ratio.coerceIn(0.02f, 1f)).clip(RoundedCornerShape(4.dp)).background(color))
}

@Composable
private fun Legend(text: String, color: androidx.compose.ui.graphics.Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.width(10.dp).height(10.dp).clip(RoundedCornerShape(3.dp)).background(color))
        T("  $text", Type.leyenda, Palette.texto2)
    }
}
