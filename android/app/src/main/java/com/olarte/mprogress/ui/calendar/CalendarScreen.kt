package com.olarte.mprogress.ui.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.CalendarMath
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.RecurringRecord
import com.olarte.mprogress.ui.components.Badge
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.CircleIconButton
import com.olarte.mprogress.ui.components.EntryRow
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.components.signedAmount
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate
import java.time.YearMonth

/** Calendario (pantalla 12), igual que CalendarView de iOS: puntos por día, detalle del día y marcar pagado. */
@Composable
fun CalendarScreen(store: Store, today: LocalDate = LocalDate.now(), onOpenEntry: (String) -> Unit = {}) {
    val ledger by store.ledger.collectAsState()
    var month by remember { mutableStateOf(YearMonth.from(today)) }
    var selected by remember { mutableStateOf(today) }
    var paying by remember { mutableStateOf<RecurringRecord?>(null) }
    val days = CalendarMath.days(month, ledger.entries, ledger.recurring, today)
    val pending = days.values.sumOf { it.pendingMinor }
    fun move(n: Long) { month = month.plusMonths(n); selected = if (month == YearMonth.from(today)) today else month.atDay(1) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        T("Calendario", Type.titulo1)
        Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CircleIconButton(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, "Mes anterior") { move(-1) }
                    T("${DueText.monthName(month.atDay(1)).replaceFirstChar { it.uppercase() }} ${month.year}", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
                    CircleIconButton(Icons.AutoMirrored.Rounded.KeyboardArrowRight, "Mes siguiente") { move(1) }
                }
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    Row { CalendarMath.weekdays.forEach { T(it, Type.leyenda, Palette.texto2, Modifier.weight(1f), align = TextAlign.Center) } }
                    CalendarMath.grid(month).chunked(7).forEach { week ->
                        Row {
                            week.forEach { date ->
                                Box(Modifier.weight(1f).height(48.dp)) {
                                    if (date != null) {
                                        val info = days[date]
                                        val isSel = date == selected
                                        val isToday = date == today
                                        Column(
                                            Modifier.fillMaxSize().clip(RoundedCornerShape(Radius.campo)).background(if (isSel) Palette.brasa else Color.Transparent)
                                                .border(1.5.dp, if (isToday && !isSel) Palette.brasa else Color.Transparent, RoundedCornerShape(Radius.campo))
                                                .clickable { selected = date },
                                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically),
                                        ) {
                                            T("${date.dayOfMonth}", Type.cuerpo2, if (isSel) Palette.sobreBrasa else if (isToday) Palette.brasaTinta else Palette.texto1)
                                            Row(Modifier.height(5.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                                                if (info?.entries?.any { it.kind == EntryKind.GASTO } == true) Dot(if (isSel) Palette.sobreBrasa else Palette.brasa)
                                                if (info?.entries?.any { it.kind == EntryKind.INGRESO } == true) Dot(Palette.hielo)
                                                if (info?.charges?.isNotEmpty() == true) Dot(Palette.oroRelleno)
                                            }
                                        }
                                    }
                                }
                            }
                            repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.s4, Alignment.CenterHorizontally)) {
                    Legend(Palette.brasa, "Gasto"); Legend(Palette.hielo, "Ingreso"); Legend(Palette.oroRelleno, "Por pagar")
                }
            }
        }
        if (pending > 0) T("Faltan por pagar ${Money(pending).formatted()} este mes", Type.cuerpo2, Palette.texto2)
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            T(when (selected) { today -> "Hoy"; today.plusDays(1) -> "Mañana"; today.minusDays(1) -> "Ayer"; else -> "${selected.dayOfMonth} de ${DueText.monthName(selected)}" }, Type.titulo3)
            val info = days[selected]
            if (info == null || (info.entries.isEmpty() && info.charges.isEmpty())) {
                Card { T("Nada registrado ni por pagar este día.", Type.cuerpo2, Palette.texto2) }
            } else {
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        info.charges.forEach { c ->
                            val item = ledger.recurring.firstOrNull { it.id == c.recurringId }
                            val isNext = item?.nextDate == c.date
                            EntryRow(c.name, c.kind, c.amountMinor, "${DueText.describe(c.date, today)} · ${item?.cycle?.title.orEmpty()}") {
                                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    T(signedAmount(c.amountMinor, c.kind), Type.cifra, if (c.kind == EntryKind.INGRESO) Palette.hielo else Palette.texto1)
                                    if (isNext) T(if (c.kind == EntryKind.INGRESO) "Recibido" else "Pagar", Type.etiqueta, Palette.brasaTinta,
                                        Modifier.heightIn(min = 32.dp).clip(CircleShape).clickable { paying = item }.padding(horizontal = 4.dp, vertical = 6.dp))
                                    else Badge("Programado", Palette.superficie3, Palette.texto2)
                                }
                            }
                        }
                        info.entries.forEach { e -> EntryRow(e.name, e.kind, e.amountMinor, "Registrado", onClick = { onOpenEntry(e.id) }) }
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

@Composable
private fun Dot(color: Color) = Box(Modifier.size(5.dp).clip(CircleShape).background(color))

@Composable
private fun Legend(color: Color, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color)); T(title, Type.leyenda, Palette.texto2)
    }
}
