package com.olarte.mprogress.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.domain.QuickActionKind
import com.olarte.mprogress.domain.QuickActionLayout
import com.olarte.mprogress.ui.components.AmountDisplay
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.CircleIconButton
import com.olarte.mprogress.ui.components.InstitutionStyle
import com.olarte.mprogress.ui.components.Keypad
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.OverlaySheet
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.Segmented
import com.olarte.mprogress.ui.components.Sym
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Tile
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

data class AddRequest(val kind: EntryKind, val cycle: Cycle)

private enum class CycleChoice(val title: String) { PUNTUAL("Puntual"), MENSUAL("Mensual"), ANUAL("Anual"), OTRA("Otra") }

private fun CycleChoice.cycle(every: Int): Cycle = when (this) {
    CycleChoice.PUNTUAL -> Cycle.Puntual; CycleChoice.MENSUAL -> Cycle.Mensual; CycleChoice.ANUAL -> Cycle.Anual; CycleChoice.OTRA -> Cycle.CadaDias(maxOf(1, every))
}

private fun choiceOf(c: Cycle) = when (c) {
    Cycle.Mensual, Cycle.Semanal -> CycleChoice.MENSUAL; Cycle.Anual -> CycleChoice.ANUAL; is Cycle.CadaDias -> CycleChoice.OTRA; else -> CycleChoice.PUNTUAL
}

private fun summary(c: Cycle, date: LocalDate): String = when (c) {
    Cycle.Puntual -> "Puntual"
    Cycle.Mensual -> "Mensual · el ${date.dayOfMonth} de cada mes"
    Cycle.Anual -> "Anual · cada ${date.dayOfMonth} de ${DueText.monthName(date)}"
    Cycle.Semanal -> "Semanal"
    is Cycle.CadaDias -> "Cada ${c.days} días"
}

