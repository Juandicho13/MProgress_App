package com.olarte.mprogress.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Categoría (pantalla 9): recientes y todas, igual que CategoryPickerView de iOS. */
@Composable
fun CategoryPickerSheet(entries: List<EntryRecord>, selection: String?, onDismiss: () -> Unit, onPick: (String?) -> Unit) {
    val recent = entries.filter { it.categoryId != null }.sortedByDescending { it.occurredAt }.mapNotNull { it.categoryId }.distinct().take(3).mapNotNull { Categories.byId(it) }
    FormSheet("Categoría", onDismiss, cancel = "Cerrar", onConfirm = null) {
        @Composable
        fun group(items: List<CategoryRecord>) = Card(padding = Spacing.s2) {
            items.forEach { c ->
                val on = c.id == selection
                CheckRow(c.name, on, leading = {
                    IconTile(Sym.sf(c.icon) ?: Sym.more, if (on) Palette.brasaVelo else Palette.superficie3, if (on) Palette.brasaTinta else Palette.texto1, size = 36.dp)
                }) { onPick(c.id) }
            }
        }
        if (recent.isNotEmpty()) { SectionLabel("Recientes"); group(recent) }
        SectionLabel("Todas")
        group(Categories.all)
        SecondaryButton("Sin categoría") { onPick(null) }
    }
}

/** Baldosa de una categoría o, si no tiene, iniciales del nombre. */
@Composable
fun CategoryTile(categoryId: String?, name: String, kind: EntryKind, size: androidx.compose.ui.unit.Dp = com.olarte.mprogress.ui.theme.Size.baldosa) {
    val income = kind == EntryKind.INGRESO
    val icon = Sym.sf(Categories.byId(categoryId)?.icon)
    if (icon != null) IconTile(icon, if (income) Palette.hieloVelo else Palette.superficie3, if (income) Palette.hielo else Palette.texto1, size)
    else EntryTile(name, kind, size)
}

private fun longDate(d: LocalDate) = "${d.dayOfMonth} de ${DueText.monthName(d)} de ${d.year}"

/** Detalle de movimiento (pantalla 23): editar, duplicar y borrar con deshacer. */
@Composable
fun EntryDetailSheet(store: Store, entryId: String, onDismiss: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val entry = ledger.entries.firstOrNull { it.id == entryId } ?: run { onDismiss(); return }
    var editing by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }
    val origin = ledger.recurring.firstOrNull { it.id == entry.recurringId }

    if (editing) {
        Box(Modifier.fillMaxSize().background(Palette.superficie2)) {
            AddEntryContent(store, AddRequest(entry.kind, Cycle.Puntual), editing = entry) { editing = false }
        }
        return
    }
    Column(Modifier.fillMaxSize().background(Palette.superficie2)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.margen).padding(top = Spacing.s4), verticalAlignment = Alignment.CenterVertically) {
            CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onDismiss)
            T("Detalle", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
            CircleIconButton(Icons.Rounded.Edit, "Editar") { editing = true }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen).padding(bottom = Spacing.s8),
            verticalArrangement = Arrangement.spacedBy(Spacing.s6)) {
            Column(Modifier.fillMaxWidth().padding(top = Spacing.s4), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                CategoryTile(entry.categoryId, entry.name, entry.kind, 72.dp)
                T(entry.name.ifBlank { if (entry.kind == EntryKind.INGRESO) "Ingreso" else "Gasto" }, Type.titulo2, align = TextAlign.Center)
                T(signedAmount(entry.amountMinor, entry.kind), Type.cifraGrande, if (entry.kind == EntryKind.INGRESO) Palette.hielo else Palette.texto1, maxLines = 1)
                if (entry.kind == EntryKind.INGRESO) Badge("Ingreso", Palette.hieloVelo, Palette.hielo) else Badge("Gasto", Palette.superficie3, Palette.texto2)
            }
            Card(padding = Spacing.s2) {
                FormRow("Fecha", longDate(entry.occurredAt) + (entry.atMinutes?.let { " · ${ReminderPlanner.timeText(it)}" } ?: ""), chevron = false)
                FormDivider()
                FormRow("Categoría", Categories.byId(entry.categoryId)?.name ?: "Sin categoría", chevron = false)
                FormDivider()
                FormRow(if (entry.kind == EntryKind.INGRESO) "Llegó a" else "Pagado con", ledger.product(entry.productId)?.label ?: "Sin elegir", chevron = false)
                origin?.let { FormDivider(); FormRow("Pago fijo", "${it.name} · ${it.cycle.title}", chevron = false) }
                if (entry.pointsEarned > 0) { FormDivider(); FormRow("Puntos", "+ ${Money.groupThousands(entry.pointsEarned)}", chevron = false) }
                if (entry.source != "manual") { FormDivider(); FormRow("Origen", when (entry.source) { "sms" -> "SMS"; "notificacion" -> "Notificación"; "recibo" -> "Recibo"; else -> entry.source }, chevron = false) }
                entry.notes?.takeIf { it.isNotBlank() }?.let { FormDivider(); FormRow("Notas", it, chevron = false) }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                SecondaryButton("Duplicar hoy") {
                    val copy = store.duplicate(entry)
                    onDismiss()
                    store.showUndo("Duplicaste ${entry.name.ifBlank { "el movimiento" }}") { store.deleteEntry(copy.id) }
                }
                SecondaryButton("Borrar movimiento", danger = true) { confirm = true }
            }
        }
    }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { T("¿Borrar ${entry.name.ifBlank { "este movimiento" }}?", Type.titulo3) },
            text = { T("Podrás deshacerlo unos segundos.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({
                confirm = false; store.deleteEntry(entry.id); onDismiss()
                store.showUndo("Borraste ${entry.name.ifBlank { "el movimiento" }}") { store.restoreEntry(entry) }
            }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ confirm = false }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}

