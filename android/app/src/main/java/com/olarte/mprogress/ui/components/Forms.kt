package com.olarte.mprogress.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.olarte.mprogress.domain.Currency
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Hoja de formulario como las de iOS: Cancelar, título y Guardar arriba; contenido que se desplaza. */
@Composable
fun FormSheet(title: String, onCancel: () -> Unit, confirm: String = "Guardar", canConfirm: Boolean = true, onConfirm: (() -> Unit)?,
              cancel: String = "Cancelar", full: Boolean = true, content: @Composable ColumnScope.() -> Unit) {
    OverlaySheet(onCancel, if (full) Modifier.fillMaxSize().padding(top = 48.dp) else Modifier) {
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.s3).padding(top = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { T(cancel, Type.cuerpo, Palette.brasaTinta, Modifier.clip(CircleShape).clickable(onClick = onCancel).padding(Spacing.s2)) }
            T(title, Type.titulo3, align = TextAlign.Center, maxLines = 1)
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
                if (onConfirm != null) T(confirm, Type.cuerpo.copy(fontWeight = FontWeight.SemiBold), Palette.brasaTinta.copy(alpha = if (canConfirm) 1f else 0.4f),
                    Modifier.clip(CircleShape).clickable(enabled = canConfirm, onClick = onConfirm).padding(Spacing.s2))
            }
        }
        Column(
            (if (full) Modifier.weight(1f) else Modifier).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen, vertical = Spacing.s4),
            verticalArrangement = Arrangement.spacedBy(Spacing.s5), content = content,
        )
    }
}

/** Grupo de filas (Section de un Form de iOS). */
@Composable
fun FormGroup(header: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        header?.let { SectionLabel(it) }
        Card(padding = Spacing.s2) { content() }
        footer?.let { T(it, Type.leyenda, Palette.texto2) }
    }
}

@Composable
fun FormDivider() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))

@Composable
fun FormRow(title: String, value: String? = null, chevron: Boolean = true, enabled: Boolean = true, titleColor: Color = Palette.texto1,
            valueColor: Color = Palette.texto2, onClick: (() -> Unit)? = null, trailing: (@Composable () -> Unit)? = null) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).alpha(if (enabled) 1f else 0.4f)
            .let { if (onClick != null) it.clip(RoundedCornerShape(Radius.campo)).clickable(enabled = enabled, onClick = onClick) else it }.padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1),
    ) {
        T(title, Type.cuerpo, titleColor, Modifier.weight(1f))
        value?.let { T(it, Type.cuerpo2, valueColor, maxLines = 1) }
        trailing?.invoke()
        if (chevron && onClick != null) Icon(Icons.Rounded.ChevronRight, null, Modifier.size(18.dp), tint = Palette.texto2)
    }
}

@Composable
fun FormToggle(title: String, checked: Boolean, subtitle: String? = null, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).alpha(if (enabled) 1f else 0.4f).clickable(enabled = enabled) { onChange(!checked) }.padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            T(title, Type.cuerpo)
            subtitle?.let { T(it, Type.cuerpo2, Palette.texto2) }
        }
        Switch(checked, onChange, enabled = enabled, colors = SwitchDefaults.colors(checkedTrackColor = Palette.brasa, checkedThumbColor = Color.White,
            uncheckedTrackColor = Palette.superficie3, uncheckedBorderColor = Color.Transparent, uncheckedThumbColor = Color.White))
    }
}

@Composable
fun FormTextField(value: String, hint: String, keyboard: KeyboardType = KeyboardType.Text, singleLine: Boolean = true, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2), contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) T(hint, Type.cuerpo, Palette.texto2)
        BasicTextField(value, onChange, Modifier.appTextField().fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa),
            singleLine = singleLine, keyboardOptions = KeyboardOptions(keyboardType = keyboard))
    }
}

/** Campo de monto con puntos de miles, como MoneyField de iOS. Guarda en unidades menores. */
@Composable
fun MoneyField(title: String, minor: Long, currency: Currency = Currency.current, modifier: Modifier = Modifier, onChange: (Long) -> Unit) {
    var text by remember { mutableStateOf((minor / currency.minorPerUnit).let { if (it == 0L) "" else Money.groupThousands(it) }) }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        T(title, Type.leyenda, Palette.texto2)
        Row(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(horizontal = Spacing.s4),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
            T(currency.symbol, Type.cifraPequena, Palette.texto2)
            Box(Modifier.weight(1f)) {
                if (text.isEmpty()) T("0", Type.cifraPequena, Palette.texto2)
                BasicTextField(text, { v ->
                    val digits = v.filter(Char::isDigit).take(12)
                    val units = digits.toLongOrNull() ?: 0
                    text = if (digits.isEmpty()) "" else Money.groupThousands(units)
                    onChange(units * currency.minorPerUnit)
                }, Modifier.appTextField().fillMaxWidth(), textStyle = Type.cifraPequena.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
            }
        }
    }
}

