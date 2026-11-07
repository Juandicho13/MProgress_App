package com.olarte.mprogress.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDropDown
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.domain.QuincenaDays
import com.olarte.mprogress.domain.RepeatDraft
import com.olarte.mprogress.domain.RepeatPreset
import com.olarte.mprogress.domain.RepeatUnit
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.FormRow
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.components.appTextField
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing

/**
 * Fila plegable de Agregar, igual que DisclosureRow de iOS: título a la izquierda, lo elegido a la derecha y una flecha. Al tocarla se
 * abre debajo lo que la cambia. Quien la usa decide cuál está abierta (una a la vez).
 */
@Composable
fun DisclosureRow(title: String, value: String, expanded: Boolean, onTap: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(Radius.campo))
                .clickable(onClickLabel = if (expanded) "Cerrar" else "Cambiar", onClick = onTap)
                .semantics(mergeDescendants = true) { stateDescription = value }
                .padding(horizontal = Spacing.s2),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2),
        ) {
            T(title, Type.cuerpo, modifier = Modifier.weight(1f))
            T(value, Type.cuerpo2, if (expanded) Palette.brasaTinta else Palette.texto2, maxLines = 1)
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(18.dp).rotate(if (expanded) 180f else 0f), tint = Palette.texto2)
        }
        AnimatedVisibility(expanded, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
            Column(Modifier.padding(start = Spacing.s2, end = Spacing.s2, bottom = Spacing.s3), verticalArrangement = Arrangement.spacedBy(Spacing.s3), content = content)
        }
    }
}

/**
 * Otra en "¿Se repite?", igual que RepeatOtherEditor de iOS: atajos (Cada 2 meses, Trimestral, Semestral, Anual) y "Cada [N] [días,
 * semanas, meses o años]" con el número escrito con el teclado numérico. Avisa si el número no sirve y muestra el resumen debajo.
 * `onFocus` avisa cuando el número tiene el teclado, para esconder el teclado del monto.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RepeatOtherEditor(draft: RepeatDraft, summary: String?, onFocus: (Boolean) -> Unit = {}, onChange: (RepeatDraft) -> Unit) {
    val focus = LocalFocusManager.current
    var focused by remember { mutableStateOf(false) }
    var unitOpen by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            RepeatPreset.entries.forEach { preset ->
                Chip(preset.title, draft.preset == preset) { focus.clearFocus(); onChange(draft.apply(preset)) }
            }
        }
        Row(Modifier.heightIn(min = Size.toqueMinimo), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            T("Cada", Type.cuerpo)
            val shape = RoundedCornerShape(Radius.campo)
            val border = when { !draft.isValid -> Palette.peligro; focused -> Palette.brasa; else -> Color.Transparent }
            Box(Modifier.size(width = 64.dp, height = 44.dp).clip(shape).background(Palette.superficie3).border(1.5.dp, border, shape), contentAlignment = Alignment.Center) {
                if (draft.countText.isEmpty()) T("N", Type.cifra, Palette.texto2)
                BasicTextField(draft.countText, { v -> onChange(draft.copy(countText = v.filter(Char::isDigit).take(3))) },
                    Modifier.appTextField().fillMaxWidth().onFocusChanged { focused = it.isFocused; onFocus(it.isFocused) }
                        .semantics { contentDescription = "Cada cuántos ${draft.unit.title}" },
                    textStyle = Type.cifra.copy(color = Palette.texto1, textAlign = TextAlign.Center), cursorBrush = SolidColor(Palette.brasa), singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }))
            }
            Box {
                Row(Modifier.heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).clickable { focus.clearFocus(); unitOpen = true }
                    .padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                    T(draft.unit.title(draft.count ?: 2), Type.cuerpo)
                    Icon(Icons.Rounded.ArrowDropDown, null, Modifier.size(22.dp), tint = Palette.texto2)
                }
                DropdownMenu(unitOpen, { unitOpen = false }, containerColor = Palette.superficie2) {
                    RepeatUnit.entries.forEach { unit ->
                        DropdownMenuItem({ T(unit.title(draft.count ?: 2), Type.cuerpo) }, { onChange(draft.copy(unit = unit)); unitOpen = false })
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            if (focused) T("Listo", Type.etiqueta, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { focus.clearFocus() }.padding(Spacing.s2))
        }
        val hint = draft.hint
        val tip = draft.tip
        if (hint != null) T(hint, Type.leyenda, Palette.peligro) else if (tip != null) T(tip, Type.leyenda, Palette.brasaTinta)
        summary?.let { T(it, Type.leyenda, Palette.texto2) }
    }
}

/** Días de Quincenal, igual que QuincenaDaysEditor de iOS: primer día de 1 a 28 y segundo día a 13 días o más (o "Último día"). */
@Composable
fun QuincenaDaysEditor(days: QuincenaDays, onChange: (QuincenaDays) -> Unit) {
    Column {
        DayMenuRow("Primer día", "${days.first}", QuincenaDays.FIRST_CHOICES.toList(), { "$it" }) { onChange(days.withFirst(it)) }
        DayMenuRow("Segundo día", secondTitle(days.second), QuincenaDays.secondChoices(days.first), ::secondTitle) { onChange(days.withSecond(it)) }
        if (days.high > 28) T("En los meses que no tienen ese día, se paga el último.", Type.leyenda, Palette.texto2)
    }
}

private fun secondTitle(day: Int) = if (day >= QuincenaDays.LAST_DAY) "Último día" else "$day"

@Composable
private fun DayMenuRow(title: String, value: String, options: List<Int>, label: (Int) -> String, onPick: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        FormRow(title, value, onClick = { open = true })
        DropdownMenu(open, { open = false }, Modifier.heightIn(max = 320.dp), containerColor = Palette.superficie2) {
            options.forEach { day -> DropdownMenuItem({ T(label(day), Type.cuerpo) }, { onPick(day); open = false }) }
        }
    }
}
