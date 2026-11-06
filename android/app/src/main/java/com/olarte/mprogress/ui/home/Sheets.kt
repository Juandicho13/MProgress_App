package com.olarte.mprogress.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.QuickActionKind
import com.olarte.mprogress.domain.QuickActionLayout
import com.olarte.mprogress.ui.components.AmountDisplay
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.Keypad
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.Segmented
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

data class AddRequest(val kind: EntryKind, val cycle: Cycle)

/** Agregar (pantalla 8): monto resaltado, teclado, nombre, ciclo, fecha y con qué se paga. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEntryContent(store: Store, request: AddRequest, onDone: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    var kind by remember { mutableStateOf(request.kind) }
    var amount by remember { mutableStateOf(AmountInput()) }
    var amountActive by remember { mutableStateOf(true) }
    var name by remember { mutableStateOf("") }
    var cycle by remember { mutableStateOf(request.cycle) }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var productId by remember { mutableStateOf<String?>(null) }
    var picking by remember { mutableStateOf(false) }
    val today = LocalDate.now()

    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen).navigationBarsPadding().padding(bottom = Spacing.s4),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        Segmented(listOf("GASTO" to "Gasto", "INGRESO" to "Ingreso"), kind.name) { kind = EntryKind.valueOf(it) }
        AmountDisplay("$", amount.display, amountActive) { amountActive = true }
        if (amountActive) {
            Keypad(amount.allowsDecimals, { amount = amount.press(it) }, { amount = amount.deleteLast() })
        }
        Box(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(Spacing.s4)
        ) {
            if (name.isEmpty()) T(if (kind == EntryKind.GASTO) "¿En qué? (opcional)" else "¿De dónde? (opcional)", Type.cuerpo, Palette.texto2)
            BasicTextField(name, { name = it; amountActive = false }, Modifier.fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1),
                cursorBrush = SolidColor(Palette.brasa), singleLine = true)
        }
        SectionLabel("Se repite")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            listOf(Cycle.Puntual, Cycle.Mensual, Cycle.Semanal, Cycle.Anual).forEach { c ->
                Chip(if (c == Cycle.Puntual) "Una vez" else c.title, cycle == c) { cycle = c }
            }
        }
        SectionLabel("Fecha")
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            Chip("Hoy", date == today) { date = today }
            Chip("Ayer", date == today.minusDays(1)) { date = today.minusDays(1) }
            val other = date != today && date != today.minusDays(1)
            Chip(if (other) DueText.shortDate(date, today) else "Otra", other) { picking = true }
        }
        if (ledger.products.isNotEmpty()) {
            SectionLabel(if (kind == EntryKind.GASTO) "Con qué pagas" else "A dónde entra")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                Chip("Sin elegir", productId == null) { productId = null }
                ledger.products.forEach { p ->
                    val bank = ledger.institutions.firstOrNull { it.id == p.institutionId }?.name.orEmpty()
                    Chip(listOfNotNull(bank, p.name, p.last4?.let { "·· $it" }).joinToString(" "), productId == p.id) { productId = p.id }
                }
            }
        }
        PrimaryButton("Guardar", enabled = amount.money.minor > 0) {
            store.add(kind, name.trim(), amount.money.minor, cycle, date, productId)
            onDone()
        }
    }

    if (picking) {
        val state = rememberDatePickerState(initialSelectedDateMillis = date.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton({
                    state.selectedDateMillis?.let { date = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                    picking = false
                }) { T("Listo", Type.etiqueta, Palette.brasaTinta) }
            },
        ) { DatePicker(state) }
    }
}

/** Más acciones (pantalla 20) con lápiz para ordenar y fijar 3 en Inicio. */
@Composable
fun MoreContent(store: Store, onPick: (QuickActionKind) -> Unit) {
    val layout by store.actions.collectAsState()
    var editing by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen).navigationBarsPadding().padding(bottom = Spacing.s6),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T(if (editing) "Organizar" else "Más acciones", Type.titulo2, modifier = Modifier.weight(1f))
            Box(
                Modifier.heightIn(min = 44.dp).clip(CircleShape).background(if (editing) Palette.brasa else Palette.superficie3)
                    .clickable { editing = !editing }.padding(horizontal = Spacing.s4, vertical = Spacing.s2),
                contentAlignment = Alignment.Center,
            ) { T(if (editing) "Listo" else "✎", Type.etiqueta, if (editing) Palette.sobreBrasa else Palette.texto1) }
        }
        if (!editing) {
            layout.order.chunked(3).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    row.forEach { kind ->
                        Column(
                            Modifier.weight(1f).heightIn(min = 96.dp).clip(RoundedCornerShape(Radius.boton)).background(Palette.superficie3)
                                .clickable { onPick(kind) }.padding(Spacing.s2),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                        ) {
                            T(kind.glyph, Type.titulo2)
                            T(kind.title, Type.leyenda, align = androidx.compose.ui.text.style.TextAlign.Center)
                            if (layout.isPinned(kind)) T("● En Inicio", Type.leyenda, Palette.brasaTinta)
                        }
                    }
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            T("Toca el lápiz para ordenarlas y elegir las 3 que ves en Inicio. Dividir gastos llega con los espacios en pareja.", Type.cuerpo2, Palette.texto2)
        } else {
            SectionLabel("En Inicio · ${layout.pinned.size} de ${QuickActionLayout.LIMIT}")
            layout.pinned.forEachIndexed { i, kind ->
                EditRow(kind, pinned = true, canUp = i > 0, canDown = i < layout.pinned.lastIndex,
                    onPin = { store.setActions(layout.togglePin(kind)) },
                    onUp = { store.setActions(layout.movePinned(i, i - 1)) }, onDown = { store.setActions(layout.movePinned(i, i + 1)) })
            }
            T("La primera se ve resaltada.", Type.leyenda, Palette.texto2)
            SectionLabel("En Más")
            val rest = layout.unpinned
            rest.forEachIndexed { i, kind ->
                EditRow(kind, pinned = false, canUp = i > 0, canDown = i < rest.lastIndex,
                    onPin = { store.setActions(layout.togglePin(kind)) },
                    onUp = { store.setActions(layout.moveUnpinned(i, i - 1)) }, onDown = { store.setActions(layout.moveUnpinned(i, i + 1)) })
            }
        }
    }
}

@Composable
private fun EditRow(kind: QuickActionKind, pinned: Boolean, canUp: Boolean, canDown: Boolean, onPin: () -> Unit, onUp: () -> Unit, onDown: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(horizontal = Spacing.s3, vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        T(kind.glyph, Type.titulo3, modifier = Modifier.padding(end = Spacing.s3))
        T(kind.title, Type.cuerpo, modifier = Modifier.weight(1f))
        IconText("▲", canUp, onUp)
        IconText("▼", canDown, onDown)
        IconText(if (pinned) "📌" else "＋", true, onPin)
    }
}

@Composable
private fun IconText(text: String, enabled: Boolean, onClick: () -> Unit) {
    Box(Modifier.size(44.dp).clip(CircleShape).clickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        T(text, Type.etiqueta, if (enabled) Palette.texto1 else Palette.texto2.copy(alpha = 0.3f))
    }
}

