package com.olarte.mprogress.ui.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.CalendarMath
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate
import java.time.YearMonth

/** Calendario (pantalla 11): el mes con puntos en los días con gastos y cobros, y el detalle del día elegido. */
@Composable
fun CalendarScreen(store: Store) {
    val ledger by store.ledger.collectAsState()
    val today = LocalDate.now()
    var month by remember { mutableStateOf(YearMonth.from(today)) }
    var selected by remember { mutableStateOf(today) }
    val days = CalendarMath.days(month, ledger.entries, ledger.recurring, today)
    val pending = days.values.sumOf { it.pendingMinor }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T("‹", Type.titulo1, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { month = month.minusMonths(1) }.padding(horizontal = Spacing.s3))
            T("${DueText.monthNames[month.monthValue - 1].replaceFirstChar { it.uppercase() }} ${month.year}", Type.titulo1, modifier = Modifier.weight(1f), align = androidx.compose.ui.text.style.TextAlign.Center)
            T("›", Type.titulo1, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { month = month.plusMonths(1) }.padding(horizontal = Spacing.s3))
        }
        T("Por pagar este mes: ${Money(pending).formatted()}", Type.cuerpo2, Palette.texto2)
        Card(padding = Spacing.s3) {
            Row { CalendarMath.weekdays.forEach { T(it, Type.leyenda, Palette.texto2, Modifier.weight(1f), align = androidx.compose.ui.text.style.TextAlign.Center) } }
            Spacer(Modifier.height(Spacing.s2))
            CalendarMath.grid(month).chunked(7).forEach { week ->
                Row {
                    week.forEach { date ->
                        Box(Modifier.weight(1f).aspectRatio(1f).padding(2.dp), contentAlignment = Alignment.Center) {
                            if (date != null) {
                                val info = days[date]
                                val isSel = date == selected
                                Column(
                                    Modifier.fillMaxSize().clip(CircleShape).background(if (isSel) Palette.brasa else Color.Transparent)
                                        .border(1.5.dp, if (date == today && !isSel) Palette.brasa else Color.Transparent, CircleShape)
                                        .clickable { selected = date },
                                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                                ) {
                                    T("${date.dayOfMonth}", Type.etiqueta, if (isSel) Palette.sobreBrasa else Palette.texto1)
                                    Box(Modifier.size(5.dp).clip(CircleShape).background(when {
                                        info == null -> Color.Transparent
                                        isSel -> Palette.sobreBrasa
                                        info.charges.isNotEmpty() -> Palette.oroRelleno
                                        info.hasExpense -> Palette.brasa
                                        else -> Palette.exito
                                    }))
                                }
                            }
                        }
                    }
                    repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        val info = days[selected]
        Card {
            T(DueText.describe(selected, today) + " · " + DueText.shortDate(selected, today), Type.titulo3)
            if (info == null) T("Nada este día.", Type.cuerpo2, Palette.texto2)
            info?.charges?.forEach { c ->
                ListRow("↻", c.name, "Pago fijo") { T(Money(c.amountMinor).formatted(), Type.titulo3, Palette.oro) }
            }
            info?.entries?.forEach { e ->
                val income = e.kind == EntryKind.INGRESO
                ListRow(if (income) "↓" else "↑", e.name.ifBlank { if (income) "Ingreso" else "Gasto" }, null) {
                    T((if (income) Money(e.amountMinor) else Money(-e.amountMinor)).formatted(sign = income), Type.titulo3, if (income) Palette.exito else Palette.texto1)
                }
            }
        }
    }
}
