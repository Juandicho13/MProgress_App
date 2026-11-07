package com.olarte.mprogress.ui.money

import android.content.Context
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.CallMade
import androidx.compose.material.icons.automirrored.rounded.CallReceived
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.olarte.mprogress.data.Ledger
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.data.addDebtPayment
import com.olarte.mprogress.data.deleteDebt
import com.olarte.mprogress.data.deleteDebtPayment
import com.olarte.mprogress.data.restoreDebt
import com.olarte.mprogress.data.saveDebt
import com.olarte.mprogress.data.settleDebt
import com.olarte.mprogress.domain.Currency
import com.olarte.mprogress.domain.DebtDirection
import com.olarte.mprogress.domain.DebtMath
import com.olarte.mprogress.domain.DebtPaymentRecord
import com.olarte.mprogress.domain.DebtRecord
import com.olarte.mprogress.domain.DebtStatus
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.PersonDebts
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.Permissions
import com.olarte.mprogress.ui.components.BackButton
import com.olarte.mprogress.ui.components.Badge
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.DatePickDialog
import com.olarte.mprogress.ui.components.FormDivider
import com.olarte.mprogress.ui.components.FormGroup
import com.olarte.mprogress.ui.components.FormRow
import com.olarte.mprogress.ui.components.FormSheet
import com.olarte.mprogress.ui.components.FormTextField
import com.olarte.mprogress.ui.components.FormToggle
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.MoneyField
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.Segmented
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate
import kotlin.math.abs

// Quién te debe, igual que Features/Money/DebtsSection.swift de iOS: sección en Dinero, persona, detalle con abonos y formularios.

/** Lo que se abre desde Quién te debe. Se apilan: persona, encima el detalle y encima el abono. */
sealed interface DebtScreen {
    data class New(val person: String = "") : DebtScreen
    data class Edit(val debtId: String) : DebtScreen
    data class Person(val key: String) : DebtScreen
    data class Detail(val debtId: String) : DebtScreen
    data class Pay(val debtId: String) : DebtScreen
}

private fun money(minor: Long) = Money(minor).formatted()

/** Iniciales de una persona: "Ana María" → "AM". */
fun debtInitials(name: String) = DebtMath.cleanName(name).split(' ').filter { it.isNotEmpty() }.take(2).joinToString("") { it.first().uppercase() }.ifEmpty { "?" }

/** Azul si te debe, naranja si le debes, gris si están a mano. */
@Composable
private fun debtColors(net: Long): Pair<Color, Color> = when {
    net > 0 -> Palette.hieloVelo to Palette.hielo
    net < 0 -> Palette.brasaVelo to Palette.brasaTinta
    else -> Palette.superficie3 to Palette.texto2
}

@Composable
private fun PersonTile(name: String, net: Long, size: androidx.compose.ui.unit.Dp = Size.baldosa) {
    val (tint, fg) = debtColors(net)
    Box(Modifier.size(size).clip(CircleShape).background(tint), contentAlignment = Alignment.Center) {
        T(debtInitials(name), TextStyle(fontFamily = Type.titulo3.fontFamily, fontSize = (size.value * 0.32f).sp, fontWeight = FontWeight.Bold), fg)
    }
}

@Composable
private fun RowLine(onClick: () -> Unit, leading: @Composable () -> Unit, title: String, subtitle: String, trailing: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(onClick = onClick).padding(vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        leading()
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, Type.titulo3, maxLines = 1)
            T(subtitle, Type.cuerpo2, Palette.texto2, maxLines = 1)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) { trailing() }
    }
}