/** Agregar movimiento (pantalla 7), igual que AddEntryView de iOS: barra con cerrar y guardar, nombre, tipo, monto, ciclo y detalles. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEntryContent(store: Store, request: AddRequest, onDone: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    var kind by remember { mutableStateOf(request.kind) }
    var amount by remember { mutableStateOf(AmountInput()) }
    var name by remember { mutableStateOf("") }
    var nameFocused by remember { mutableStateOf(false) }
    var choice by remember { mutableStateOf(choiceOf(request.cycle)) }
    var everyDays by remember { mutableStateOf(30) }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var productId by remember { mutableStateOf<String?>(null) }
    var picking by remember { mutableStateOf(false) }
    var payWith by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val cycle = choice.cycle(everyDays)
    val canSave = amount.money.minor > 0
    fun save() { store.add(kind, name.trim(), amount.money.minor, cycle, date, productId); onDone() }

    Box(Modifier.fillMaxWidth().fillMaxHeight().background(Palette.superficie2)) {
        Column(Modifier.fillMaxSize().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.margen).padding(top = Spacing.s4), verticalAlignment = Alignment.CenterVertically) {
                CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onDone)
                T("Agregar", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
                CircleIconButton(Icons.Rounded.Check, "Guardar", filled = true, enabled = canSave) { save() }
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen, vertical = Spacing.s4),
                verticalArrangement = Arrangement.spacedBy(Spacing.s5),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    Tile(name.ifBlank { "?" }, size = 60.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T("Nombre", Type.leyenda, Palette.texto2)
                        Box {
                            if (name.isEmpty()) T("Netflix, mercado, sueldo", Type.titulo2, Palette.texto2, maxLines = 1)
                            BasicTextField(name, { name = it }, Modifier.fillMaxWidth().onFocusChanged { nameFocused = it.isFocused },
                                textStyle = Type.titulo2.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true)
                        }
                    }
                }
                Segmented(listOf("GASTO" to "Gasto", "INGRESO" to "Ingreso"), kind.name) { kind = EntryKind.valueOf(it) }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    AmountDisplay("$", amount.display, !nameFocused, empty = amount.text.isEmpty()) { focus.clearFocus() }
                    T(summary(cycle, date), Type.cuerpo2, Palette.texto2)
                }
                SectionLabel("Ciclo de cobro")
                Segmented(CycleChoice.entries.map { it.name to it.title }, choice.name) { choice = CycleChoice.valueOf(it) }
                if (choice == CycleChoice.OTRA) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T("Cada $everyDays días", Type.cuerpo, modifier = Modifier.weight(1f))
                        Row(Modifier.clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3)) {
                            StepperKey("−", everyDays > 1) { everyDays-- }
                            Box(Modifier.width(1.dp).height(20.dp).align(Alignment.CenterVertically).background(Palette.linea))
                            StepperKey("+", everyDays < 365) { everyDays++ }
                        }
                    }
                }
                Card(padding = Spacing.s2) {
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                        T(if (choice == CycleChoice.PUNTUAL) "Fecha" else "Fecha de pago", Type.cuerpo, modifier = Modifier.weight(1f))
                        Box(Modifier.clip(RoundedCornerShape(10.dp)).background(Palette.superficie3).clickable { focus.clearFocus(); picking = true }
                            .padding(horizontal = Spacing.s3, vertical = 6.dp)) {
                            T("${date.dayOfMonth} ${DueText.monthName(date).take(3)} ${date.year}", Type.cuerpo, Palette.brasaTinta)
                        }
                    }
                    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))
                    val product = ledger.products.firstOrNull { it.id == productId }
                    DetailRow(if (kind == EntryKind.INGRESO) "¿A dónde llegó?" else "¿Con qué pagaste?",
                        product?.let { p -> p.last4?.let { "${p.name} ·· $it" } ?: p.name } ?: "Sin elegir") { focus.clearFocus(); payWith = true }
                }
            }
            if (!nameFocused) {
                Box(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s2)) {
                    Keypad(amount.allowsDecimals, { amount = amount.press(it) }, { amount = amount.deleteLast() })
                }
            }
        }
        if (payWith) PayWithSheet(store, kind, productId, { payWith = false }) { productId = it }
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

@Composable
private fun StepperKey(text: String, enabled: Boolean, onClick: () -> Unit) {
    Box(Modifier.size(width = 48.dp, height = 36.dp).clickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        T(text, Type.titulo2, if (enabled) Palette.texto1 else Palette.texto2.copy(alpha = 0.4f))
    }
}

@Composable
private fun DetailRow(title: String, value: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(onClick = onClick).padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        T(title, Type.cuerpo, modifier = Modifier.weight(1f))
        T(value, Type.cuerpo2, Palette.texto2, maxLines = 1)
        Icon(Icons.Rounded.ChevronRight, null, Modifier.size(18.dp), tint = Palette.texto2)
    }
}

private enum class PayTab(val title: String, val kinds: Set<ProductKind>) {
    TARJETA("Tarjeta", setOf(ProductKind.CREDITO, ProductKind.DEBITO)), CUENTA("Cuenta", setOf(ProductKind.CUENTA, ProductKind.BOLSILLO)), EFECTIVO("Efectivo", setOf(ProductKind.EFECTIVO));
    companion object { fun of(k: ProductKind) = entries.first { k in it.kinds } }
}

/** ¿Con qué pagaste? (pantalla 34): tarjeta, cuenta o efectivo. */
@Composable
private fun PayWithSheet(store: Store, kind: EntryKind, selected: String?, onDismiss: () -> Unit, onPick: (String?) -> Unit) {
    val ledger by store.ledger.collectAsState()
    var current by remember { mutableStateOf(selected) }
    var tab by remember { mutableStateOf(ledger.products.firstOrNull { it.id == selected }?.let { PayTab.of(it.kind) } ?: PayTab.TARJETA) }
    val items = ledger.products.filter { it.kind in tab.kinds }
    OverlaySheet(onDismiss) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            T(if (kind == EntryKind.INGRESO) "¿A dónde llegó?" else "¿Con qué pagaste?", Type.titulo2, modifier = Modifier.padding(top = Spacing.s6))
            Segmented(PayTab.entries.map { it.name to it.title }, tab.name) { tab = PayTab.valueOf(it) }
            if (items.isEmpty()) {
                Card {
                    T(if (tab == PayTab.EFECTIVO) "Aún no tienes billetera de efectivo. Agrégala en la pestaña Dinero."
                      else "Agrega tus bancos y tarjetas en la pestaña Dinero para elegirlos aquí.", Type.cuerpo, Palette.texto2)
                }
            } else {
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        items.forEach { p ->
                            val bank = ledger.institutions.firstOrNull { it.id == p.institutionId }?.name.orEmpty()
                            ListRow(title = p.last4?.let { "${p.name} ·· $it" } ?: p.name, subtitle = bank, icon = InstitutionStyle.symbol(p.kind),
                                onClick = { current = p.id; onPick(p.id) }) {
                                if (p.id == current) Icon(Icons.Rounded.Check, null, Modifier.size(18.dp), tint = Palette.brasaTinta)
                            }
                        }
                    }
                }
            }
            if (current != null) {
                T("Quitar", Type.etiqueta, Palette.texto2, Modifier.heightIn(min = Size.toqueMinimo).clip(CircleShape)
                    .clickable { current = null; onPick(null) }.padding(vertical = 16.dp))
            }
            PrimaryButton("Listo", onClick = onDismiss)
        }
    }
}