/** Editar un pago fijo: nombre, monto, ciclo, fecha, termina, con qué se paga, activo, aviso y borrar. */
@Composable
fun RecurringEditSheet(store: Store, recurringId: String, onDismiss: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val item = ledger.recurring.firstOrNull { it.id == recurringId } ?: run { onDismiss(); return }
    var kind by remember { mutableStateOf(item.kind) }
    var name by remember { mutableStateOf(item.name) }
    var amount by remember { mutableStateOf(item.amountMinor) }
    var choice by remember { mutableStateOf(choiceOf(item.cycle)) }
    var everyDays by remember { mutableStateOf(item.cycle.intervalDays ?: 15) }
    var hasDate by remember { mutableStateOf(!item.dateUnset) }
    var date by remember { mutableStateOf(item.nextDate) }
    var productId by remember { mutableStateOf(item.productId) }
    var categoryId by remember { mutableStateOf(item.categoryId) }
    var active by remember { mutableStateOf(item.active || item.finished) }
    var end by remember { mutableStateOf(when { item.totalCount != null -> EndChoice.CUOTAS; item.endDate != null -> EndChoice.FECHA; else -> EndChoice.NUNCA }) }
    var endDate by remember { mutableStateOf(item.endDate ?: item.nextDate.plusMonths(6)) }
    var count by remember { mutableStateOf(item.totalCount ?: 12) }
    var alert by remember { mutableStateOf(item.alert) }
    var payWith by remember { mutableStateOf(false) }
    var categories by remember { mutableStateOf(false) }
    var reminder by remember { mutableStateOf(false) }
    var pickDay by remember { mutableStateOf(false) }
    var pickDate by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val canSave = name.isNotBlank() && amount > 0

    Box(Modifier.fillMaxSize()) {
        FormSheet("Pago fijo", onDismiss, canConfirm = canSave, onConfirm = {
            val cycle = choice.cycle(everyDays)
            val total = if (end == EndChoice.CUOTAS) maxOf(count, item.paidCount + 1) else null
            var updated = item.copy(kind = kind, name = name.trim(), amountMinor = amount, cycle = cycle, nextDate = date,
                anchor = if (hasDate) CycleAnchor.of(date) else item.anchor, dateUnset = !hasDate, productId = productId, categoryId = categoryId,
                endDate = if (end == EndChoice.FECHA) endDate else null, totalCount = total, alert = alert, active = active, finished = false)
            if ((total != null && updated.paidCount >= total) || (updated.endDate != null && date.isAfter(updated.endDate))) updated = updated.copy(active = false, finished = true)
            store.updateRecurring(updated)
            onDismiss()
        }) {
            Card(padding = Spacing.s2) {
                Segmented(listOf("GASTO" to "Gasto", "INGRESO" to "Ingreso"), kind.name) { kind = EntryKind.valueOf(it) }
                FormTextField(name, "Nombre") { name = it }
            }
            MoneyField("Monto", amount) { amount = it }
            FormGroup("Cuándo") {
                Segmented(CycleChoice.entries.filter { it != CycleChoice.PUNTUAL }.map { it.name to it.title }, choice.name) { choice = CycleChoice.valueOf(it) }
                if (choice == CycleChoice.OTRA) Stepper("Cada $everyDays días", everyDays, 1..365) { everyDays = it }
                FormToggle("Ya sé la fecha", hasDate) { hasDate = it }
                if (hasDate) {
                    FormDivider()
                    if (choice == CycleChoice.MENSUAL) FormRow("Día del mes", "Día ${date.dayOfMonth}", onClick = { pickDay = true })
                    else FormRow("Próximo cobro", "${date.dayOfMonth} ${DueText.months[date.monthValue - 1]} ${date.year}", onClick = { pickDate = true })
                }
            }
            EndPicker(end, endDate, count, { end = it }, { endDate = it }, { count = it })
            if (item.totalCount != null && item.paidCount > 0) T("Ya van ${item.paidCount} cuotas pagadas.", Type.cuerpo2, Palette.texto2)
            Card(padding = Spacing.s2) {
                FormRow("Categoría", Categories.byId(categoryId)?.name ?: "Sin categoría", onClick = { categories = true })
                FormDivider()
                FormRow(if (kind == EntryKind.INGRESO) "¿A dónde llega?" else "¿Con qué se paga?", ledger.product(productId)?.label ?: "Sin elegir", onClick = { payWith = true })
                FormDivider()
                FormToggle(if (item.finished) "Activo (estaba terminado)" else "Activo", active) { active = it }
                FormDivider()
                FormRow("Aviso", alertText(alert, store.alerts.value), enabled = hasDate && active, onClick = { reminder = true })
            }
            if (item.active && !item.dateUnset) SecondaryButton(if (item.kind == EntryKind.INGRESO) "Marcar recibido hoy" else "Marcar pagado hoy") {
                markPaidWithUndo(store, item.id); onDismiss()
            }
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                SecondaryButton("Borrar pago fijo", danger = true) { confirmDelete = true }
                T("Borrarlo no borra los pagos que ya registraste.", Type.leyenda, Palette.texto2)
            }
        }
        if (payWith) PayWithSheet(store, kind, productId, { payWith = false }) { productId = it }
        if (categories) CategoryPickerSheet(ledger.entries, categoryId, { categories = false }) { categoryId = it; categories = false }
        if (reminder) AlertEditSheet(store, item.copy(name = name, amountMinor = amount, kind = kind), alert, { reminder = false }) { alert = it; reminder = false }
        if (pickDay) DayGridSheet("¿Qué día se paga ${name.ifBlank { "este pago" }}?", date.dayOfMonth, { pickDay = false }) { d ->
            val today = LocalDate.now()
            var n = today.withDayOfMonth(minOf(d, today.lengthOfMonth()))
            if (n.isBefore(today)) n = n.plusMonths(1).let { it.withDayOfMonth(minOf(d, it.lengthOfMonth())) }
            date = n; pickDay = false
        }
    }
    if (pickDate) DatePickDialog(date, { pickDate = false }) { date = it; pickDate = false }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { T("¿Borrar ${item.name}?", Type.titulo3) },
            confirmButton = { TextButton({
                confirmDelete = false; store.deleteRecurring(item.id); onDismiss()
                store.showUndo("Borraste ${item.name}") { store.restoreRecurring(item) }
            }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ confirmDelete = false }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}