/** Botones de fecha de Paso 2: Hoy, Ayer, Mañana y Otra fecha (abre el calendario). */
@Composable
fun DateChips(date: LocalDate, today: LocalDate = LocalDate.now(), allowFuture: Boolean = true, onPick: (LocalDate) -> Unit) {
    var picking by remember { mutableStateOf(false) }
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        Chip("Hoy", date == today) { onPick(today) }
        Chip("Ayer", date == today.minusDays(1)) { onPick(today.minusDays(1)) }
        if (allowFuture) Chip("Mañana", date == today.plusDays(1)) { onPick(today.plusDays(1)) }
        val other = date != today && date != today.minusDays(1) && date != today.plusDays(1)
        Chip(if (other) DueText.shortDate(date, today) else "Otra fecha", other, icon = Icons.Outlined.CalendarMonth) { picking = true }
    }
    if (picking) DatePickDialog(date, { picking = false }) { onPick(it); picking = false }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DatePickDialog(initial: LocalDate, onDismiss: () -> Unit, onPick: (LocalDate) -> Unit) {
    val state = rememberDatePickerState(initialSelectedDateMillis = initial.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli())
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton({ state.selectedDateMillis?.let { onPick(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) } ?: onDismiss() }) { T("Listo", Type.etiqueta, Palette.brasaTinta) } },
        dismissButton = { TextButton(onDismiss) { T("Cancelar", Type.etiqueta) } },
    ) { DatePicker(state) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimePickDialog(minutes: Int, onDismiss: () -> Unit, onPick: (Int) -> Unit) {
    val state = rememberTimePickerState(minutes / 60, minutes % 60, false)
    Dialog(onDismiss) {
        Column(Modifier.clip(RoundedCornerShape(Radius.tarjeta)).background(Palette.superficie2).padding(Spacing.s5), horizontalAlignment = Alignment.CenterHorizontally) {
            TimePicker(state)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                TextButton(onDismiss) { T("Cancelar", Type.etiqueta) }
                TextButton({ onPick(state.hour * 60 + state.minute) }) { T("Listo", Type.etiqueta, Palette.brasaTinta) }
            }
        }
    }
}

/** Cuadrícula de días 1 a 31 (Día del mes). */
@Composable
fun DayGrid(selection: Int?, onPick: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        (1..31).chunked(7).forEach { week ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                week.forEach { d ->
                    Box(Modifier.weight(1f).height(44.dp), contentAlignment = Alignment.Center) {
                        Box(Modifier.size(44.dp).clip(CircleShape).background(if (selection == d) Palette.brasa else Color.Transparent).clickable { onPick(d) },
                            contentAlignment = Alignment.Center) { T("$d", Type.cuerpo, if (selection == d) Palette.sobreBrasa else Palette.texto1) }
                    }
                }
                repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** Hoja con la cuadrícula de días. */
@Composable
fun DayGridSheet(title: String, selection: Int?, onDismiss: () -> Unit, onPick: (Int) -> Unit) {
    OverlaySheet(onDismiss) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s6), verticalArrangement = Arrangement.spacedBy(Spacing.s4), horizontalAlignment = Alignment.CenterHorizontally) {
            T(title, Type.titulo2, modifier = Modifier.padding(top = Spacing.s6), align = TextAlign.Center)
            DayGrid(selection, onPick)
            T("Si el mes no tiene ese día, se usa el último.", Type.cuerpo2, Palette.texto2)
        }
    }
}

@Composable
fun Stepper(text: String, value: Int, range: IntRange, onChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
        T(text, Type.cuerpo, modifier = Modifier.weight(1f))
        Row(Modifier.clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3), verticalAlignment = Alignment.CenterVertically) {
            listOf("−" to -1, "+" to 1).forEachIndexed { i, (label, delta) ->
                if (i == 1) Box(Modifier.width(1.dp).height(20.dp).background(Palette.linea))
                val enabled = (value + delta) in range
                Box(Modifier.size(width = 48.dp, height = 36.dp).clickable(enabled = enabled) { onChange(value + delta) }, contentAlignment = Alignment.Center) {
                    T(label, Type.titulo2, if (enabled) Palette.texto1 else Palette.texto2.copy(alpha = 0.4f))
                }
            }
        }
    }
}

/** Fila elegible con marca, para listas de opciones. */
@Composable
fun CheckRow(title: String, selected: Boolean, subtitle: String? = null, leading: (@Composable () -> Unit)? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(Radius.campo)).clickable(onClick = onClick).padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        leading?.invoke()
        Column(Modifier.weight(1f)) {
            T(title, Type.cuerpo.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal), if (selected) Palette.brasaTinta else Palette.texto1)
            subtitle?.let { T(it, Type.cuerpo2, Palette.texto2) }
        }
        if (selected) Icon(Icons.Rounded.Check, null, Modifier.size(18.dp), tint = Palette.brasaTinta)
    }
}