/** Más acciones (pantalla 20) con lápiz para ordenar y fijar 3 en Inicio, igual que MoreSheet de iOS. */
@Composable
fun MoreContent(store: Store, onPick: (QuickActionKind) -> Unit) {
    val layout by store.actions.collectAsState()
    var editing by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxWidth().background(Palette.superficie2).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen)
            .navigationBarsPadding().padding(bottom = Spacing.s6),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        Row(Modifier.padding(top = Spacing.s6), verticalAlignment = Alignment.CenterVertically) {
            T(if (editing) "Organizar" else "Más acciones", Type.titulo2, modifier = Modifier.weight(1f))
            Box(
                Modifier.height(44.dp).let { if (editing) it else it.width(44.dp) }.clip(CircleShape).background(if (editing) Palette.brasa else Palette.superficie3)
                    .clickable { editing = !editing }.padding(horizontal = if (editing) Spacing.s4 else 0.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (editing) T("Listo", Type.etiqueta, Palette.sobreBrasa)
                else Icon(Icons.Rounded.Edit, "Organizar acciones", Modifier.size(20.dp), tint = Palette.texto1)
            }
        }
        if (!editing) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                layout.order.chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                        row.forEach { kind ->
                            Box(Modifier.weight(1f).heightIn(min = 96.dp).clip(RoundedCornerShape(Radius.boton)).background(Palette.superficie3).clickable { onPick(kind) }) {
                                Column(Modifier.align(Alignment.Center).padding(horizontal = Spacing.s1, vertical = Spacing.s3),
                                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                                    Icon(Sym.of(kind), null, Modifier.size(26.dp), tint = Palette.texto1)
                                    T(kind.title, Type.leyenda, align = TextAlign.Center)
                                }
                                if (layout.isPinned(kind)) Icon(Icons.Rounded.PushPin, "En Inicio", Modifier.align(Alignment.TopEnd).padding(Spacing.s2).size(12.dp), tint = Palette.brasaTinta)
                            }
                        }
                        repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
            T("Toca el lápiz para ordenarlas y elegir las 3 que ves en Inicio. Dividir gastos llega con los espacios en pareja.", Type.cuerpo2, Palette.texto2,
                Modifier.padding(top = Spacing.s4))
        } else {
            Group("En Inicio · ${layout.pinned.size} de ${QuickActionLayout.LIMIT}", "La primera se ve resaltada. Usa las flechas para cambiar el orden.") {
                layout.pinned.forEachIndexed { i, kind ->
                    EditRow(kind, pinned = true, canUp = i > 0, canDown = i < layout.pinned.lastIndex, last = i == layout.pinned.lastIndex,
                        onPin = { store.setActions(layout.togglePin(kind)) },
                        onUp = { store.setActions(layout.movePinned(i, i - 1)) }, onDown = { store.setActions(layout.movePinned(i, i + 1)) })
                }
            }
            val rest = layout.unpinned
            Group("En Más", null) {
                rest.forEachIndexed { i, kind ->
                    EditRow(kind, pinned = false, canUp = i > 0, canDown = i < rest.lastIndex, last = i == rest.lastIndex,
                        onPin = { store.setActions(layout.togglePin(kind)) },
                        onUp = { store.setActions(layout.moveUnpinned(i, i - 1)) }, onDown = { store.setActions(layout.moveUnpinned(i, i + 1)) })
                }
            }
        }
    }
}

/** Sección agrupada como la lista insetGrouped de iOS. */
@Composable
private fun Group(header: String, footer: String?, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        T(header, Type.leyenda, Palette.texto2, Modifier.padding(horizontal = Spacing.s4))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3)) { content() }
        footer?.let { T(it, Type.leyenda, Palette.texto2, Modifier.padding(horizontal = Spacing.s4)) }
    }
}

@Composable
private fun EditRow(kind: QuickActionKind, pinned: Boolean, canUp: Boolean, canDown: Boolean, last: Boolean, onPin: () -> Unit, onUp: () -> Unit, onDown: () -> Unit) {
    Column {
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(start = Spacing.s4, end = Spacing.s1), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) { Icon(Sym.of(kind), null, Modifier.size(20.dp), tint = Palette.texto1) }
            T(kind.title, Type.cuerpo, modifier = Modifier.weight(1f))
            IconBtn(if (pinned) Icons.Rounded.PushPin else Icons.Outlined.PushPin, if (pinned) "Quitar de Inicio" else "Poner en Inicio", true,
                if (pinned) Palette.brasaTinta else Palette.texto2, onPin)
            IconBtn(Icons.Rounded.KeyboardArrowUp, "Subir", canUp, Palette.texto2, onUp)
            IconBtn(Icons.Rounded.KeyboardArrowDown, "Bajar", canDown, Palette.texto2, onDown)
        }
        if (!last) Box(Modifier.padding(start = 60.dp).fillMaxWidth().height(1.dp).background(Palette.linea))
    }
}

@Composable
private fun IconBtn(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, enabled: Boolean, tint: androidx.compose.ui.graphics.Color, onClick: () -> Unit) {
    Box(Modifier.size(40.dp).clip(CircleShape).clickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(icon, label, Modifier.size(18.dp), tint = if (enabled) tint else tint.copy(alpha = 0.25f))
    }
}

