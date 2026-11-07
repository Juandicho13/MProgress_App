package com.olarte.mprogress.ui.money

import com.olarte.mprogress.ui.components.appTextField

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.MoreHoriz
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Institution
import com.olarte.mprogress.data.Ledger
import com.olarte.mprogress.data.Product
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.MoneyCalculator
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.components.BackButton
import com.olarte.mprogress.ui.components.DayGridSheet
import com.olarte.mprogress.ui.components.FormDivider
import com.olarte.mprogress.ui.components.FormRow
import com.olarte.mprogress.ui.components.FormToggle
import com.olarte.mprogress.ui.components.MoneyField
import com.olarte.mprogress.domain.monthlyYield
import com.olarte.mprogress.domain.Currency
import androidx.compose.foundation.layout.width
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.CircleIconButton
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.InstitutionStyle
import com.olarte.mprogress.ui.components.OverlaySheet
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

private const val HIDE_KEY = "dinero.ocultarSaldos"

private fun money(minor: Long) = Money(minor).formatted()
private fun hexOf(i: Institution) = i.colorHex ?: InstitutionStyle.hexFor(i.name)

private sealed interface MoneySheet {
    data object NewBank : MoneySheet
    data class NewProduct(val institutionId: String, val kind: ProductKind) : MoneySheet
    data class Edit(val product: Product) : MoneySheet
    data class Transfer(val from: String? = null, val to: String? = null) : MoneySheet
}

/** Mi dinero (pantalla 31) y Mi dinero vacío (pantalla 40), igual que MoneyView de iOS. */
@Composable
fun MoneyScreen(store: Store, initialDetail: String? = null) {
    val ledger by store.ledger.collectAsState()
    var hide by remember { mutableStateOf(store.prefs.getBoolean(HIDE_KEY, false)) }
    var detail by remember { mutableStateOf(initialDetail) }
    var sheet by remember { mutableStateOf<MoneySheet?>(null) }
    var debts by remember { mutableStateOf(listOf<DebtScreen>()) }
    BackHandler(enabled = detail != null && sheet == null) { detail = null }

    Box(Modifier.fillMaxSize()) {
        val inst = ledger.institutions.firstOrNull { it.id == detail }
        if (inst != null) InstitutionDetail(store, ledger, inst, hide, { detail = null }) { sheet = it }
        else Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(Spacing.s5),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("Mi dinero", Type.titulo1, modifier = Modifier.weight(1f))
                if (ledger.institutions.isNotEmpty()) CircleIconButton(if (hide) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                    if (hide) "Mostrar saldos" else "Ocultar saldos") { hide = !hide; store.prefs.edit().putBoolean(HIDE_KEY, hide).apply() }
            }
            if (ledger.institutions.isEmpty()) EmptyMoney { sheet = MoneySheet.NewBank }
            else {
                val (have, owe, net) = MoneyCalculator.netWorth(ledger.productRecords, ledger.entries, ledger.transfers)
                Card {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        T("Patrimonio neto", Type.cuerpo2, Palette.texto2)
                        T(if (hide) "••••••" else money(net), Type.cifraGrande, if (net < 0) Palette.peligro else Palette.texto1, maxLines = 1)
                        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                            Dot(Palette.hielo, "Tienes ${if (hide) "••••" else money(have)}")
                            Dot(Palette.brasa, "Debes ${if (hide) "••••" else money(owe)}")
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3), verticalAlignment = Alignment.CenterVertically) {
                    SecondaryButton("Transferir", Modifier.weight(1f), enabled = ledger.products.count { it.kind != ProductKind.DEBITO } >= 2) { sheet = MoneySheet.Transfer() }
                    PrimaryButton("+ Banco", Modifier.weight(1f)) { sheet = MoneySheet.NewBank }
                }
                SectionLabel("Bancos y billeteras")
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        ledger.institutions.forEach { i ->
                            val products = ledger.products.filter { it.institutionId == i.id }
                            val haveI = products.filter { !it.kind.isDebt && it.kind != ProductKind.DEBITO }.sumOf { ledger.balance(it) }
                            val oweI = products.filter { it.kind.isDebt }.sumOf { ledger.balance(it) }
                            Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable { detail = i.id }.padding(vertical = Spacing.s1),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                                InstitutionStyle.Tile(i.name, hexOf(i))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    T(i.name, Type.titulo3, maxLines = 1)
                                    T(kindsSubtitle(products.map { it.kind }), Type.cuerpo2, Palette.texto2, maxLines = 1)
                                }
                                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    T(if (hide) "••••••" else money(haveI), Type.cifraPequena)
                                    if (!hide && oweI > 0) T("debes ${money(oweI)}", Type.leyenda, Palette.brasaTinta)
                                    else if (!hide) products.filter { it.kind.earnsYield }.sumOf { monthlyYield(ledger.balance(it), it.rateEA) }
                                        .takeIf { it > 0 }?.let { T("+ ${money(it)} rendimiento", Type.leyenda, Palette.exito) }
                                }
                            }
                        }
                    }
                }
                DebtsSection(ledger, hide) { debts = debts + it }
                RewardsSection(store, ledger, hide)
            }
            PlanningSection(ledger)
        }
        DebtScreens(store, debts, hide, onPush = { debts = debts + it }, onPop = { debts = debts.dropLast(1) })
        when (val s = sheet) {
            is MoneySheet.Transfer -> TransferSheet(store, s.from, s.to) { sheet = null }
            MoneySheet.NewBank -> AddInstitutionSheet(store) { sheet = null }
            is MoneySheet.NewProduct -> ProductFormSheet(store, ledger, ledger.institutions.first { it.id == s.institutionId }, s.kind, null) { sheet = null }
            is MoneySheet.Edit -> ProductFormSheet(store, ledger, ledger.institutions.first { it.id == s.product.institutionId }, s.product.kind, s.product,
                onPay = { sheet = MoneySheet.Transfer(to = s.product.id) }) { sheet = null }
            null -> {}
        }
    }
}

