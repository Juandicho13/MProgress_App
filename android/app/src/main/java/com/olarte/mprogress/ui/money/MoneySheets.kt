package com.olarte.mprogress.ui.money

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Ledger
import com.olarte.mprogress.data.Product
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/**
 * Transferir entre productos o pagar una tarjeta (F06-05). No cuenta como gasto ni como ingreso.
 * Pagar tarjeta trae la deuda de hoy como monto, en un campo que se ve editable.
 */
@Composable
fun TransferSheet(store: Store, from: String? = null, to: String? = null, onDone: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val options = ledger.products.filter { it.kind != ProductKind.DEBITO }
    var fromId by remember { mutableStateOf(from ?: options.firstOrNull { it.kind == ProductKind.CUENTA }?.id ?: options.firstOrNull()?.id) }
    var toId by remember { mutableStateOf(to ?: options.firstOrNull { it.kind == ProductKind.CREDITO }?.id ?: options.drop(1).firstOrNull()?.id) }
    // Pagar tarjeta: la deuda de hoy, lista para cambiarla si pagas otro valor.
    var amount by remember {
        val card = ledger.product(toId)?.takeIf { it.kind == ProductKind.CREDITO }
        mutableStateOf(AmountInput.prefilled(maxOf(0, card?.let { ledger.balance(it) } ?: 0), Currency.current))
    }
    var editing by remember { mutableStateOf(amount.text.isEmpty()) }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var picking by remember { mutableStateOf(false) }
    val target = ledger.product(toId)
    val canSave = fromId != null && toId != null && fromId != toId && amount.money.minor > 0
    fun label(p: Product?) = p?.let { listOfNotNull(it.label, ledger.institution(it)?.name).joinToString(" · ") } ?: "Elegir"

    OverlaySheet(onDone, Modifier.fillMaxSize().padding(top = 48.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.margen).padding(top = Spacing.s4), verticalAlignment = Alignment.CenterVertically) {
            CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onDone)
            T(if (target?.kind == ProductKind.CREDITO) "Pagar tarjeta" else "Transferir", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
            CircleIconButton(Icons.Rounded.Check, "Guardar", filled = true, enabled = canSave) {
                val t = TransferRecord(fromProductId = fromId!!, toProductId = toId!!, amountMinor = amount.money.minor, occurredAt = date)
                store.addTransfer(t); onDone()
                store.showUndo(if (target?.kind == ProductKind.CREDITO) "Pagaste ${target.name}" else "Moviste plata a ${target?.name}") { store.deleteTransfer(t.id) }
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen, vertical = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
            EditableAmountField(amount, editing) { editing = true }
            Card(padding = Spacing.s2) {
                ProductMenuRow("Desde", label(ledger.product(fromId)), options, ledger) { fromId = it }
                FormDivider()
                ProductMenuRow("Hacia", label(target), options, ledger) { toId = it }
                FormDivider()
                FormRow("Fecha", DueText.describe(date, LocalDate.now()).let { if (it.startsWith("En") || it.startsWith("Hace")) DueText.shortDate(date, LocalDate.now()) else it }, onClick = { picking = true })
            }
            if (fromId != null && fromId == toId) T("Elige dos productos distintos.", Type.cuerpo2, Palette.peligro)
            T("Mover plata entre tus productos no cuenta como gasto ni como ingreso.", Type.leyenda, Palette.texto2)
        }
        if (editing) Box(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s2)) {
            Keypad(amount.allowsDecimals, { amount = amount.press(it) }, { amount = amount.deleteLast() })
        }
    }
    if (picking) DatePickDialog(date, { picking = false }) { date = it; picking = false }
}

@Composable
private fun ProductMenuRow(title: String, value: String, options: List<Product>, ledger: Ledger, onPick: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        FormRow(title, value, onClick = { open = true })
        DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
            options.forEach { p ->
                DropdownMenuItem({ T(listOfNotNull(p.label, ledger.institution(p)?.name).joinToString(" · "), Type.cuerpo) }, { onPick(p.id); open = false },
                    leadingIcon = { Icon(InstitutionStyle.symbol(p.kind), null, Modifier.size(18.dp), tint = Palette.texto2) })
            }
        }
    }
}

