package com.olarte.mprogress.ui.onboarding

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
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
import com.olarte.mprogress.data.BankDraft
import com.olarte.mprogress.data.FixedDraft
import com.olarte.mprogress.data.OnboardingDraft
import com.olarte.mprogress.data.ProductDraft
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.components.AmountDisplay
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.Keypad
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing

private enum class Step { BIENVENIDA, INGRESO, BANCOS, FIJOS, FECHAS }

private val bankSuggestions = listOf("Bancolombia", "Nequi", "Davivienda", "Daviplata", "Banco de Bogotá", "BBVA", "Nu", "Lulo Bank", "Falabella", "Scotiabank Colpatria")
private val fixedSuggestions = listOf("Arriendo", "Servicios", "Internet", "Celular", "Música", "Nube", "Gimnasio", "Streaming", "Transporte", "Suscripción IA")

/** Onboarding como en iOS: ingreso, bancos y tarjetas antes que los fijos, y al final la fecha y con qué se paga cada uno. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OnboardingScreen(store: Store) {
    var step by remember { mutableStateOf(Step.BIENVENIDA) }
    var draft by remember { mutableStateOf(OnboardingDraft()) }
    var income by remember { mutableStateOf(AmountInput()) }
    var editingFixed by remember { mutableStateOf<String?>(null) }
    var fixedAmount by remember { mutableStateOf(AmountInput()) }
    var customName by remember { mutableStateOf("") }

    Column(Modifier.fillMaxSize().background(Palette.fondo).statusBarsPadding().navigationBarsPadding().padding(horizontal = Spacing.margen)) {
        val progress = (step.ordinal + 1f) / Step.entries.size
        Box(Modifier.padding(vertical = Spacing.s4).fillMaxWidth().height(6.dp).clip(CircleShape).background(Palette.superficie3)) {
            Box(Modifier.fillMaxWidth(progress).height(6.dp).clip(CircleShape).background(Palette.brasa))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            when (step) {
                Step.BIENVENIDA -> {
                    Spacer(Modifier.height(60.dp))
                    T("Hola, soy MProgress", Type.titulo1)
                    T("Te digo cuánto te queda este mes y te aviso antes de cada pago. En 2 minutos queda listo.", Type.cuerpo, Palette.texto2)
                    T("Nunca te pedimos claves ni números completos de tarjetas: solo los últimos 4, si quieres.", Type.cuerpo2, Palette.texto2)
                }
                Step.INGRESO -> {
                    T("¿Cuánto te llega al mes?", Type.titulo1)
                    T("Tu sueldo o lo que recibes fijo. Puedes cambiarlo después.", Type.cuerpo, Palette.texto2)
                    AmountDisplay("$", income.display, true)
                    Keypad(false, { income = income.press(it) }, { income = income.deleteLast() })
                    SectionLabel("¿Qué día te llega?")
                    DayPicker(draft.incomeDay) { draft = draft.copy(incomeDay = it ?: 1) }
                }
                Step.BANCOS -> {
                    T("¿Dónde tienes tu plata?", Type.titulo1)
                    T("Elige tus bancos. Así luego eliges con qué pagas cada cosa.", Type.cuerpo, Palette.texto2)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        bankSuggestions.forEach { b ->
                            val on = draft.banks.any { it.name == b }
                            Chip(b, on) {
                                draft = if (on) draft.copy(banks = draft.banks.filter { it.name != b })
                                else draft.copy(banks = draft.banks + BankDraft(b, listOf(ProductDraft(ProductKind.CUENTA, "Cuenta de ahorros"))))
                            }
                        }
                    }
                    draft.banks.forEach { bank ->
                        Card {
                            T(bank.name, Type.titulo3)
                            Spacer(Modifier.height(Spacing.s2))
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                                listOf(ProductKind.CUENTA to "Cuenta de ahorros", ProductKind.DEBITO to "Débito", ProductKind.CREDITO to "Crédito", ProductKind.BOLSILLO to "Bolsillo").forEach { (kind, name) ->
                                    val on = bank.products.any { it.kind == kind }
                                    Chip(name, on) {
                                        val products = if (on) bank.products.filter { it.kind != kind } else bank.products + ProductDraft(kind, name)
                                        draft = draft.copy(banks = draft.banks.map { if (it.name == bank.name) it.copy(products = products) else it })
                                    }
                                }
                            }
                            bank.products.filter { it.kind == ProductKind.CREDITO || it.kind == ProductKind.DEBITO }.forEach { p ->
                                Spacer(Modifier.height(Spacing.s2))
                                Last4Field("${p.name}: últimos 4 (opcional)", p.last4.orEmpty()) { v ->
                                    draft = draft.copy(banks = draft.banks.map { b ->
                                        if (b.name != bank.name) b else b.copy(products = b.products.map { if (it == p) it.copy(last4 = v.ifBlank { null }) else it })
                                    })
                                }
                            }
                        }
                    }
                }
                Step.FIJOS -> {
                    T("¿Qué pagas cada mes?", Type.titulo1)
                    T("Toca uno y escribe cuánto. Las fechas van en el siguiente paso.", Type.cuerpo, Palette.texto2)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        (fixedSuggestions + draft.fixed.map { it.name }.filter { it !in fixedSuggestions }).forEach { name ->
                            val item = draft.fixed.firstOrNull { it.name == name }
                            Chip(item?.let { "$name · ${Money(it.amountMinor).formatted()}" } ?: name, item != null) {
                                editingFixed = name
                                fixedAmount = item?.let { AmountInput.fromMinor(it.amountMinor, com.olarte.mprogress.domain.Currency.COP) } ?: AmountInput()
                            }
                        }
                    }
                    if (editingFixed != null) {
                        Card {
                            T(editingFixed!!, Type.titulo3)
                            AmountDisplay("$", fixedAmount.display, true)
                            Spacer(Modifier.height(Spacing.s2))
                            Keypad(false, { fixedAmount = fixedAmount.press(it) }, { fixedAmount = fixedAmount.deleteLast() })
                            Spacer(Modifier.height(Spacing.s3))
                            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                                SecondaryButton("Quitar", Modifier.weight(1f)) {
                                    draft = draft.copy(fixed = draft.fixed.filter { it.name != editingFixed }); editingFixed = null
                                }
                                PrimaryButton("Listo", Modifier.weight(1f), enabled = fixedAmount.money.minor > 0) {
                                    val name = editingFixed!!
                                    draft = draft.copy(fixed = draft.fixed.filter { it.name != name } + FixedDraft(name, fixedAmount.money.minor))
                                    editingFixed = null
                                }
                            }
                        }
                    }
                    SectionLabel("Agregar otro")
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        Box(Modifier.weight(1f).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(Spacing.s4)) {
                            if (customName.isEmpty()) T("Nombre, por ejemplo Colegio", Type.cuerpo, Palette.texto2)
                            BasicTextField(customName, { customName = it }, Modifier.fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1),
                                cursorBrush = SolidColor(Palette.brasa), singleLine = true)
                        }
                        Chip("+ Agregar", false) {
                            if (customName.isNotBlank()) { editingFixed = customName.trim(); fixedAmount = AmountInput(); customName = "" }
                        }
                    }
                }
                Step.FECHAS -> {
                    T("¿Cuándo y con qué pagas?", Type.titulo1)
                    T("Si no sabes alguno, déjalo para más tarde.", Type.cuerpo, Palette.texto2)
                    val products = draft.allProducts
                    if (draft.incomeProductIndexCandidates(products)) {
                        Card {
                            T("Sueldo · día ${draft.incomeDay}", Type.titulo3)
                            T("¿A dónde te llega?", Type.cuerpo2, Palette.texto2)
                            ProductPicker(products, draft.incomeProductIndex) { draft = draft.copy(incomeProductIndex = it) }
                        }
                    }
                    draft.fixed.forEachIndexed { i, f ->
                        Card {
                            Row { T(f.name, Type.titulo3, modifier = Modifier.weight(1f)); T(Money(f.amountMinor).formatted(), Type.titulo3) }
                            Spacer(Modifier.height(Spacing.s2))
                            DayPicker(f.day, allowLater = true) { d -> draft = draft.copy(fixed = draft.fixed.mapIndexed { j, x -> if (j == i) x.copy(day = d) else x }) }
                            if (products.isNotEmpty()) {
                                Spacer(Modifier.height(Spacing.s2))
                                ProductPicker(products, f.productIndex) { p -> draft = draft.copy(fixed = draft.fixed.mapIndexed { j, x -> if (j == i) x.copy(productIndex = p) else x }) }
                            }
                        }
                    }
                    if (draft.fixed.isEmpty()) T("No agregaste pagos fijos. Puedes hacerlo luego desde Inicio.", Type.cuerpo2, Palette.texto2)
                }
            }
        }
        Spacer(Modifier.height(Spacing.s3))
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            if (step == Step.FECHAS) SecondaryButton("Todo más tarde", Modifier.weight(1f)) {
                draft = draft.copy(fixed = draft.fixed.map { it.copy(day = null) }); finish(store, draft, income)
            }
            PrimaryButton(when (step) { Step.BIENVENIDA -> "Empezar"; Step.FECHAS -> "Listo"; else -> "Siguiente" }, Modifier.weight(1f)) {
                if (step == Step.FECHAS) finish(store, draft, income) else step = Step.entries[step.ordinal + 1]
            }
        }
        if (step != Step.BIENVENIDA) {
            T("Atrás", Type.etiqueta, Palette.texto2, Modifier.align(Alignment.CenterHorizontally).clip(CircleShape)
                .clickable { step = Step.entries[step.ordinal - 1] }.padding(Spacing.s3))
        } else Spacer(Modifier.height(Spacing.s4))
    }
}

private fun OnboardingDraft.incomeProductIndexCandidates(products: List<Pair<String, ProductDraft>>) = products.isNotEmpty()

private fun finish(store: Store, draft: OnboardingDraft, income: AmountInput) =
    store.finishOnboarding(draft.copy(incomeMinor = income.money.minor))

@Composable
private fun DayPicker(selected: Int?, allowLater: Boolean = false, onPick: (Int?) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s1), verticalAlignment = Alignment.CenterVertically) {
        if (allowLater) Chip("Más tarde", selected == null) { onPick(null) }
        (1..31).forEach { d ->
            val on = selected == d
            Box(Modifier.size(40.dp).clip(CircleShape).background(if (on) Palette.brasa else Palette.superficie3).clickable { onPick(d) }, contentAlignment = Alignment.Center) {
                T("$d", Type.etiqueta, if (on) Palette.sobreBrasa else Palette.texto1)
            }
        }
    }
}

@Composable
private fun ProductPicker(products: List<Pair<String, ProductDraft>>, selected: Int?, onPick: (Int?) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        products.forEachIndexed { i, (bank, p) ->
            Chip(listOfNotNull(bank, p.name.takeIf { p.kind != ProductKind.CUENTA }, p.last4?.let { "·· $it" }).joinToString(" "), selected == i) {
                onPick(if (selected == i) null else i)
            }
        }
    }
}

@Composable
private fun Last4Field(hint: String, value: String, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(Spacing.s3)) {
        if (value.isEmpty()) T(hint, Type.cuerpo2, Palette.texto2)
        BasicTextField(value, { onChange(it.filter(Char::isDigit).take(4)) }, Modifier.fillMaxWidth(),
            textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword))
    }
}
