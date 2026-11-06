package com.olarte.mprogress.ui.money

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Product
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.MoneyCalculator
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.components.AmountDisplay
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.Keypad
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing

private sealed interface Sheet {
    data object NewBank : Sheet
    data class NewProduct(val institutionId: String) : Sheet
    data class Balance(val product: Product) : Sheet
}

/** Dinero (pantalla 9): lo que tienes, lo que debes y cada banco con sus cuentas y tarjetas. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoneyScreen(store: Store) {
    val ledger by store.ledger.collectAsState()
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    val records = ledger.products.map { it.record }
    val (have, owe, net) = MoneyCalculator.netWorth(records, ledger.entries)

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        T("Dinero", Type.titulo1)
        Card {
            T("Patrimonio", Type.cuerpo2, Palette.texto2)
            T(Money(net).formatted(), Type.cifra, if (net < 0) Palette.peligro else Palette.texto1)
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                Column { T("Tienes", Type.leyenda, Palette.texto2); T(Money(have).formatted(), Type.titulo3, Palette.exito) }
                Column { T("Debes", Type.leyenda, Palette.texto2); T(Money(owe).formatted(), Type.titulo3, Palette.peligro) }
            }
        }
        if (ledger.institutions.isEmpty()) T("Agrega tus bancos para ver tus saldos y elegir con qué pagas.", Type.cuerpo2, Palette.texto2)
        ledger.institutions.forEach { inst ->
            val products = ledger.products.filter { it.institutionId == inst.id }
            Card {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(inst.name, Type.titulo2, modifier = Modifier.weight(1f))
                    T("+ Agregar", Type.etiqueta, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { sheet = Sheet.NewProduct(inst.id) }.padding(6.dp))
                }
                products.forEach { p ->
                    val balance = MoneyCalculator.currentBalance(p.record, records, ledger.entries)
                    val glyph = when (p.kind) { ProductKind.CREDITO, ProductKind.DEBITO -> "▭"; ProductKind.BOLSILLO -> "◎"; ProductKind.EFECTIVO -> "$"; else -> "▤" }
                    val subtitle = listOfNotNull(p.kind.title, p.last4?.let { "·· $it" }, p.dueDay?.let { "paga el $it" }).joinToString(" · ")
                    ListRow(glyph, p.name, subtitle, onClick = if (p.kind == ProductKind.DEBITO) null else ({ sheet = Sheet.Balance(p) })) {
                        if (p.kind != ProductKind.DEBITO) T(Money(balance).formatted(), Type.titulo3, if (p.kind.isDebt) Palette.peligro else Palette.texto1)
                    }
                }
                if (products.isEmpty()) T("Sin cuentas todavía.", Type.cuerpo2, Palette.texto2)
            }
        }
        SecondaryButton("Agregar banco o billetera") { sheet = Sheet.NewBank }
        T("Nunca guardamos claves ni números completos: solo los últimos 4 de tus tarjetas.", Type.leyenda, Palette.texto2)
    }

    sheet?.let { current ->
        ModalBottomSheet({ sheet = null }, containerColor = Palette.superficie2, shape = RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)) {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen).navigationBarsPadding().padding(bottom = Spacing.s4),
                verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                when (current) {
                    Sheet.NewBank -> NewBank(store) { sheet = it?.let { id -> Sheet.NewProduct(id) } }
                    is Sheet.NewProduct -> NewProduct(store, current.institutionId) { sheet = null }
                    is Sheet.Balance -> BalanceEditor(store, current.product) { sheet = null }
                }
            }
        }
    }
}

private val banks = listOf("Bancolombia", "Nequi", "Davivienda", "Daviplata", "Banco de Bogotá", "BBVA", "Nu", "Lulo Bank", "Falabella", "Efectivo")

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun NewBank(store: Store, onDone: (String?) -> Unit) {
    var name by remember { mutableStateOf("") }
    T("Nuevo banco", Type.titulo2)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        banks.forEach { b -> Chip(b, name == b) { name = b } }
    }
    TextBox("O escribe el nombre", name) { name = it }
    PrimaryButton("Siguiente", enabled = name.isNotBlank()) { onDone(store.addInstitution(name.trim())) }
}

@Composable
private fun NewProduct(store: Store, institutionId: String, onDone: () -> Unit) {
    var kind by remember { mutableStateOf(ProductKind.CUENTA) }
    var name by remember { mutableStateOf("") }
    var last4 by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf(AmountInput()) }
    var dueDay by remember { mutableStateOf<Int?>(null) }
    T("Cuenta o tarjeta", Type.titulo2)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        ProductKind.entries.forEach { k -> Chip(k.title, kind == k) { kind = k } }
    }
    TextBox("Nombre (opcional), por ejemplo Oro", name) { name = it }
    if (kind == ProductKind.CREDITO || kind == ProductKind.DEBITO) {
        TextBox("Últimos 4 (opcional)", last4, numeric = true) { last4 = it.filter(Char::isDigit).take(4) }
    }
    if (kind != ProductKind.DEBITO) {
        SectionLabel(if (kind == ProductKind.CREDITO) "Lo que debes hoy" else "Saldo de hoy")
        AmountDisplay("$", amount.display, true)
        Keypad(false, { amount = amount.press(it) }, { amount = amount.deleteLast() })
    }
    if (kind == ProductKind.CREDITO) {
        SectionLabel("Día de pago (opcional)")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
            (1..31).forEach { d -> Chip("$d", dueDay == d) { dueDay = if (dueDay == d) null else d } }
        }
    }
    PrimaryButton("Guardar") {
        store.addProduct(institutionId, kind, name.ifBlank { kind.title }, last4, amount.money.minor, dueDay)
        onDone()
    }
}

@Composable
private fun BalanceEditor(store: Store, product: Product, onDone: () -> Unit) {
    var amount by remember { mutableStateOf(AmountInput()) }
    T(product.name, Type.titulo2)
    T(if (product.kind.isDebt) "¿Cuánto debes hoy según el banco?" else "¿Cuánto tienes hoy según el banco?", Type.cuerpo, Palette.texto2)
    AmountDisplay("$", amount.display, true)
    Keypad(false, { amount = amount.press(it) }, { amount = amount.deleteLast() })
    PrimaryButton("Ajustar saldo") { store.setBalance(product.id, amount.money.minor); onDone() }
    Spacer(Modifier.height(Spacing.s2))
    T("Eliminar", Type.etiqueta, Palette.peligro, Modifier.fillMaxWidth().clip(CircleShape).clickable { store.deleteProduct(product.id); onDone() }.padding(Spacing.s3), align = androidx.compose.ui.text.style.TextAlign.Center)
}

@Composable
private fun TextBox(hint: String, value: String, numeric: Boolean = false, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(Spacing.s4)) {
        if (value.isEmpty()) T(hint, Type.cuerpo, Palette.texto2)
        BasicTextField(value, onChange, Modifier.fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa),
            singleLine = true, keyboardOptions = if (numeric) KeyboardOptions(keyboardType = KeyboardType.NumberPassword) else KeyboardOptions.Default)
    }
}
