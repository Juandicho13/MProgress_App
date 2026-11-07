package com.olarte.mprogress.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.domain.DateStrip
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/**
 * Fecha de Agregar, igual que EasyDatePicker de iOS: una fila con los 7 días de la semana (de lunes a domingo) con hoy marcado en brasa.
 * Se toca un día para elegirlo, se desliza o se usan las flechas para ir a otras semanas (hasta dos años atrás o adelante). El título
 * "noviembre 2026" abre el mes completo, que también se mueve por meses y se cierra al elegir. "Hoy" sale solo si la fecha no es hoy.
 */
@Composable
fun WeekDatePicker(title: String, date: LocalDate, today: LocalDate = LocalDate.now(), startsExpanded: Boolean = false, onPick: (LocalDate) -> Unit) {
    var visible by remember { mutableStateOf(date) }
    var showsMonth by remember { mutableStateOf(startsExpanded) }
    var drag by remember { mutableFloatStateOf(0f) }
    val threshold = with(LocalDensity.current) { 40.dp.toPx() }
    LaunchedEffect(date) { visible = date }

    fun pick(day: LocalDate) {
        val chosen = DateStrip.clamp(day, today)
        visible = chosen
        showsMonth = false
        onPick(chosen)
    }

    fun shift(step: Int) {
        if (showsMonth) { if (DateStrip.canShiftMonth(visible, step, today)) visible = DateStrip.shiftMonth(visible, step) }
        else if (DateStrip.canShiftWeek(visible, step, today)) visible = DateStrip.shiftWeek(visible, step)
    }

    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
            Column(
                Modifier.weight(1f).heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo))
                    .clickable(onClickLabel = if (showsMonth) "Cerrar el mes" else "Abrir el mes completo") { showsMonth = !showsMonth }
                    .semantics(mergeDescendants = true) { contentDescription = "$title, ${DateStrip.spokenDate(date)}" },
                verticalArrangement = Arrangement.Center,
            ) {
                T(title, Type.leyenda, Palette.texto2)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    T(DateStrip.monthLabel(visible), Type.titulo3)
                    Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(18.dp).rotate(if (showsMonth) 180f else 0f), tint = Palette.texto2)
                }
            }
            if (date != today) {
                Box(Modifier.heightIn(min = Size.toqueMinimo).clip(CircleShape).clickable(onClickLabel = "Elegir hoy") { pick(today) }.padding(horizontal = Spacing.s3),
                    contentAlignment = Alignment.Center) { T("Hoy", Type.etiqueta, Palette.brasaTinta) }
            }
            val unit = if (showsMonth) "Mes" else "Semana"
            listOf(-1, 1).forEach { step ->
                val enabled = if (showsMonth) DateStrip.canShiftMonth(visible, step, today) else DateStrip.canShiftWeek(visible, step, today)
                Box(Modifier.size(width = 40.dp, height = Size.toqueMinimo).clip(CircleShape).clickable(enabled = enabled) { shift(step) }
                    .semantics { contentDescription = if (step < 0) "$unit anterior" else "$unit siguiente" }.alpha(if (enabled) 1f else 0.3f),
                    contentAlignment = Alignment.Center) {
                    Icon(if (step < 0) Icons.Rounded.ChevronLeft else Icons.Rounded.ChevronRight, null, Modifier.size(22.dp), tint = Palette.texto1)
                }
            }
        }
        Column(Modifier.pointerInput(Unit) {
            detectHorizontalDragGestures(onDragStart = { drag = 0f }, onDragEnd = {
                if (drag < -threshold) shift(1) else if (drag > threshold) shift(-1)
                drag = 0f
            }) { _, amount -> drag += amount }
        }) {
            AnimatedVisibility(!showsMonth, enter = fadeIn(), exit = fadeOut()) {
                Row(Modifier.fillMaxWidth()) {
                    DateStrip.week(visible).forEachIndexed { i, day ->
                        DayCell(day, DateStrip.weekdayInitials[i], day == date, day == today, true, DateStrip.isSelectable(day, today), Modifier.weight(1f)) { pick(day) }
                    }
                }
            }
            AnimatedVisibility(showsMonth, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                Column {
                    Row(Modifier.fillMaxWidth()) {
                        DateStrip.weekdayInitials.forEach { Box(Modifier.weight(1f).heightIn(min = 24.dp), contentAlignment = Alignment.Center) { T(it, Type.leyenda, Palette.texto2) } }
                    }
                    DateStrip.monthGrid(visible).chunked(7).forEach { week ->
                        Row(Modifier.fillMaxWidth()) {
                            week.forEach { cell ->
                                DayCell(cell.date, null, cell.date == date, cell.date == today, cell.inMonth, DateStrip.isSelectable(cell.date, today), Modifier.weight(1f)) { pick(cell.date) }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Un día: inicial (solo en la semana) y número; elegido en brasa, hoy con borde brasa, los de otros meses en gris. */
@Composable
private fun DayCell(day: LocalDate, initial: String?, selected: Boolean, today: Boolean, inMonth: Boolean, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val spoken = DateStrip.spokenDate(day)
    Column(
        modifier.heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).clickable(enabled = enabled, onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = if (today) "Hoy, $spoken" else spoken; this.selected = selected }
            .alpha(if (!enabled) 0.25f else if (inMonth) 1f else 0.55f),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
    ) {
        if (initial != null) T(initial, Type.leyenda, Palette.texto2)
        Box(
            Modifier.size(36.dp).clip(CircleShape).background(if (selected) Palette.brasa else Color.Transparent)
                .let { if (today && !selected) it.border(1.5.dp, Palette.brasa, CircleShape) else it },
            contentAlignment = Alignment.Center,
        ) {
            val color = when { selected -> Palette.sobreBrasa; today -> Palette.brasaTinta; inMonth -> Palette.texto1; else -> Palette.texto2 }
            T("${day.dayOfMonth}", Type.cuerpo2.copy(fontWeight = if (selected || today) FontWeight.SemiBold else FontWeight.Normal), color)
        }
    }
}