/** Marca pagado con Deshacer; si era la última cuota avisa "Terminaste de pagar X". */
fun markPaidWithUndo(store: Store, recurringId: String) {
    val before = store.ledger.value.recurring.firstOrNull { it.id == recurringId } ?: return
    val (entry, finished) = store.markPaid(recurringId) ?: return
    val verb = if (before.kind == EntryKind.INGRESO) "recibido" else "pagado"
    store.showUndo(if (finished) "Terminaste de pagar ${before.name}" else "${before.name} quedó $verb") { store.undoPaid(before, entry) }
}

fun alertText(rule: AlertRule, general: AlertSettings): String = when (rule.mode) {
    AlertMode.NINGUNO -> "Sin aviso"
    AlertMode.PERSONALIZADO -> "${if (rule.daysBefore == 0) "El mismo día" else "${rule.daysBefore} días antes"} · ${ReminderPlanner.timeText(rule.atMinutes)}"
    AlertMode.GENERAL -> if (general.enabled) "Como el general" else "General apagado"
}

/** Aviso de un pago fijo (Paso 2): como el general, personalizado (días y hora propios) o sin aviso. */
@Composable
fun AlertEditSheet(store: Store, item: RecurringRecord, initial: AlertRule, onDismiss: () -> Unit, onSave: (AlertRule) -> Unit) {
    val general by store.alerts.collectAsState()
    var rule by remember { mutableStateOf(initial) }
    var pickingTime by remember { mutableStateOf(false) }
    val effective = ReminderPlanner.effective(rule, general)
    FormSheet("Aviso de pago", onDismiss, onConfirm = { onSave(rule) }) {
        Card { EntryRow(item.name, item.kind, item.amountMinor, "${Money(item.amountMinor).formatted()} · ${item.cycle.title}") { } }
        Segmented(AlertMode.entries.map { it.raw to when (it) { AlertMode.GENERAL -> "General"; AlertMode.PERSONALIZADO -> "Personalizado"; AlertMode.NINGUNO -> "Sin aviso" } }, rule.mode.raw) { rule = rule.copy(mode = AlertMode.from(it)) }
        when (rule.mode) {
            AlertMode.GENERAL -> T(if (general.enabled) "Usa el aviso general: ${if (general.daysBefore == 0) "el mismo día" else "${general.daysBefore} días antes"} a las ${ReminderPlanner.timeText(general.atMinutes)}. Lo cambias en Ajustes › Avisos."
                else "El aviso general está apagado en Ajustes › Avisos, así que este pago no avisa.", Type.cuerpo2, Palette.texto2)
            AlertMode.NINGUNO -> T("Este pago no te va a avisar.", Type.cuerpo2, Palette.texto2)
            AlertMode.PERSONALIZADO -> {
                SectionLabel("¿Cuándo?")
                Card {
                    Row { T("Días antes", Type.cuerpo, modifier = Modifier.weight(1f)); T(if (rule.daysBefore == 0) "El mismo día" else "${rule.daysBefore}", Type.cifra) }
                    Slider(rule.daysBefore.toFloat(), { rule = rule.copy(daysBefore = Math.round(it)) }, valueRange = 0f..14f, steps = 13,
                        colors = SliderDefaults.colors(thumbColor = Palette.brasa, activeTrackColor = Palette.brasa, inactiveTrackColor = Palette.superficie3))
                    Row { T("El mismo día", Type.leyenda, Palette.texto2, Modifier.weight(1f)); T("14 días", Type.leyenda, Palette.texto2) }
                }
                Card(padding = Spacing.s2) { FormRow("Hora del aviso", ReminderPlanner.timeText(rule.atMinutes), onClick = { pickingTime = true }) }
            }
        }
        if (effective != null) {
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.boton)).background(Palette.superficie1).padding(Spacing.s4), horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                IconTile(Icons.Rounded.NotificationsActive, Palette.brasa, Palette.sobreBrasa, size = 36.dp)
                Column { T("Vista previa", Type.etiqueta); T(ReminderPlanner.body(item.name, item.kind, Money(item.amountMinor).formatted(), effective.first), Type.cuerpo2, Palette.texto2) }
            }
        }
    }
    if (pickingTime) TimePickDialog(rule.atMinutes, { pickingTime = false }) { rule = rule.copy(atMinutes = it); pickingTime = false }
}
