package com.olarte.mprogress.ui.home

import com.olarte.mprogress.ui.components.appTextField

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
import androidx.compose.foundation.layout.imePadding
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
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.Permissions
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

/**
 * Lo que abre Agregar. `merchant` es el comercio tal como llegó (registro automático o recibo) y `categoryId` la categoría
 * aprendida de ese comercio, si hay.
 */
data class AddRequest(val kind: EntryKind, val cycle: Cycle, val name: String = "", val amountMinor: Long = 0, val source: String = "manual", val productId: String? = null,
                      val merchant: String? = null, val categoryId: String? = null)

enum class CycleChoice(val title: String) { PUNTUAL("Puntual"), MENSUAL("Mensual"), ANUAL("Anual"), OTRA("Otra") }

/** `monthly`: el ciclo de Mensual según "Cada cuánto" (mensual, trimestral, cada N meses). */
fun CycleChoice.cycle(every: Int, monthly: Cycle = Cycle.Mensual): Cycle = when (this) {
    CycleChoice.PUNTUAL -> Cycle.Puntual; CycleChoice.MENSUAL -> monthly; CycleChoice.ANUAL -> Cycle.Anual; CycleChoice.OTRA -> Cycle.CadaDias(maxOf(1, every))
}

fun choiceOf(c: Cycle) = when (c) {
    Cycle.Mensual, Cycle.Semanal, is Cycle.CadaMeses -> CycleChoice.MENSUAL; Cycle.Anual -> CycleChoice.ANUAL; is Cycle.CadaDias -> CycleChoice.OTRA; else -> CycleChoice.PUNTUAL
}

/** Cada cuánto se repite un pago mensual: Mensual, Cada 2 meses, Trimestral, Semestral, Anual o Cada N meses (1 a 24), como en iOS. */
@Composable
fun MonthIntervalPicker(interval: MonthInterval, months: Int, onInterval: (MonthInterval) -> Unit, onMonths: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Column {
        Box {
            FormRow("Cada cuánto", interval.title, onClick = { open = true })
            androidx.compose.material3.DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
                MonthInterval.entries.forEach { option ->
                    androidx.compose.material3.DropdownMenuItem({ T(option.title, Type.cuerpo) }, { onInterval(option); open = false })
                }
            }
        }
        if (interval == MonthInterval.OTRO) Stepper("Cada $months ${if (months == 1) "mes" else "meses"}", months, MonthInterval.RANGE, onMonths)
    }
}

private fun summary(c: Cycle, date: LocalDate): String = when (c) {
    Cycle.Puntual -> "Puntual"
    Cycle.Mensual -> "Mensual · el ${date.dayOfMonth} de cada mes"
    Cycle.Anual -> "Anual · cada ${date.dayOfMonth} de ${DueText.monthName(date)}"
    Cycle.Semanal -> "Semanal"
    is Cycle.CadaDias -> "Cada ${c.days} días"
    is Cycle.CadaMeses -> "${MonthInterval.title(c.months)} · el ${date.dayOfMonth}"
}

/** "Termina" de un pago fijo (Paso 2): nunca, en una fecha o después de N cuotas. */
enum class EndChoice(val title: String) { NUNCA("Nunca"), FECHA("En una fecha"), CUOTAS("Después de N cuotas") }

/** Bloque "Termina" que comparten Agregar y editar pago fijo. */
@Composable
fun EndPicker(choice: EndChoice, endDate: LocalDate, count: Int, onChoice: (EndChoice) -> Unit, onDate: (LocalDate) -> Unit, onCount: (Int) -> Unit) {
    var picking by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        SectionLabel("Termina")
        Segmented(EndChoice.entries.map { it.name to when (it) { EndChoice.NUNCA -> "Nunca"; EndChoice.FECHA -> "En una fecha"; EndChoice.CUOTAS -> "Cuotas" } }, choice.name) { onChoice(EndChoice.valueOf(it)) }
        when (choice) {
            EndChoice.FECHA -> Card(padding = Spacing.s2) {
                FormRow("Último cobro", "${endDate.dayOfMonth} ${DueText.months[endDate.monthValue - 1]} ${endDate.year}", onClick = { picking = true })
            }
            EndChoice.CUOTAS -> Card(padding = Spacing.s2) { Stepper("Después de $count cuotas", count, 1..360, onCount) }
            EndChoice.NUNCA -> {}
        }
    }
    if (picking) DatePickDialog(endDate, { picking = false }) { onDate(it); picking = false }
}