/** "Cuenta y 2 tarjetas", como WalletMath.subtitle de iOS. */
private fun kindsSubtitle(kinds: List<ProductKind>): String {
    if (kinds.isEmpty()) return "Sin cuentas"
    val parts = mutableListOf<String>()
    val accounts = kinds.count { it == ProductKind.CUENTA }
    val cards = kinds.count { it == ProductKind.CREDITO || it == ProductKind.DEBITO }
    val pockets = kinds.count { it == ProductKind.BOLSILLO }
    val boxes = kinds.count { it == ProductKind.CAJITA }
    if (kinds.contains(ProductKind.EFECTIVO)) parts += "Billetera física"
    if (accounts > 0) parts += if (accounts == 1) "Cuenta" else "$accounts cuentas"
    if (pockets > 0) parts += if (pockets == 1) "1 bolsillo" else "$pockets bolsillos"
    if (boxes > 0) parts += if (boxes == 1) "1 cajita" else "$boxes cajitas"
    if (cards > 0) parts += if (cards == 1) "1 tarjeta" else "$cards tarjetas"
    return if (parts.size <= 1) parts.joinToString("") else parts.dropLast(1).joinToString(", ") + " y " + parts.last()
}

@Composable
private fun Dot(color: Color, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        T(text, Type.leyenda, Palette.texto2)
    }
}

@Composable
private fun EmptyMoney(onAdd: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(vertical = Spacing.s8), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            InstitutionStyle.Tile("Banco", 0xF5C451, 52.dp); InstitutionStyle.Tile("Nu", 0xA68CFF, 52.dp); InstitutionStyle.Tile("Efectivo", 0x3A3F47, 52.dp)
        }
        T("¿De dónde sale tu plata?", Type.titulo2, align = TextAlign.Center)
        T("Agrega tus bancos, tarjetas y bolsillos para saber con qué pagas y cuánto tienes en total.", Type.cuerpo, Palette.texto2, align = TextAlign.Center)
        PrimaryButton("Agregar banco o billetera", onClick = onAdd)
        Spacer(Modifier.heightIn(min = Spacing.s8))
        T("Solo los últimos 4 dígitos de cada tarjeta. Nunca te pedimos claves.", Type.leyenda, Palette.texto2, align = TextAlign.Center)
    }
}

// MARK: Detalle de banco (pantalla 32)