/** Puntos y millas dentro de Mi dinero: saldo, valor aproximado y vencimiento, igual que RewardsSection de iOS. */
@Composable
fun RewardsSection(store: Store, ledger: Ledger, hide: Boolean) {
    var adding by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<RewardRecord?>(null) }
    val today = LocalDate.now()
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { SectionLabel("Puntos y millas") }
            T("+ Agregar", Type.etiqueta, Palette.brasaTinta, Modifier.heightIn(min = 48.dp).clickable { adding = true }.padding(vertical = 15.dp, horizontal = 4.dp))
        }
        if (ledger.rewards.isEmpty()) {
            Box(Modifier.clickable { adding = true }) {
                Card {
                    ListRow(icon = Icons.Outlined.StarOutline, tint = Palette.oroRelleno.copy(alpha = 0.18f), fg = Palette.oro, title = "Puntos Colombia, LifeMiles…",
                        subtitle = "Lleva tus puntos y millas junto a tu plata") { Icon(Icons.Rounded.Add, null, tint = Palette.texto2) }
                }
            }
        } else Card(padding = Spacing.s3) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                ledger.rewards.forEach { r ->
                    val card = ledger.products.firstOrNull { it.rewardProgramId == r.id }
                    val subtitle = listOfNotNull(r.kind.title, card?.label, card?.pointsPerThousand?.let { rateText(it, r.kind) }, RewardMath.expiryText(r, today)).joinToString(" · ")
                    val hex = RewardMath.suggestions.firstOrNull { it.first == r.name }?.third ?: InstitutionStyle.palette[2]
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable { editing = r }.padding(vertical = Spacing.s1), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                        InstitutionStyle.Tile(r.name, hex)
                        Column(Modifier.weight(1f)) { T(r.name, Type.titulo3, maxLines = 1); T(subtitle, Type.cuerpo2, Palette.texto2, maxLines = 1) }
                        Column(horizontalAlignment = Alignment.End) {
                            T(if (hide) "••••" else RewardMath.balanceText(r), Type.cifraPequena)
                            RewardMath.estimatedValueMinor(r, Currency.current)?.takeIf { !hide }?.let { T("≈ ${Money(it).formatted()}", Type.leyenda, Palette.oro) }
                        }
                    }
                }
                val total = RewardMath.totalValueMinor(ledger.rewards, Currency.current)
                if (total > 0 && !hide) {
                    FormDivider()
                    Row { T("Valen aprox.", Type.cuerpo2, Palette.texto2, Modifier.weight(1f)); T(Money(total).formatted(), Type.cifraPequena, Palette.oro) }
                }
            }
        }
    }
    if (adding) RewardForm(store, null) { adding = false }
    editing?.let { r -> RewardForm(store, r) { editing = null } }
}

/** "2 puntos por cada $ 1.000". */
fun rateText(rate: Double, kind: RewardKind): String {
    val shown = if (rate % 1.0 == 0.0) rate.toLong().toString() else rate.toString().replace('.', ',')
    val unit = if (rate == 1.0) kind.unit.dropLast(1) else kind.unit
    return "$shown $unit por cada ${Money.units(1000, Currency.current).formatted()}"
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun RewardForm(store: Store, reward: RewardRecord?, onDone: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    var name by remember { mutableStateOf(reward?.name ?: "") }
    var kind by remember { mutableStateOf(reward?.kind ?: RewardKind.PUNTOS) }
    var balance by remember { mutableStateOf(reward?.balance?.let { Money.groupThousands(it) } ?: "") }
    var value by remember { mutableStateOf(reward?.valuePerPoint?.toString()?.replace('.', ',') ?: "") }
    var hasExpiry by remember { mutableStateOf(reward?.expiresAt != null) }
    var expires by remember { mutableStateOf(reward?.expiresAt ?: LocalDate.now().plusMonths(6)) }
    var picking by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }
    FormSheet(if (reward == null) "Puntos o millas" else "Actualizar saldo", onDone, canConfirm = name.isNotBlank(), onConfirm = {
        store.saveReward((reward ?: RewardRecord(name = name, kind = kind, balance = 0)).copy(name = name.trim(), kind = kind,
            balance = balance.filter(Char::isDigit).toLongOrNull() ?: 0, valuePerPoint = value.replace(',', '.').toDoubleOrNull(), expiresAt = if (hasExpiry) expires else null))
        onDone()
    }) {
        if (reward == null) FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            RewardMath.suggestions.forEach { (n, k, _) -> Chip(n, name == n) { name = if (n == "Otro") "" else n; kind = k } }
        }
        Card(padding = Spacing.s2) {
            FormTextField(name, "Nombre del programa") { name = it }
            FormDivider()
            Segmented(RewardKind.entries.map { it.raw to it.title }, kind.raw) { kind = RewardKind.from(it) }
            FormTextField(balance, "Saldo de ${kind.unit}", KeyboardType.Number) { t -> val d = t.filter(Char::isDigit).take(12); balance = if (d.isEmpty()) "" else Money.groupThousands(d.toLong()) }
        }
        FormGroup(footer = "Opcional. Con ese valor te mostramos cuánta plata son tus ${kind.unit}. Lo encuentras en la app del programa.") {
            FormTextField(value, "¿Cuánto vale cada uno? (${Currency.current.symbol})", KeyboardType.Decimal) { value = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }
        }
        Card(padding = Spacing.s2) {
            FormToggle("Tienen vencimiento", hasExpiry) { hasExpiry = it }
            if (hasExpiry) { FormDivider(); FormRow("Vencen", "${expires.dayOfMonth} ${DueText.months[expires.monthValue - 1]} ${expires.year}", onClick = { picking = true }) }
        }
        T("Para que se sumen solos, abre la tarjeta en Dinero y elige este programa con sus puntos por cada ${Money.units(1000, Currency.current).formatted()}.", Type.leyenda, Palette.texto2)
        if (reward != null) SecondaryButton("Borrar", danger = true) { confirm = true }
    }
    if (picking) DatePickDialog(expires, { picking = false }) { expires = it; picking = false }
    if (confirm && reward != null) AlertDialog(onDismissRequest = { confirm = false }, title = { T("¿Borrar ${reward.name}?", Type.titulo3) },
        confirmButton = { TextButton({ store.deleteReward(reward.id); confirm = false; onDone() }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
        dismissButton = { TextButton({ confirm = false }) { T("Cancelar", Type.etiqueta) } }, containerColor = Palette.superficie2)
}