/** Agregar movimiento (pantalla 7), igual que AddEntryView de iOS. Con `editing` edita uno ya guardado. */
@Composable
fun AddEntryContent(store: Store, request: AddRequest, editing: EntryRecord? = null, onDone: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val currency by store.currency.collectAsState()
    val today = LocalDate.now()
    var kind by remember { mutableStateOf(editing?.kind ?: request.kind) }
    var amount by remember { mutableStateOf(editing?.let { AmountInput.fromMinor(it.amountMinor, currency) }
        ?: if (request.amountMinor > 0) AmountInput.fromMinor(request.amountMinor, currency) else AmountInput(currency)) }
    var name by remember { mutableStateOf(editing?.name ?: request.name) }
    var nameFocused by remember { mutableStateOf(false) }
    var notesFocused by remember { mutableStateOf(false) }
    var choice by remember { mutableStateOf(choiceOf(request.cycle)) }
    var everyDays by remember { mutableStateOf(30) }
    var date by remember { mutableStateOf(editing?.occurredAt ?: today) }
    var atMinutes by remember { mutableStateOf(editing?.atMinutes) }
    var productId by remember { mutableStateOf(editing?.productId ?: request.productId) }
    var categoryId by remember { mutableStateOf(editing?.categoryId ?: request.categoryId) }
    var monthInterval by remember { mutableStateOf(MonthInterval.MENSUAL) }
    var everyMonths by remember { mutableStateOf(4) }
    var notes by remember { mutableStateOf(editing?.notes ?: "") }
    var end by remember { mutableStateOf(EndChoice.NUNCA) }
    var pickedDay by remember { mutableStateOf<Int?>(null) }
    var paidThisMonth by remember { mutableStateOf(false) }
    var endDate by remember { mutableStateOf(today.plusMonths(6)) }
    var count by remember { mutableStateOf(12) }
    var payWith by remember { mutableStateOf(false) }
    var categories by remember { mutableStateOf(false) }
    var pickingTime by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val context = androidx.compose.ui.platform.LocalContext.current
    val cycle = if (editing != null) Cycle.Puntual else choice.cycle(everyDays, MonthInterval.cycle(monthInterval, everyMonths))
    val canSave = amount.money.minor > 0
    val anyFocused = nameFocused || notesFocused

    fun save() {
        if (editing != null) {
            store.updateEntry(editing.copy(kind = kind, amountMinor = amount.money.minor, name = name.trim(), occurredAt = date, productId = productId,
                categoryId = categoryId, notes = notes.trim().ifEmpty { null }, atMinutes = atMinutes))
            onDone(); return
        }
        val before = BudgetMath.statuses(ledger.budgets, ledger.entries, today)
        val created = store.add(kind, name.trim(), amount.money.minor, cycle, date, productId, today, categoryId, notes.trim(), atMinutes, source = request.source,
            endDate = if (cycle.repeats && end == EndChoice.FECHA) endDate else null, totalCount = if (cycle.repeats && end == EndChoice.CUOTAS) count else null,
            merchant = request.merchant ?: request.name.takeIf { request.source != "manual" })
        val l = store.ledger.value
        val crossing = if (created != null && store.alerts.value.budgets) BudgetMath.crossings(before, BudgetMath.statuses(l.budgets, l.entries, today)).firstOrNull() else null
        if (crossing != null) {
            val cname = crossing.budget.categoryId?.let { Categories.byId(it)?.name } ?: "el total del mes"
            val pct = Math.round(crossing.ratio * 100)
            val text = if (crossing.level == BudgetLevel.SUPERADO) "Te pasaste del límite de $cname ($pct %)" else "Vas en $pct % del límite de $cname"
            store.showUndo(text)
            com.olarte.mprogress.notify.Notifier.show(context, "mp.limite.${crossing.budget.id}.${crossing.level}", if (crossing.level == BudgetLevel.SUPERADO) "Te pasaste del límite" else "Te acercas al límite", text, com.olarte.mprogress.notify.Notifier.CHANNEL_LIMITES)
        } else if (created != null) {
            store.showUndo("Guardaste ${name.trim().ifEmpty { if (kind == EntryKind.GASTO) "el gasto" else "el ingreso" }}") { store.deleteEntry(created.id) }
        }
        if (cycle.repeats) Permissions.askAfterFirstFixed()
        onDone()
    }

    Box(Modifier.fillMaxWidth().fillMaxHeight().background(Palette.superficie2)) {
        Column(Modifier.fillMaxSize().navigationBarsPadding().imePadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.margen).padding(top = Spacing.s4), verticalAlignment = Alignment.CenterVertically) {
                CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onDone)
                T(if (editing != null) "Editar" else "Agregar", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
                CircleIconButton(Icons.Rounded.Check, "Guardar", filled = true, enabled = canSave) { save() }
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen, vertical = Spacing.s4),
                verticalArrangement = Arrangement.spacedBy(Spacing.s5),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    val cat = Categories.byId(categoryId)
                    val icon = Sym.sf(cat?.icon)
                    if (icon != null) IconTile(icon, size = 60.dp) else Tile(name.ifBlank { "?" }, size = 60.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T("Nombre", Type.leyenda, Palette.texto2)
                        Box {
                            if (name.isEmpty()) T("Netflix, mercado, sueldo", Type.titulo2, Palette.texto2, maxLines = 1)
                            BasicTextField(name, { name = it }, Modifier.appTextField().fillMaxWidth().onFocusChanged { nameFocused = it.isFocused },
                                textStyle = Type.titulo2.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true)
                        }
                    }
                }
                Segmented(listOf("GASTO" to "Gasto", "INGRESO" to "Ingreso"), kind.name) { kind = EntryKind.valueOf(it) }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    AmountDisplay(currency.symbol, amount.display, !anyFocused, empty = amount.text.isEmpty()) { focus.clearFocus() }
                    if (editing == null) T(summary(cycle, date), Type.cuerpo2, Palette.texto2)
                }
                if (editing == null) {
                    SectionLabel("Ciclo de cobro")
                    Segmented(CycleChoice.entries.map { it.name to it.title }, choice.name) { choice = CycleChoice.valueOf(it) }
                    if (choice == CycleChoice.OTRA) Card(padding = Spacing.s2) { Stepper("Cada $everyDays días", everyDays, 1..365) { everyDays = it } }
                    if (choice == CycleChoice.MENSUAL) Card(padding = Spacing.s2) { MonthIntervalPicker(monthInterval, everyMonths, { monthInterval = it }, { everyMonths = it }) }
                    if (cycle.repeats) EndPicker(end, endDate, count, { end = it }, { endDate = it }, { count = it })
                }
                if (editing == null && choice == CycleChoice.MENSUAL) Card {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                        T("Día del mes", Type.titulo3)
                        DayGrid(pickedDay ?: date.dayOfMonth) { d -> pickedDay = d; date = DayOfMonth.date(d, today, paidThisMonth) }
                        val day = pickedDay ?: date.dayOfMonth
                        if (DayOfMonth.hasPassed(day, today)) FormToggle(if (kind == EntryKind.INGRESO) "Ya me llegó este mes" else "Ya lo pagué este mes", paidThisMonth) {
                            paidThisMonth = it; date = DayOfMonth.date(day, today, it)
                        }
                        val plan = AddPlan.decide(cycle, date, today)
                        val word = if (kind == EntryKind.INGRESO) "pago" else "cobro"
                        val next = plan.recurringNext?.let { DueText.shortDate(it, today) }.orEmpty()
                        T(plan.entryDate?.let { "Se anota el ${DueText.shortDate(it, today)} como ${if (kind == EntryKind.INGRESO) "recibido" else "pagado"} y el próximo $word es el $next." }
                            ?: "Próximo $word: $next.", Type.leyenda, Palette.texto2)
                    }
                } else Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    SectionLabel(if (choice == CycleChoice.PUNTUAL || editing != null) "Fecha" else "Fecha de pago")
                    DateChips(date, today) { date = it }
                    if (atMinutes == null) T("+ Agregar hora", Type.etiqueta, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { pickingTime = true }.padding(vertical = Spacing.s2, horizontal = Spacing.s1))
                    else Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        Chip("Hora ${ReminderPlanner.timeText(atMinutes!!)}", true) { pickingTime = true }
                        T("Quitar", Type.etiqueta, Palette.texto2, Modifier.clip(CircleShape).clickable { atMinutes = null }.padding(Spacing.s2))
                    }
                }
                Card(padding = Spacing.s2) {
                    DetailRow("Categoría", Categories.byId(categoryId)?.name ?: "Sin categoría") { focus.clearFocus(); categories = true }
                    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))
                    val product = ledger.product(productId)
                    DetailRow(if (kind == EntryKind.INGRESO) "¿A dónde llegó?" else "¿Con qué pagaste?", product?.label ?: "Sin elegir") { focus.clearFocus(); payWith = true }
                    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                        T("Notas", Type.cuerpo)
                        Box(Modifier.weight(1f).padding(start = Spacing.s3), contentAlignment = Alignment.CenterEnd) {
                            if (notes.isEmpty()) T("Opcional", Type.cuerpo, Palette.texto2)
                            BasicTextField(notes, { notes = it }, Modifier.appTextField().fillMaxWidth().onFocusChanged { notesFocused = it.isFocused },
                                textStyle = Type.cuerpo.copy(color = Palette.texto2, textAlign = TextAlign.End), cursorBrush = SolidColor(Palette.brasa))
                        }
                    }
                }
            }
            if (!anyFocused) {
                Box(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s2)) {
                    Keypad(amount.allowsDecimals, { amount = amount.press(it) }, { amount = amount.deleteLast() })
                }
            }
        }
        if (payWith) PayWithSheet(store, kind, productId, { payWith = false }) { productId = it }
        if (categories) CategoryPickerSheet(ledger.entries, categoryId, { categories = false }) { categoryId = it; categories = false }
    }
    if (pickingTime) TimePickDialog(atMinutes ?: 12 * 60, { pickingTime = false }) { atMinutes = it; pickingTime = false }
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
fun PayWithSheet(store: Store, kind: EntryKind, selected: String?, onDismiss: () -> Unit, onPick: (String?) -> Unit) {
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