@Composable
private fun InstitutionDetail(store: Store, ledger: Ledger, inst: Institution, hide: Boolean, onBack: () -> Unit, onSheet: (MoneySheet) -> Unit) {
    val products = ledger.products.filter { it.institutionId == inst.id }
    val net = products.filter { it.kind != ProductKind.DEBITO }.sumOf { if (it.kind.isDebt) -ledger.balance(it) else ledger.balance(it) }
    var menu by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf<String?>(null) }
    var deleting by remember { mutableStateOf(false) }
    val tint = InstitutionStyle.color(hexOf(inst))
    val today = LocalDate.now()

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BackButton("Volver a Mi dinero", onBack)
            T(inst.name, Type.titulo3, modifier = Modifier.weight(1f).padding(top = Spacing.s2), align = TextAlign.Center, maxLines = 1)
            Box(Modifier.padding(top = Spacing.s2)) {
                CircleIconButton(Icons.Rounded.MoreHoriz, "Más opciones") { menu = true }
                DropdownMenu(menu, { menu = false }, containerColor = Palette.superficie2) {
                    DropdownMenuItem({ T("Cambiar nombre", Type.cuerpo) }, { menu = false; renaming = inst.name }, leadingIcon = { Icon(Icons.Rounded.Edit, null, tint = Palette.texto1) })
                    DropdownMenuItem({ T("Borrar banco", Type.cuerpo, Palette.peligro) }, { menu = false; deleting = true }, leadingIcon = { Icon(Icons.Outlined.Delete, null, tint = Palette.peligro) })
                }
            }
        }
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.tarjeta)).background(Brush.linearGradient(listOf(tint.copy(alpha = 0.35f), Palette.superficie1))).padding(Spacing.s5),
            verticalArrangement = Arrangement.spacedBy(Spacing.s2),
        ) {
            T("Total en ${inst.name}", Type.cuerpo2, Palette.texto2)
            T(if (hide) "••••••" else money(net), Type.cifraGrande, maxLines = 1)
        }
        listOf((if (inst.name == "Efectivo") "Efectivo" else "Cuenta") to setOf(ProductKind.CUENTA, ProductKind.EFECTIVO), "Bolsillos" to setOf(ProductKind.BOLSILLO), "Cajitas" to setOf(ProductKind.CAJITA), "Tarjetas" to setOf(ProductKind.CREDITO, ProductKind.DEBITO)).forEach { (title, kinds) ->
            val items = products.filter { it.kind in kinds }
            if (items.isNotEmpty()) {
                SectionLabel(title)
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        items.forEach { p -> ProductRow(ledger, p, hide, today) { onSheet(MoneySheet.Edit(p)) } }
                    }
                }
            }
        }
        if (products.isEmpty()) T("Agrega la cuenta, bolsillos, cajitas o tarjetas que tienes en ${inst.name}.", Type.cuerpo, Palette.texto2)
        if (inst.name == "Efectivo") {
            SecondaryButton("+ Efectivo") { onSheet(MoneySheet.NewProduct(inst.id, ProductKind.EFECTIVO)) }
            T("Crea uno por cada lugar donde guardas billetes: Billetera, Casa, Alcancía. Mueve plata entre ellos con Transferir.", Type.leyenda, Palette.texto2)
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                SecondaryButton("+ Bolsillo", Modifier.weight(1f)) { onSheet(MoneySheet.NewProduct(inst.id, ProductKind.BOLSILLO)) }
                SecondaryButton("+ Cajita", Modifier.weight(1f)) { onSheet(MoneySheet.NewProduct(inst.id, ProductKind.CAJITA)) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                SecondaryButton("+ Tarjeta", Modifier.weight(1f)) { onSheet(MoneySheet.NewProduct(inst.id, ProductKind.CREDITO)) }
                SecondaryButton("+ Cuenta", Modifier.weight(1f)) { onSheet(MoneySheet.NewProduct(inst.id, ProductKind.CUENTA)) }
            }
        }
    }

    renaming?.let { value ->
        AlertDialog(
            onDismissRequest = { renaming = null },
            title = { T("Nombre del banco", Type.titulo3) },
            text = { TextBox(value, "Nombre") { renaming = it } },
            confirmButton = { TextButton({ value.trim().takeIf { it.isNotEmpty() }?.let { store.renameInstitution(inst.id, it) }; renaming = null }) { T("Guardar", Type.etiqueta, Palette.brasaTinta) } },
            dismissButton = { TextButton({ renaming = null }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
    if (deleting) {
        AlertDialog(
            onDismissRequest = { deleting = false },
            title = { T("¿Borrar ${inst.name}?", Type.titulo3) },
            text = { T("Se borran sus cuentas, bolsillos, cajitas y tarjetas. Tus movimientos se quedan.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ deleting = false; onBack(); store.deleteInstitution(inst.id) }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ deleting = false }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}

@Composable
private fun ProductRow(ledger: Ledger, p: Product, hide: Boolean, today: LocalDate, onClick: () -> Unit) {
    val balance = ledger.balance(p)
    val subtitle = when (p.kind) {
        ProductKind.CUENTA -> "Disponible para gastar"
        ProductKind.EFECTIVO -> "Billetera física"
        ProductKind.BOLSILLO, ProductKind.CAJITA -> p.rateEA?.let { "Rentabilidad ${if (it % 1.0 == 0.0) it.toLong().toString() else it.toString().replace('.', ',')}% E.A." } ?: "Sin rentabilidad"
        ProductKind.DEBITO -> listOfNotNull("Física", ledger.products.firstOrNull { it.id == p.parentProductId }?.name?.let { "de $it" }).joinToString(" · ")
        ProductKind.CREDITO -> listOfNotNull(p.creditLimitMinor?.let { "Cupo ${money(it)}" }, p.cutDay?.let { "corte día $it" }, p.dueDay?.let { d ->
            var next = today.withDayOfMonth(minOf(d, today.lengthOfMonth()))
            if (next.isBefore(today)) next = next.plusMonths(1).let { it.withDayOfMonth(minOf(d, it.lengthOfMonth())) }
            "pago ${DueText.describe(next, today).lowercase()}"
        }).joinToString(" · ").ifEmpty { "Tarjeta de crédito" }
    }
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(onClick = onClick).padding(vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        IconTile(InstitutionStyle.symbol(p.kind))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(p.last4?.let { "${p.name} ·· $it" } ?: p.name, Type.titulo3, maxLines = 1)
            T(subtitle, Type.cuerpo2, Palette.texto2, maxLines = 1)
        }
        if (p.kind != ProductKind.DEBITO) Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(if (hide || p.hidden) "••••••" else Money(if (p.kind == ProductKind.CREDITO) -balance else balance).formatted(), Type.cifraPequena,
                if (p.kind == ProductKind.CREDITO && balance > 0) Palette.brasaTinta else Palette.texto1)
            if (!hide && !p.hidden) {
                val y = if (p.kind.earnsYield) monthlyYield(balance, p.rateEA) else 0
                if (y > 0) T("+ ${money(y)}", Type.leyenda, Palette.exito)
                p.creditLimitMinor?.takeIf { p.kind == ProductKind.CREDITO }?.let { T("disponible ${money(maxOf(0, it - balance))}", Type.leyenda, Palette.texto2) }
            }
        }
    }
}

// MARK: Hojas

@Composable
private fun SheetBar(title: String, canSave: Boolean, onClose: () -> Unit, onSave: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.margen).padding(top = Spacing.s4), verticalAlignment = Alignment.CenterVertically) {
        CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onClose)
        T(title, Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center, maxLines = 1)
        CircleIconButton(Icons.Rounded.Check, "Guardar", filled = true, enabled = canSave, onClick = onSave)
    }
}

/** "+ Banco": nombre y color, como AddInstitutionView de iOS. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun AddInstitutionSheet(store: Store, onDone: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var hex by remember { mutableStateOf(InstitutionStyle.palette[0]) }
    val clean = name.trim()
    OverlaySheet(onDone, Modifier.fillMaxSize().padding(top = 48.dp)) {
        SheetBar("Nuevo banco", clean.isNotEmpty(), onDone) {
            if (clean.equals("Efectivo", true)) {
                val id = store.ledger.value.institutions.firstOrNull { it.name.equals("Efectivo", true) }?.id ?: store.addInstitution("Efectivo", 0x3A3F47)
                if (store.ledger.value.products.none { it.institutionId == id }) store.addProduct(id, ProductKind.EFECTIVO, "Billetera", null, 0, null)
            } else store.addInstitution(clean, hex)
            onDone()
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen, vertical = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                InstitutionStyle.Tile(clean.ifEmpty { "?" }, hex, 60.dp)
                Box(Modifier.weight(1f)) {
                    if (name.isEmpty()) T("Nombre del banco o billetera", Type.titulo2, Palette.texto2, maxLines = 1)
                    BasicTextField(name, { name = it }, Modifier.appTextField().fillMaxWidth(), textStyle = Type.titulo2.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true)
                }
            }
            SectionLabel("Sugerencias")
            FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                InstitutionStyle.suggestions.forEach { (n, h) -> Chip(n) { name = n; hex = h } }
            }
            SectionLabel("Color")
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                InstitutionStyle.palette.forEach { h ->
                    Box(Modifier.widthIn(min = 36.dp).heightIn(min = Size.toqueMinimo).clickable { hex = h }, contentAlignment = Alignment.Center) {
                        Box(Modifier.size(38.dp).border(2.dp, if (hex == h) Palette.texto1 else Color.Transparent, CircleShape).padding(3.dp).clip(CircleShape).background(InstitutionStyle.color(h)))
                    }
                }
            }
            T("No nos conectamos a tu banco. Tú pones los saldos y nosotros llevamos la cuenta.", Type.leyenda, Palette.texto2)
        }
    }
}

/** Agregar o editar cuenta, tarjeta, bolsillo, cajita o efectivo, como ProductFormView de iOS. Solo los últimos 4 de la tarjeta. */
@Composable
internal fun ProductFormSheet(store: Store, ledger: Ledger, inst: Institution, initialKind: ProductKind, editing: Product?, onPay: () -> Unit = {}, onDone: () -> Unit) {
    var kind by remember { mutableStateOf(initialKind) }
    var name by remember { mutableStateOf(editing?.name ?: "") }
    var last4 by remember { mutableStateOf(editing?.last4 ?: "") }
    val startBalance = editing?.let { ledger.balance(it) } ?: 0L
    var balance by remember { mutableStateOf(startBalance) }
    var limit by remember { mutableStateOf(editing?.creditLimitMinor ?: 0L) }
    var rate by remember { mutableStateOf(editing?.rateEA?.toString()?.replace('.', ',') ?: "") }
    var cutDay by remember { mutableStateOf(editing?.cutDay) }
    var dueDay by remember { mutableStateOf(editing?.dueDay) }
    var parentId by remember { mutableStateOf(editing?.parentProductId) }
    var hidden by remember { mutableStateOf(editing?.hidden ?: false) }
    var rewardId by remember { mutableStateOf(editing?.rewardProgramId) }
    var points by remember { mutableStateOf(editing?.pointsPerThousand?.let { if (it % 1.0 == 0.0) it.toLong().toString() else it.toString().replace('.', ',') } ?: "") }
    var pickDay by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    val isCard = kind == ProductKind.CREDITO || kind == ProductKind.DEBITO
    val last4Valid = last4.isEmpty() || last4.length == 4
    val kindName = when (kind) { ProductKind.CUENTA -> "Cuenta"; ProductKind.DEBITO -> "Tarjeta débito"; ProductKind.CREDITO -> "Tarjeta crédito"; ProductKind.BOLSILLO -> "Bolsillo"; ProductKind.CAJITA -> "Cajita"; ProductKind.EFECTIVO -> "Efectivo" }
    val accounts = ledger.products.filter { it.institutionId == inst.id && it.kind == ProductKind.CUENTA }

    Box(Modifier.fillMaxSize()) {
        OverlaySheet(onDone, Modifier.fillMaxSize().padding(top = 48.dp)) {
            SheetBar(if (editing == null) "Agregar a ${inst.name}" else "Editar", last4Valid, onDone) {
                val base = editing ?: Product(institutionId = inst.id, kind = kind, name = "", balanceMinor = 0)
                var p = base.copy(kind = kind, name = name.trim().ifEmpty { kindName }, last4 = last4.ifEmpty { null },
                    creditLimitMinor = if (kind == ProductKind.CREDITO && limit > 0) limit else null, cutDay = if (kind == ProductKind.CREDITO) cutDay else null,
                    dueDay = if (kind == ProductKind.CREDITO) dueDay else null, rateEA = if (kind.earnsYield) rate.replace(',', '.').toDoubleOrNull() else null,
                    parentProductId = if (kind == ProductKind.DEBITO) parentId else null, hidden = hidden,
                    rewardProgramId = if (isCard) rewardId else null, pointsPerThousand = if (isCard && rewardId != null) points.replace(',', '.').toDoubleOrNull() else null)
                if (editing == null) p = p.copy(balanceMinor = if (kind == ProductKind.DEBITO) 0 else balance, balanceAt = LocalDate.now())
                else if (kind != ProductKind.DEBITO && balance != startBalance) p = p.copy(balanceMinor = balance, balanceAt = LocalDate.now().plusDays(1))
                store.saveProduct(p)
                onDone()
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen, vertical = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
                if (editing == null && kind != ProductKind.EFECTIVO) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        SectionLabel("¿Qué es?")
                        listOf(listOf(Triple(ProductKind.CUENTA, "Cuenta", "Ahorros o corriente"), Triple(ProductKind.DEBITO, "Tarjeta débito", "Ligada a una cuenta")),
                            listOf(Triple(ProductKind.CREDITO, "Tarjeta crédito", "Cupo, corte y pago"), Triple(ProductKind.BOLSILLO, "Bolsillo", "Apartada en tu cuenta")),
                            listOf(Triple(ProductKind.CAJITA, "Cajita", "Ahorro aparte que rinde"))).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                                row.forEach { (k, t, sub) ->
                                    val on = kind == k
                                    Column(Modifier.weight(1f).heightIn(min = 64.dp).clip(RoundedCornerShape(Radius.campo)).background(if (on) Palette.brasaVelo else Palette.superficie3)
                                        .border(1.5.dp, if (on) Palette.brasa else Color.Transparent, RoundedCornerShape(Radius.campo)).clickable { kind = k }.padding(horizontal = Spacing.s3),
                                        verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically)) {
                                        T(t, Type.titulo3, maxLines = 1); T(sub, Type.leyenda, Palette.texto2, maxLines = 1)
                                    }
                                }
                                // La última fila (Cajita) queda en media columna, como la cuadrícula de iOS.
                                if (row.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                }
                Field("Nombre") { TextBox(name, when (kind) { ProductKind.CREDITO -> "Crédito Oro"; ProductKind.DEBITO -> "Débito"; ProductKind.BOLSILLO -> "Arriendo, Mercado"; ProductKind.CAJITA -> "Emergencias, Viaje"; ProductKind.EFECTIVO -> "Billetera, Casa, Alcancía"; else -> "Ahorros" }) { name = it } }
                when (kind) {
                    ProductKind.CREDITO -> {
                        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                            Box(Modifier.weight(1f)) { Field("Últimos 4") { TextBox(last4, "0000", numeric = true, color = if (last4Valid) Palette.texto1 else Palette.peligro) { last4 = it.filter(Char::isDigit).take(4) } } }
                            MoneyField("Cupo", limit, modifier = Modifier.weight(1f)) { limit = it }
                        }
                        MoneyField("Deuda de hoy", balance) { balance = it }
                    }
                    ProductKind.DEBITO -> Field("Últimos 4") { TextBox(last4, "0000", numeric = true, color = if (last4Valid) Palette.texto1 else Palette.peligro) { last4 = it.filter(Char::isDigit).take(4) } }
                    ProductKind.BOLSILLO, ProductKind.CAJITA -> Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                        MoneyField("Saldo de hoy", balance, modifier = Modifier.weight(1f)) { balance = it }
                        Box(Modifier.weight(0.6f)) { Field("Tasa E.A. (%)") { TextBox(rate, "0", numeric = true) { rate = it.filter { c -> c.isDigit() || c == ',' || c == '.' } } } }
                    }
                    else -> MoneyField("Saldo de hoy", balance) { balance = it }
                }
                Card(padding = Spacing.s2) {
                    if (kind == ProductKind.CREDITO) {
                        FormRow("Día de corte", cutDay?.let { "Día $it" } ?: "Sin definir", onClick = { pickDay = "corte" })
                        FormDivider()
                        FormRow("Día de pago", dueDay?.let { "Día $it" } ?: "Sin definir", onClick = { pickDay = "pago" })
                        FormDivider()
                    }
                    if (kind == ProductKind.DEBITO && accounts.isNotEmpty()) {
                        var open by remember { mutableStateOf(false) }
                        Box {
                            FormRow("Cuenta que paga", accounts.firstOrNull { it.id == parentId }?.name ?: "Ninguna", onClick = { open = true })
                            DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
                                DropdownMenuItem({ T("Ninguna", Type.cuerpo) }, { parentId = null; open = false })
                                accounts.forEach { a -> DropdownMenuItem({ T(a.name, Type.cuerpo) }, { parentId = a.id; open = false }) }
                            }
                        }
                        FormDivider()
                    }
                    if (isCard && ledger.rewards.isNotEmpty()) {
                        var open by remember { mutableStateOf(false) }
                        Box {
                            FormRow("Acumula en", ledger.rewards.firstOrNull { it.id == rewardId }?.name ?: "Ningún programa", onClick = { open = true })
                            DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
                                DropdownMenuItem({ T("Ningún programa", Type.cuerpo) }, { rewardId = null; open = false })
                                ledger.rewards.forEach { r -> DropdownMenuItem({ T(r.name, Type.cuerpo) }, { rewardId = r.id; open = false }) }
                            }
                        }
                        if (rewardId != null) {
                            FormDivider()
                            Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                                T("Puntos por cada ${Money.units(1000, Currency.current).formatted()}", Type.cuerpo, modifier = Modifier.weight(1f))
                                Box(Modifier.width(72.dp)) { TextBox(points, "1", numeric = true) { points = it.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(6) } }
                            }
                        }
                        FormDivider()
                    }
                    FormToggle("Ocultar saldo en Inicio", hidden) { hidden = it }
                }
                if (isCard) T("Solo guardamos los últimos 4 dígitos para reconocer la tarjeta. Nunca el número completo.", Type.leyenda, Palette.texto2)
                if (isCard && rewardId != null) T("Cada gasto con esta tarjeta suma sus puntos solo; si lo borras, se restan.", Type.leyenda, Palette.texto2)
                if (editing != null && kind == ProductKind.CREDITO) SecondaryButton("Pagar tarjeta") { onPay() }
                if (editing != null) SecondaryButton("Borrar ${kindName.lowercase()}", danger = true) { confirmDelete = true }
            }
        }
        pickDay?.let { which ->
            DayGridSheet(if (which == "corte") "¿Qué día es el corte?" else "¿Qué día se paga la tarjeta?", if (which == "corte") cutDay else dueDay, { pickDay = null }) { d ->
                if (which == "corte") cutDay = d else dueDay = d; pickDay = null
            }
        }
    }
    if (confirmDelete && editing != null) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { T("¿Borrar ${editing.name}?", Type.titulo3) },
            text = { T("Los movimientos pagados con esto se quedan, sin producto.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ store.deleteProduct(editing.id); confirmDelete = false; onDone() }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ confirmDelete = false }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}

@Composable
private fun Field(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        T(title, Type.leyenda, Palette.texto2)
        Box(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(horizontal = Spacing.s4),
            contentAlignment = Alignment.CenterStart) { content() }
    }
}

@Composable
private fun TextBox(value: String, hint: String, numeric: Boolean = false, color: Color = Palette.texto1, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth()) {
        if (value.isEmpty()) T(hint, Type.cuerpo, Palette.texto2)
        BasicTextField(value, onChange, Modifier.appTextField().fillMaxWidth(), textStyle = Type.cuerpo.copy(color = color), cursorBrush = SolidColor(Palette.brasa), singleLine = true,
            keyboardOptions = if (numeric) KeyboardOptions(keyboardType = KeyboardType.Number) else KeyboardOptions.Default)
    }
}