/** Abre la hoja del sistema para compartir el mensaje (sin integrarse con ninguna app de mensajes). */
fun shareReminder(context: Context, text: String) {
    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
    context.startActivity(Intent.createChooser(send, "Recordarle").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

/** Quién te debe, dentro de Dinero, debajo de Bancos y billeteras. */
@Composable
fun DebtsSection(ledger: Ledger, hide: Boolean, onOpen: (DebtScreen) -> Unit) {
    var showsSettled by remember { mutableStateOf(false) }
    val people = DebtMath.people(ledger.debts, ledger.debtPayments)
    val settled = DebtMath.settled(ledger.debts, ledger.debtPayments)
    val totals = DebtMath.totals(ledger.debts, ledger.debtPayments)
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { SectionLabel("Quién te debe") }
            T("+ Agregar", Type.etiqueta, Palette.brasaTinta, Modifier.heightIn(min = 48.dp).clickable { onOpen(DebtScreen.New()) }.padding(vertical = 15.dp, horizontal = 4.dp))
        }
        if (people.isEmpty() && settled.isEmpty()) {
            Box(Modifier.clickable { onOpen(DebtScreen.New()) }) {
                Card {
                    ListRow(icon = Icons.Outlined.People, tint = Palette.hieloVelo, fg = Palette.hielo, title = "Anota lo que prestas",
                        subtitle = "Y lo que te prestan, con abonos y aviso") { Icon(Icons.Rounded.Add, null, tint = Palette.texto2) }
                }
            }
        } else Card(padding = Spacing.s3) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                T(if (hide) "Montos ocultos" else DebtMath.summaryText(totals, Currency.current), Type.cuerpo2, Palette.texto2, Modifier.padding(horizontal = Spacing.s1))
                people.forEach { p -> PersonRow(p, hide) { onOpen(DebtScreen.Person(p.key)) } }
                if (settled.isNotEmpty()) {
                    FormDivider()
                    Row(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clickable { showsSettled = !showsSettled }.padding(horizontal = Spacing.s1),
                        verticalAlignment = Alignment.CenterVertically) {
                        T("Saldadas (${settled.size})", Type.cuerpo, modifier = Modifier.weight(1f))
                        Icon(if (showsSettled) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown, null, tint = Palette.texto2)
                    }
                    if (showsSettled) settled.forEach { d -> SettledRow(d, hide) { onOpen(DebtScreen.Detail(d.id)) } }
                }
            }
        }
    }
}

@Composable
private fun PersonRow(p: PersonDebts, hide: Boolean, onClick: () -> Unit) {
    val color = debtColors(p.netMinor).second
    RowLine(onClick, { PersonTile(p.name, p.netMinor) }, p.name, if (p.openCount == 1) "1 deuda abierta" else "${p.openCount} deudas abiertas") {
        T(if (hide) "••••••" else money(abs(p.netMinor)), Type.cifraPequena, color)
        T(DebtMath.netLabel(p), Type.leyenda, color)
    }
}

@Composable
private fun SettledRow(d: DebtRecord, hide: Boolean, onClick: () -> Unit) {
    val today = LocalDate.now()
    RowLine(onClick, { PersonTile(d.person, 0) }, d.person,
        "${if (d.direction == DebtDirection.ME_DEBE) "Te debía" else "Le debías"} · ${DueText.shortDate(d.date, today)}") {
        T(if (hide) "••••••" else money(d.amountMinor), Type.cifraPequena, Palette.texto2)
        T("Saldada", Type.leyenda, Palette.exito)
    }
}

/** Dibuja lo que se abrió desde Quién te debe, uno encima del otro. */
@Composable
fun DebtScreens(store: Store, stack: List<DebtScreen>, hide: Boolean, onPush: (DebtScreen) -> Unit, onPop: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    stack.forEachIndexed { i, s ->
        val top = i == stack.lastIndex
        when (s) {
            is DebtScreen.Person -> PersonScreen(store, ledger, s.key, hide, top, onPush, onPop)
            is DebtScreen.Detail -> ledger.debts.firstOrNull { it.id == s.debtId }?.let { DebtDetailSheet(store, ledger, it, onPush, onPop) } ?: onPopLater(onPop)
            is DebtScreen.New -> DebtForm(store, ledger, null, s.person, onPop)
            is DebtScreen.Edit -> ledger.debts.firstOrNull { it.id == s.debtId }?.let { DebtForm(store, ledger, it, it.person, onPop) } ?: onPopLater(onPop)
            is DebtScreen.Pay -> ledger.debts.firstOrNull { it.id == s.debtId }?.let { DebtPaymentForm(store, ledger, it, onPop) } ?: onPopLater(onPop)
        }
    }
}

/** La deuda ya no existe (se borró): se cierra sola. */
@Composable
private fun onPopLater(onPop: () -> Unit) {
    androidx.compose.runtime.LaunchedEffect(Unit) { onPop() }
}

// MARK: Persona

@Composable
private fun PersonScreen(store: Store, ledger: Ledger, key: String, hide: Boolean, top: Boolean, onPush: (DebtScreen) -> Unit, onPop: () -> Unit) {
    BackHandler(enabled = top, onBack = onPop)
    val context = LocalContext.current
    val today = LocalDate.now()
    var showsSettled by remember { mutableStateOf(false) }
    val debts = DebtMath.debtsOf(key, ledger.debts)
    val payments = ledger.debtPayments
    val open = DebtMath.open(debts, payments)
    val settled = DebtMath.settled(debts, payments)
    val totals = DebtMath.totals(debts, payments)
    val name = debts.maxByOrNull { it.date }?.person?.let(DebtMath::cleanName) ?: ""
    val net = totals.owedToMeMinor - totals.iOweMinor
    val (owed, owedDue) = DebtMath.owedToMe(key, debts, payments)
    Box(Modifier.fillMaxSize().background(Palette.fondo).clickable(interactionSource = null, indication = null) {}) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(Spacing.s5),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                BackButton("Volver a Mi dinero", onPop)
                T(name, Type.titulo3, modifier = Modifier.weight(1f).padding(top = Spacing.s2, end = Size.toqueMinimo), align = TextAlign.Center, maxLines = 1)
            }
            if (debts.isEmpty()) T("Ya no hay deudas con esta persona.", Type.cuerpo, Palette.texto2)
            else {
                val (_, fg) = debtColors(net)
                Card {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                        PersonTile(name, net, 56.dp)
                        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                            T(if (net > 0) "Te debe" else if (net < 0) "Le debes" else "Están a mano", Type.cuerpo2, Palette.texto2)
                            T(if (hide) "••••••" else money(abs(net)), Type.cifraGrande, fg, maxLines = 1)
                            if (totals.owedToMeMinor > 0 && totals.iOweMinor > 0 && !hide)
                                T(DebtMath.summaryText(totals, Currency.current).replace("Te deben", "Te debe").replace("Debes", "Le debes"), Type.leyenda, Palette.texto2)
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3), verticalAlignment = Alignment.CenterVertically) {
                    if (owed > 0) SecondaryButton("Recordarle", Modifier.weight(1f)) {
                        shareReminder(context, DebtMath.shareText(name, owed, owedDue, Currency.current, today))
                    }
                    PrimaryButton("+ Deuda", Modifier.weight(1f)) { onPush(DebtScreen.New(name)) }
                }
                if (open.isNotEmpty()) {
                    SectionLabel("Pendientes")
                    Card(padding = Spacing.s3) {
                        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) { open.forEach { d -> DebtRow(d, payments, hide, today) { onPush(DebtScreen.Detail(d.id)) } } }
                    }
                }
                if (settled.isNotEmpty()) {
                    Row(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clickable { showsSettled = !showsSettled }, verticalAlignment = Alignment.CenterVertically) {
                        T("SALDADAS (${settled.size})", Type.leyenda, Palette.texto2)
                        Icon(if (showsSettled) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown, null, Modifier.size(18.dp), tint = Palette.texto2)
                    }
                    if (showsSettled) Card(padding = Spacing.s3) {
                        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) { settled.forEach { d -> DebtRow(d, payments, hide, today) { onPush(DebtScreen.Detail(d.id)) } } }
                    }
                }
            }
        }
    }
}

@Composable
private fun DebtRow(d: DebtRecord, payments: List<DebtPaymentRecord>, hide: Boolean, today: LocalDate, onClick: () -> Unit) {
    val left = DebtMath.remaining(d, payments)
    val status = DebtMath.status(d, payments, today)
    val parts = mutableListOf(if (d.direction == DebtDirection.ME_DEBE) "Te debe" else "Le debes", DueText.shortDate(d.date, today))
    if (status == DebtStatus.SALDADA) parts += "Saldada"
    else d.dueDate?.let { parts += if (status == DebtStatus.VENCIDA) "venció ${DueText.shortDate(it, today)}" else "vence ${DueText.describe(it, today).lowercase()}" }
    val meDebe = d.direction == DebtDirection.ME_DEBE
    val color = if (status == DebtStatus.SALDADA) Palette.texto2 else if (meDebe) Palette.hielo else Palette.brasaTinta
    val icon: ImageVector = if (meDebe) Icons.AutoMirrored.Rounded.CallMade else Icons.AutoMirrored.Rounded.CallReceived
    RowLine(onClick, { IconTile(icon, if (meDebe) Palette.hieloVelo else Palette.brasaVelo, color) },
        d.note ?: if (meDebe) "Le prestaste" else "Te prestó", parts.joinToString(" · ")) {
        T(if (hide) "••••••" else money(if (status == DebtStatus.SALDADA) d.amountMinor else left), Type.cifraPequena, color)
        if (status != DebtStatus.SALDADA && left < d.amountMinor && !hide) T("de ${money(d.amountMinor)}", Type.leyenda, Palette.texto2)
        else if (status == DebtStatus.VENCIDA) T("Vencida", Type.leyenda, Palette.peligro)
    }
}

// MARK: Detalle de una deuda

@Composable
private fun DebtDetailSheet(store: Store, ledger: Ledger, d: DebtRecord, onPush: (DebtScreen) -> Unit, onPop: () -> Unit) {
    val context = LocalContext.current
    val today = LocalDate.now()
    val payments = ledger.debtPayments
    val left = DebtMath.remaining(d, payments)
    val status = DebtMath.status(d, payments, today)
    val history = payments.filter { it.debtId == d.id }.sortedByDescending { it.date }
    val meDebe = d.direction == DebtDirection.ME_DEBE
    var confirmDelete by remember { mutableStateOf(false) }
    var removing by remember { mutableStateOf<DebtPaymentRecord?>(null) }
    FormSheet(d.person, onPop, confirm = "Editar", onConfirm = { onPush(DebtScreen.Edit(d.id)) }, cancel = "Cerrar") {
        Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(if (meDebe) "${d.person} te debe" else "Le debes a ${d.person}", Type.cuerpo2, Palette.texto2, Modifier.weight(1f))
                    when (status) {
                        DebtStatus.SALDADA -> Badge(status.title, Palette.superficie3, Palette.texto1)
                        DebtStatus.VENCIDA -> Badge(status.title, Palette.peligroVelo, Palette.peligro)
                        DebtStatus.PENDIENTE -> Badge(status.title, Palette.hieloVelo, Palette.hielo)
                    }
                }
                T(money(left), Type.cifraGrande, if (status == DebtStatus.SALDADA) Palette.texto2 else if (meDebe) Palette.hielo else Palette.brasaTinta, maxLines = 1)
                val line = mutableListOf("De ${money(d.amountMinor)}", DueText.shortDate(d.date, today))
                d.dueDate?.let { line += "vence el ${DueText.shortDate(it, today)}" }
                ledger.product(d.productId)?.let { line += if (meDebe) "salió de ${it.name}" else "llegó a ${it.name}" }
                T(line.joinToString(" · "), Type.leyenda, Palette.texto2)
                d.note?.let { T(it, Type.cuerpo2) }
            }
        }
        if (status != DebtStatus.SALDADA) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3), verticalAlignment = Alignment.CenterVertically) {
                SecondaryButton("Saldar", Modifier.weight(1f)) { store.settleDebt(d.id, today, d.productId); store.showUndo("Quedó saldada") }
                PrimaryButton("+ Abono", Modifier.weight(1f)) { onPush(DebtScreen.Pay(d.id)) }
            }
            if (meDebe) SecondaryButton("Recordarle") { shareReminder(context, DebtMath.shareText(d.person, left, d.dueDate, Currency.current, today)) }
        }
        SectionLabel("Abonos")
        Card(padding = Spacing.s3) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                if (history.isEmpty()) Box(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo), contentAlignment = Alignment.CenterStart) {
                    T("Todavía no hay abonos.", Type.cuerpo2, Palette.texto2)
                }
                history.forEach { p ->
                    RowLine({ removing = p }, { IconTile(Icons.Outlined.CheckCircle, Palette.superficie3, Palette.exito) }, "Abono",
                        listOfNotNull(DueText.shortDate(p.date, today), ledger.product(p.productId)?.name).joinToString(" · ")) {
                        T(money(p.amountMinor), Type.cifraPequena)
                    }
                }
            }
        }
        SecondaryButton("Borrar deuda", danger = true) { confirmDelete = true }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { T("¿Borrar esta deuda?", Type.titulo3) },
        text = { T("Se borran también sus abonos y lo que movieron en tus cuentas.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({
            confirmDelete = false
            val removed = store.deleteDebt(d.id)
            onPop()
            store.showUndo("Borraste la deuda con ${d.person}") { removed?.let { store.restoreDebt(it) } }
        }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
        dismissButton = { TextButton({ confirmDelete = false }) { T("Cancelar", Type.etiqueta) } }, containerColor = Palette.superficie2)
    removing?.let { p ->
        AlertDialog(onDismissRequest = { removing = null }, title = { T("¿Borrar este abono?", Type.titulo3) },
            confirmButton = { TextButton({ store.deleteDebtPayment(p.id); removing = null }) { T("Borrar abono", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ removing = null }) { T("Cancelar", Type.etiqueta) } }, containerColor = Palette.superficie2)
    }
}

// MARK: Formularios

/** Productos por donde puede pasar la plata: todo menos las tarjetas débito (mueven la plata de su cuenta). */
private fun moneyProducts(ledger: Ledger) = ledger.products.filter { it.kind != ProductKind.DEBITO }

@Composable
private fun ProductPicker(ledger: Ledger, question: String, selected: String?, onPick: (String?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        FormRow(question, ledger.product(selected)?.label ?: "No la anoto", onClick = { open = true })
        DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
            DropdownMenuItem({ T("No la anoto", Type.cuerpo) }, { onPick(null); open = false })
            moneyProducts(ledger).forEach { p -> DropdownMenuItem({ T(p.label, Type.cuerpo) }, { onPick(p.id); open = false }) }
        }
    }
}

private fun dateText(d: LocalDate) = "${d.dayOfMonth} ${DueText.months[d.monthValue - 1]} ${d.year}"

/** Agregar o editar una deuda: quién, hacia dónde, cuánto, fechas, nota y por qué cuenta pasó la plata. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DebtForm(store: Store, ledger: Ledger, debt: DebtRecord?, presetPerson: String, onDone: () -> Unit) {
    var person by remember { mutableStateOf(debt?.person ?: presetPerson) }
    var direction by remember { mutableStateOf(debt?.direction ?: DebtDirection.ME_DEBE) }
    var amount by remember { mutableStateOf(debt?.amountMinor ?: 0L) }
    var date by remember { mutableStateOf(debt?.date ?: LocalDate.now()) }
    var hasDue by remember { mutableStateOf(debt?.dueDate != null) }
    var due by remember { mutableStateOf(debt?.dueDate ?: LocalDate.now().plusDays(15)) }
    var note by remember { mutableStateOf(debt?.note ?: "") }
    var productId by remember { mutableStateOf(debt?.productId) }
    var picking by remember { mutableStateOf<String?>(null) }
    val canSave = DebtMath.cleanName(person).isNotEmpty() && amount > 0
    val suggestions = DebtMath.suggestions(person, ledger.debts)
    FormSheet(if (debt == null) "Nueva deuda" else "Editar deuda", onDone, canConfirm = canSave, onConfirm = {
        store.saveDebt(debt, person, direction, amount, date, if (hasDue) due else null, note, productId)
        if (hasDue) Permissions.askAfterFirstFixed()
        onDone()
    }) {
        Segmented(DebtDirection.entries.map { it.raw to it.title }, direction.raw) { direction = DebtDirection.from(it) }
        Card(padding = Spacing.s2) { FormTextField(person, "¿Quién?") { person = it } }
        if (suggestions.isNotEmpty()) FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            suggestions.forEach { n -> Chip(n) { person = n } }
        }
        MoneyField("Monto", amount) { amount = it }
        FormGroup(footer = if (hasDue) "Te avisamos el día antes." else null) {
            FormRow("Fecha", dateText(date), onClick = { picking = "fecha" })
            FormDivider()
            FormToggle("Tiene fecha límite", hasDue) { hasDue = it }
            if (hasDue) { FormDivider(); FormRow("Fecha límite", dateText(due), onClick = { picking = "limite" }) }
        }
        FormGroup(footer = "Opcional. Si eliges una cuenta, su saldo se mueve con esta deuda. No cuenta como gasto ni ingreso del mes.") {
            ProductPicker(ledger, DebtMath.productQuestion(direction, false), productId) { productId = it }
        }
        Card(padding = Spacing.s2) { FormTextField(note, "Nota (opcional)", singleLine = false) { note = it } }
    }
    picking?.let { which ->
        DatePickDialog(if (which == "fecha") date else due, { picking = null }) { if (which == "fecha") date = it else due = it; picking = null }
    }
}

/** Un abono: cuánto, cuándo y por qué cuenta pasó. */
@Composable
fun DebtPaymentForm(store: Store, ledger: Ledger, d: DebtRecord, onDone: () -> Unit) {
    val remaining = DebtMath.remaining(d, ledger.debtPayments)
    var amount by remember { mutableStateOf(remaining) }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var productId by remember { mutableStateOf(d.productId) }
    var picking by remember { mutableStateOf(false) }
    FormSheet("Abono", onDone, canConfirm = amount > 0, onConfirm = {
        store.addDebtPayment(d.id, amount, date, productId)
        onDone()
    }) {
        MoneyField("Monto", amount) { amount = it }
        FormGroup(footer = if (amount > remaining) "Falta ${money(remaining)}. El abono queda en ese valor." else "Falta ${money(remaining)}.") {
            FormRow("Fecha", dateText(date), onClick = { picking = true })
        }
        FormGroup {
            ProductPicker(ledger, DebtMath.productQuestion(d.direction, true), productId) { productId = it }
        }
    }
    if (picking) DatePickDialog(date, { picking = false }) { date = it; picking = false }
}
