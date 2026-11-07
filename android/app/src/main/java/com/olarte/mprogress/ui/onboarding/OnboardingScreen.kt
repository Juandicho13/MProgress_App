package com.olarte.mprogress.ui.onboarding

import com.olarte.mprogress.ui.components.appTextField

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.Cloud
import androidx.compose.material.icons.outlined.CloudOff
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.NotificationsActive
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.RemoveCircleOutline
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.outlined.Contactless
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.RadioButtonChecked
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.olarte.mprogress.data.BankDraft
import com.olarte.mprogress.data.FixedDraft
import com.olarte.mprogress.data.OnboardingDraft
import com.olarte.mprogress.data.ProductDraft
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.components.AmountDisplay
import com.olarte.mprogress.ui.components.Avatar
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.InstitutionStyle
import com.olarte.mprogress.ui.components.Keypad
import com.olarte.mprogress.ui.components.OverlaySheet
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Tile
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.util.UUID

/** Pasos del onboarding, en el mismo orden que iOS. */
enum class OnboardingStep { BIENVENIDA, INGRESO, BANCOS, FIJOS, FECHAS, INTERESES, FUNCIONES }

data class PlannedProduct(val kind: ProductKind, val name: String, val last4: String? = null, val id: String = UUID.randomUUID().toString()) {
    val label get() = last4?.let { "$name ·· $it" } ?: name
}

data class PlannedBank(val name: String, val hex: Long, val products: List<PlannedProduct>, val id: String = UUID.randomUUID().toString())

data class PlannedFixed(
    val id: String, val name: String, val icon: ImageVector?, val amountMinor: Long, val selected: Boolean, val rotate: Float = 0f,
    val day: Int? = null, val productId: String? = null, val later: Boolean = false,
)

enum class Interest(val title: String, val icon: ImageVector, val slideTitle: String, val slideMessage: String, val sampleTitle: String, val sampleDetail: String) {
    PAGO("Registrar al pagar con el celular", Icons.Outlined.Contactless, "Pagas y queda anotado",
        "Con el SMS o la notificación del banco, el comercio, el monto y la tarjeta se registran solos.", "Gasto registrado", "$ 81.900 en el mercado · Crédito ·· 4417"),
    CUENTAS("Separar trabajo, casa o viaje", Icons.Outlined.Layers, "Cada gasto en su cuenta",
        "Personal, trabajo o un viaje, cada uno con sus totales y su límite.", "Cuenta Trabajo", "3 gastos reembolsables este mes"),
    PAREJA("Llevar las cuentas en pareja", Icons.Outlined.People, "Las cuentas del hogar, sin enredos",
        "Cada uno en su celular, quién pagó qué y cuánto se deben.", "Mariana registró un gasto", "Mercado · $ 84.300 · Hogar"),
    LIMITE("Ponerme un límite al mes", Icons.Outlined.Speed, "Un límite que te avisa",
        "Pon un tope al mes o por categoría y te avisamos antes de pasarte.", "Vas en el 80 % de Salidas", "Te quedan $ 50.000 hasta fin de mes"),
    AHORRO("Ahorrar para algo", Icons.Outlined.AccountBalance, "Metas que se llenan solas",
        "Aparta para un viaje o un fondo de emergencia, solo o en pareja.", "Viaje juntos al 48 %", "$ 2.400.000 de $ 5.000.000"),
    AVISOS("Avisarme antes de cada cargo", Icons.Outlined.NotificationsActive, "Avisos para quien toca",
        "A los dos, solo a ti o solo a tu pareja, de 1 a 14 días antes.", "La renta vence en 3 días", "Para Juan · $ 2.275.000"),
    WIDGET("Verlo en la pantalla de inicio", Icons.Outlined.GridView, "Tu mes en la pantalla de inicio",
        "Lo que te queda y el próximo cobro sin abrir la app.", "Te quedan $ 1.901.100", "Próximo: Gimnasio mañana"),
    RECIBOS("Escanear recibos", Icons.Outlined.DocumentScanner, "Escanea y listo",
        "Toma una foto del recibo y el gasto queda listo para revisar.", "Recibo leído", "Farmacia · $ 32.400 · listo para revisar");

    companion object { val defaultSelection = setOf(PAGO, CUENTAS, PAREJA, AVISOS, WIDGET) }
}

private fun units(u: Long) = Money(AmountInput(text = u.toString()).money.minor)

private fun defaultFixed() = listOf(
    PlannedFixed("renta", "Renta", Icons.Outlined.Home, units(1_500_000).minor, false),
    PlannedFixed("streaming", "Streaming", Icons.Outlined.SmartDisplay, units(45_500).minor, false),
    PlannedFixed("musica", "Música", Icons.Rounded.MusicNote, units(16_900).minor, true),
    PlannedFixed("nube", "Nube", Icons.Outlined.Cloud, units(10_500).minor, false),
    PlannedFixed("gimnasio", "Gimnasio", Icons.Rounded.FitnessCenter, units(119_900).minor, true, rotate = -45f),
    PlannedFixed("ia", "Suscripción IA", Icons.Rounded.AutoAwesome, units(85_000).minor, true),
)

/** Estado del onboarding, igual que OnboardingModel de iOS. */
class OnboardingState {
    var step by mutableStateOf(OnboardingStep.BIENVENIDA)
    var income by mutableStateOf(AmountInput())
    var payday by mutableStateOf(1)
    var incomeProductId by mutableStateOf<String?>(null)
    var banks by mutableStateOf(listOf<PlannedBank>())
    var fixed by mutableStateOf(defaultFixed())
    var interests by mutableStateOf(Interest.defaultSelection)
    var slideIndex by mutableStateOf(0)

    val slides get() = Interest.entries.filter { it in interests }
    val selectedFixed get() = fixed.filter { it.selected && it.amountMinor > 0 }
    val plannedProducts get() = banks.flatMap { it.products }
    val isLastSlide get() = step == OnboardingStep.FUNCIONES && slideIndex >= slides.size - 1

    val progress: Float get() {
        val total = OnboardingStep.entries.size.toFloat()
        if (step == OnboardingStep.FUNCIONES && slides.isNotEmpty()) return (step.ordinal + (slideIndex + 1f) / slides.size) / total
        return (step.ordinal + 1) / total
    }

    private fun skipDates() = selectedFixed.isEmpty() && income.money.minor == 0L

    fun next() {
        if (step == OnboardingStep.FUNCIONES) { if (slideIndex + 1 < slides.size) slideIndex++; return }
        var following = OnboardingStep.entries.getOrNull(step.ordinal + 1) ?: return
        if (following == OnboardingStep.FECHAS && skipDates()) following = OnboardingStep.INTERESES
        if (following == OnboardingStep.FUNCIONES) slideIndex = 0
        step = following
    }

    fun back() {
        if (step == OnboardingStep.FUNCIONES && slideIndex > 0) { slideIndex--; return }
        var previous = OnboardingStep.entries.getOrNull(step.ordinal - 1) ?: return
        if (previous == OnboardingStep.FECHAS && skipDates()) previous = OnboardingStep.FIJOS
        step = previous
    }

    fun addBank(name: String) {
        val hex = InstitutionStyle.hexFor(name)
        if (name == "Efectivo") {
            if (banks.none { it.name == "Efectivo" }) banks = banks + PlannedBank(name, hex, listOf(PlannedProduct(ProductKind.EFECTIVO, "Efectivo")))
            return
        }
        banks = banks + PlannedBank(name, hex, listOf(PlannedProduct(ProductKind.CUENTA, "Cuenta de ahorros")))
    }

    fun addProduct(p: PlannedProduct, bankId: String) {
        val clean = p.copy(last4 = p.last4?.filter(Char::isDigit)?.takeLast(4)?.takeIf { it.length == 4 })
        banks = banks.map { if (it.id == bankId) it.copy(products = it.products + clean) else it }
    }

    fun removeProduct(id: String) {
        banks = banks.map { b -> b.copy(products = b.products.filter { it.id != id }) }
        clear(setOf(id))
    }

    fun removeBank(id: String) {
        val ids = banks.firstOrNull { it.id == id }?.products?.map { it.id }.orEmpty().toSet()
        banks = banks.filter { it.id != id }
        clear(ids)
    }

    private fun clear(ids: Set<String>) {
        if (incomeProductId in ids) incomeProductId = null
        fixed = fixed.map { if (it.productId in ids) it.copy(productId = null) else it }
    }

    private fun edit(id: String, f: (PlannedFixed) -> PlannedFixed) { fixed = fixed.map { if (it.id == id) f(it) else it } }
    fun toggleFixed(id: String) = edit(id) { it.copy(selected = !it.selected) }
    fun setAmount(minor: Long, id: String) = edit(id) { it.copy(amountMinor = minor, selected = true) }
    fun addCustomFixed(name: String, minor: Long) {
        val clean = name.trim()
        if (clean.isEmpty() || minor <= 0) return
        fixed = fixed + PlannedFixed("propio-${UUID.randomUUID()}", clean, null, minor, true)
    }
    fun setDay(day: Int?, id: String) = edit(id) { it.copy(day = day, later = if (day != null) false else it.later) }
    fun setProduct(p: String?, id: String) = edit(id) { it.copy(productId = p) }
    fun setLater(later: Boolean, id: String) = edit(id) { it.copy(later = later, day = if (later) null else it.day) }
    fun allLater() { fixed = fixed.map { if (it.selected) it.copy(later = true, day = null) else it }; next() }
    fun toggleInterest(i: Interest) { interests = if (i in interests) interests - i else interests + i }

    /** Pasa lo planeado al borrador del Store. Los productos se nombran por su posición en allProducts. */
    fun toDraft(): OnboardingDraft {
        val banksDraft = banks.map { b ->
            BankDraft(b.name, b.products.sortedBy { it.kind != ProductKind.CUENTA }.map { ProductDraft(it.kind, it.name, it.last4) })
        }
        val order = banks.flatMap { b -> b.products.sortedBy { it.kind != ProductKind.CUENTA }.map { it.id } }
        fun index(id: String?) = id?.let { order.indexOf(it).takeIf { i -> i >= 0 } }
        return OnboardingDraft(
            incomeMinor = income.money.minor, incomeDay = payday, incomeProductIndex = index(incomeProductId), banks = banksDraft,
            fixed = selectedFixed.map { FixedDraft(it.name, it.amountMinor, if (it.later) null else it.day, index(it.productId)) },
            interests = interests.map { it.name.lowercase() }.sorted(),
        )
    }
}

/** Bienvenida y onboarding (pantallas 14 a 18), igual que OnboardingView de iOS. */
@Composable
fun OnboardingScreen(store: Store, state: OnboardingState = remember { OnboardingState() }) {
    Column(Modifier.fillMaxSize().background(Palette.fondo).statusBarsPadding().navigationBarsPadding()) {
        ProgressBar(state.progress, Modifier.padding(horizontal = Spacing.margen).padding(top = Spacing.s2))
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when (state.step) {
                OnboardingStep.BIENVENIDA -> WelcomeStep(state)
                OnboardingStep.INGRESO -> IncomeStep(state)
                OnboardingStep.BANCOS -> BanksStep(state)
                OnboardingStep.FIJOS -> FixedStep(state)
                OnboardingStep.FECHAS -> DatesStep(state)
                OnboardingStep.INTERESES -> InterestsStep(state)
                OnboardingStep.FUNCIONES -> FeatureStep(state) { val d = state.toDraft(); store.finishOnboarding(d); if (d.fixed.isNotEmpty()) com.olarte.mprogress.ui.Permissions.askAfterFirstFixed() }
            }
        }
    }
}

// MARK: Piezas comunes

@Composable
private fun ProgressBar(value: Float, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(Palette.superficie3)) {
        Box(Modifier.fillMaxWidth(value.coerceIn(0.02f, 1f)).height(6.dp).clip(CircleShape).background(Palette.brasa))
    }
}

@Composable
private fun StepHeader(title: String, message: String, modifier: Modifier = Modifier, oneLine: Boolean = false) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        val lines = if (oneLine) 1 else Int.MAX_VALUE
        androidx.compose.material3.Text(title, style = Type.titulo1, color = Palette.texto1, maxLines = lines, overflow = TextOverflow.Ellipsis)
        androidx.compose.material3.Text(message, style = Type.cuerpo, color = Palette.texto2, maxLines = lines, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun StepFooter(back: String, next: String, nextEnabled: Boolean = true, onBack: () -> Unit, onNext: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3), verticalAlignment = Alignment.CenterVertically) {
        SecondaryButton(back, Modifier.width(120.dp), onClick = onBack)
        PrimaryButton(next, Modifier.weight(1f), enabled = nextEnabled, onClick = onNext)
    }
}

/** Estructura de los pasos con lista: contenido que se desplaza y pie fijo. */
@Composable
private fun ScrollStep(footer: @Composable ColumnScope.() -> Unit, bottom: androidx.compose.ui.unit.Dp = Spacing.s4, overlay: @Composable BoxScope.() -> Unit = {}, content: @Composable ColumnScope.() -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(horizontal = Spacing.margen).padding(bottom = bottom), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = Spacing.s6), verticalArrangement = Arrangement.spacedBy(Spacing.s5), content = content)
            footer()
        }
        overlay()
    }
}

@Composable
private fun CheckCircle(on: Boolean) {
    Box(
        Modifier.size(28.dp).clip(CircleShape).background(if (on) Palette.brasa else Color.Transparent)
            .border(2.dp, if (on) Palette.brasa else lineaControl(), CircleShape),
        contentAlignment = Alignment.Center,
    ) { if (on) Icon(Icons.Rounded.Check, null, Modifier.size(16.dp), tint = Palette.sobreBrasa) }
}

@Composable
private fun lineaControl() = if (Palette.fondo.red < 0.5f) Color(0xFF6C727B) else Color(0xFF7F8792)

@Composable
private fun Divider() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))

// MARK: Paso 0 · Bienvenida

@Composable
private fun WelcomeStep(state: OnboardingState) {
    Column(Modifier.fillMaxSize().padding(horizontal = Spacing.margen).padding(bottom = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s6)) {
        PhonePreview(Modifier.padding(top = Spacing.s5).fillMaxWidth().weight(1f, fill = false))
        StepHeader("Sabe cuánto te queda, solo o en pareja", "Anota lo que entra y lo que sale, y MProgress te dice cada día cuánto te queda.")
        Column {
            TrustRow(Icons.Outlined.AccountBalance, "Sin conectar tu banco", "Tus datos se quedan en tu teléfono")
            Divider()
            TrustRow(Icons.Outlined.CloudOff, "Funciona sin internet", "Se sincroniza cuando vuelves")
        }
        Spacer(Modifier.weight(0.001f))
        PrimaryButton("Empezar") { state.next() }
    }
}

@Composable
private fun TrustRow(icon: ImageVector, title: String, message: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = Spacing.s3), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s4)) {
        IconTile(icon, Palette.superficie1, size = 48.dp, circle = true)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, Type.titulo3)
            T(message, Type.cuerpo2, Palette.texto2)
        }
    }
}

/** Teléfono de muestra con Inicio dentro (pantalla 14). */
@Composable
private fun PhonePreview(modifier: Modifier) {
    val sys = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    Box(modifier.height(360.dp).clip(RoundedCornerShape(Radius.hoja)).background(Palette.superficie1)) {
        Box(
            Modifier.padding(horizontal = 38.dp).padding(top = 34.dp).fillMaxWidth().height(380.dp)
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .drawWithContent {
                    drawContent()
                    drawRect(Brush.verticalGradient(0f to Color.Black, 0.5f to Color.Black, 1f to Color.Transparent), blendMode = BlendMode.DstIn)
                },
        ) {
            Column(
                Modifier.fillMaxSize().clip(RoundedCornerShape(44.dp)).background(Palette.fondo)
                    .border(7.dp, Palette.superficie3, RoundedCornerShape(44.dp)).padding(horizontal = Spacing.s4).padding(top = 44.dp),
                verticalArrangement = Arrangement.spacedBy(Spacing.s3),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Avatar("Tú", 22.dp)
                    Spacer(Modifier.width(Spacing.s2))
                    T("Personal", sys)
                    Spacer(Modifier.weight(1f))
                    T("Inicio", sys)
                    Spacer(Modifier.weight(1f))
                    Spacer(Modifier.width(40.dp))
                }
                T("Te quedan en el mes", TextStyle(fontSize = 11.sp), Palette.texto2)
                T(Money(AmountInput(text = "1901100").money.minor).formatted(), Type.cifraGrande)
                T("− $ 81.900 con el celular, anotado solo", TextStyle(fontSize = 11.sp), Palette.texto2)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    repeat(4) { i -> Box(Modifier.weight(1f).height(48.dp).clip(RoundedCornerShape(14.dp)).background(if (i == 0) Palette.brasa else Palette.superficie1)) }
                }
                T("Próximos cargos", TextStyle(fontSize = 14.sp, fontWeight = FontWeight.SemiBold))
                MiniRow("GY", "Gimnasio", 119_900, Palette.superficie3)
                MiniRow("RN", "Renta · Hogar", 1_137_500, Palette.hielo)
            }
            Box(Modifier.align(Alignment.TopCenter).padding(top = 12.dp).width(92.dp).height(26.dp).clip(CircleShape).background(Color.Black))
        }
    }
}

@Composable
private fun MiniRow(initials: String, name: String, amount: Long, tint: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        Box(Modifier.size(30.dp).clip(CircleShape).background(tint), contentAlignment = Alignment.Center) {
            T(initials, TextStyle(fontSize = 9.6.sp, fontWeight = FontWeight.Bold))
        }
        T(name, TextStyle(fontSize = 12.sp), modifier = Modifier.weight(1f))
        T(units(amount).formatted(), TextStyle(fontSize = 12.sp, fontWeight = FontWeight.SemiBold))
    }
}

// MARK: Paso 1 · Ingreso

@Composable
private fun DayChip(title: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.widthIn(min = Size.toqueMinimo).heightIn(min = 40.dp).clip(CircleShape).background(if (selected) Palette.brasa else Palette.superficie3)
            .clickable(onClick = onClick).padding(horizontal = Spacing.s1),
        contentAlignment = Alignment.Center,
    ) { T(title, Type.etiqueta, if (selected) Palette.sobreBrasa else Palette.texto1) }
}

@Composable
private fun IncomeStep(state: OnboardingState) {
    val paydays = listOf(1, 15, 30)
    var otherDay by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(horizontal = Spacing.margen).padding(bottom = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
            StepHeader("¿Cuánto entra al mes?", "Tu sueldo o lo que ganes en promedio. Con eso te digo cuánto te queda.", Modifier.padding(top = Spacing.s6))
            AmountDisplay("$", state.income.display, true, empty = state.income.text.isEmpty())
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                T("Me pagan el día", Type.cuerpo2, Palette.texto2)
                paydays.forEach { d -> DayChip("$d", state.payday == d) { state.payday = d } }
                DayChip(if (state.payday in paydays) "Otro" else "${state.payday}", state.payday !in paydays) { otherDay = true }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("Prefiero no decirlo", Type.cuerpo2, Palette.texto2, Modifier.heightIn(min = Size.toqueMinimo).clickable {
                    state.income = AmountInput(state.income.currency); state.next()
                }.padding(vertical = 14.dp))
                Spacer(Modifier.weight(1f))
                PrimaryButton("Siguiente", Modifier.width(160.dp), enabled = state.income.money.minor > 0) { state.next() }
            }
            Spacer(Modifier.weight(1f))
            Keypad(state.income.allowsDecimals, { state.income = state.income.press(it) }, { state.income = state.income.deleteLast() })
        }
        if (otherDay) DayPickerSheet(state.payday, "¿Qué día te pagan?", { otherDay = false }) { state.payday = it; otherDay = false }
    }
}

@Composable
private fun DayPickerSheet(selection: Int?, title: String, onDismiss: () -> Unit, onPick: (Int) -> Unit) {
    OverlaySheet(onDismiss) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s6), verticalArrangement = Arrangement.spacedBy(Spacing.s4), horizontalAlignment = Alignment.CenterHorizontally) {
            T(title, Type.titulo2, modifier = Modifier.padding(top = Spacing.s6))
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                (1..31).chunked(7).forEach { week ->
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        week.forEach { d ->
                            Box(Modifier.weight(1f).height(44.dp), contentAlignment = Alignment.Center) {
                                Box(Modifier.size(44.dp).clip(CircleShape).background(if (selection == d) Palette.brasa else Color.Transparent).clickable { onPick(d) },
                                    contentAlignment = Alignment.Center) { T("$d", Type.cuerpo, if (selection == d) Palette.sobreBrasa else Palette.texto1) }
                            }
                        }
                        repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
            T("Si el mes no tiene ese día, se usa el último.", Type.cuerpo2, Palette.texto2)
        }
    }
}

// MARK: Paso 2 · Bancos y tarjetas

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BanksStep(state: OnboardingState) {
    var adding by remember { mutableStateOf<Pair<String, ProductKind>?>(null) }
    ScrollStep(
        footer = { StepFooter("Atrás", if (state.banks.isEmpty()) "Lo hago después" else "Siguiente", onBack = state::back, onNext = state::next) },
        overlay = { adding?.let { (bankId, kind) -> PlannedCardSheet(kind, { adding = null }) { state.addProduct(it, bankId); adding = null } } },
    ) {
        StepHeader("¿Dónde tienes tu plata?", "Agrega tus bancos y tarjetas para decir con qué pagas cada cosa. De las tarjetas solo los 4 últimos dígitos.")
        FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            InstitutionStyle.suggestions.map { it.first }.filter { n -> state.banks.none { it.name == n } }.forEach { n -> Chip(n) { state.addBank(n) } }
        }
        state.banks.forEach { bank -> BankCard(state, bank) { kind -> adding = bank.id to kind } }
        if (state.banks.isEmpty()) T("Toca tu banco arriba. Si no está, lo agregas después en Dinero.", Type.cuerpo2, Palette.texto2)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BankCard(state: OnboardingState, bank: PlannedBank, onAdd: (ProductKind) -> Unit) {
    Card(padding = Spacing.s3) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                InstitutionStyle.Tile(bank.name, bank.hex)
                T(bank.name, Type.titulo3, modifier = Modifier.weight(1f))
                Box(Modifier.size(Size.toqueMinimo).clip(CircleShape).clickable { state.removeBank(bank.id) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Close, "Quitar ${bank.name}", Modifier.size(18.dp), tint = Palette.texto2)
                }
            }
            bank.products.forEach { p ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { Icon(InstitutionStyle.symbol(p.kind), null, Modifier.size(20.dp), tint = Palette.texto2) }
                    T(p.label, Type.cuerpo, modifier = Modifier.weight(1f))
                    Box(Modifier.width(Size.toqueMinimo).height(36.dp).clip(CircleShape).clickable { state.removeProduct(p.id) }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.RemoveCircleOutline, "Quitar ${p.label}", Modifier.size(22.dp), tint = Palette.texto2)
                    }
                }
            }
            if (bank.name != "Efectivo") {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    Chip("+ Crédito") { onAdd(ProductKind.CREDITO) }
                    Chip("+ Débito") { onAdd(ProductKind.DEBITO) }
                    Chip("+ Bolsillo") { onAdd(ProductKind.BOLSILLO) }
                    Chip("+ Cajita") { onAdd(ProductKind.CAJITA) }
                }
            }
        }
    }
}

/** Nombre y 4 últimos dígitos de una tarjeta, o nombre de un bolsillo o una cajita. Nunca el número completo. */
@Composable
private fun PlannedCardSheet(kind: ProductKind, onDismiss: () -> Unit, onAdd: (PlannedProduct) -> Unit) {
    val isCard = kind == ProductKind.CREDITO || kind == ProductKind.DEBITO
    var name by remember { mutableStateOf(when (kind) { ProductKind.CREDITO -> "Crédito"; ProductKind.DEBITO -> "Débito"; else -> kind.title }) }
    var last4 by remember { mutableStateOf("") }
    val canAdd = name.isNotBlank() && (last4.isEmpty() || last4.length == 4)
    OverlaySheet(onDismiss) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s8), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
            Row(Modifier.fillMaxWidth().padding(top = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                T("Cancelar", Type.cuerpo, Palette.brasaTinta, Modifier.clip(CircleShape).clickable(onClick = onDismiss).padding(Spacing.s2))
                T(if (isCard) "Nueva tarjeta" else if (kind == ProductKind.BOLSILLO) "Nuevo bolsillo" else "Nueva cajita", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center)
                T("Agregar", Type.cuerpo.copy(fontWeight = FontWeight.SemiBold), Palette.brasaTinta.copy(alpha = if (canAdd) 1f else 0.4f),
                    Modifier.clip(CircleShape).clickable(enabled = canAdd) { onAdd(PlannedProduct(kind, name.trim(), last4.ifEmpty { null })) }.padding(Spacing.s2))
            }
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie1)) {
                FormField(name, "Nombre") { name = it }
                if (isCard) {
                    Box(Modifier.padding(start = Spacing.s4)) { Divider() }
                    FormField(last4, "Últimos 4 dígitos", KeyboardType.Number) { last4 = it.filter(Char::isDigit).take(4) }
                }
            }
        }
    }
}

@Composable
private fun FormField(value: String, hint: String, keyboard: KeyboardType = KeyboardType.Text, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(horizontal = Spacing.s4), contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) T(hint, Type.cuerpo, Palette.texto2)
        BasicTextField(value, onChange, Modifier.appTextField().fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa),
            singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = keyboard))
    }
}

// MARK: Paso 3 · Gastos fijos

@Composable
private fun FixedTile(item: PlannedFixed) {
    if (item.icon != null) IconTile(item.icon, rotate = item.rotate) else Tile(item.name)
}

@Composable
private fun FixedStep(state: OnboardingState) {
    var editing by remember { mutableStateOf<PlannedFixed?>(null) }
    var addingCustom by remember { mutableStateOf(false) }
    ScrollStep(
        footer = { StepFooter("Atrás", "Siguiente", onBack = state::back, onNext = state::next) },
        overlay = {
            editing?.let { item -> FixedAmountSheet(item.name, item.amountMinor, { editing = null }) { _, m -> state.setAmount(m, item.id); editing = null } }
            if (addingCustom) FixedAmountSheet(null, 0, { addingCustom = false }) { n, m -> state.addCustomFixed(n.orEmpty(), m); addingCustom = false }
        },
    ) {
        StepHeader("¿Qué pagas cada mes?", "Marca los tuyos y ajusta el monto. En el siguiente paso eliges el día y con qué los pagas.")
        Card(padding = Spacing.s2) {
            state.fixed.forEach { item ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 64.dp).clickable { state.toggleFixed(item.id) }.padding(horizontal = Spacing.s2),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
                ) {
                    FixedTile(item)
                    T(item.name, Type.titulo3, modifier = Modifier.weight(1f), maxLines = 1)
                    T(Money(item.amountMinor).formatted(), Type.cifraPequena, if (item.selected) Palette.texto1 else Palette.texto2,
                        Modifier.heightIn(min = Size.toqueMinimo).clickable { editing = item }.padding(vertical = 14.dp))
                    CheckCircle(item.selected)
                }
                Divider()
            }
            Row(
                Modifier.fillMaxWidth().heightIn(min = 64.dp).clickable { addingCustom = true }.padding(horizontal = Spacing.s2),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
            ) {
                IconTile(Icons.Rounded.Add, Palette.brasaVelo, Palette.brasaTinta)
                T("Agregar otro", Type.titulo3, Palette.brasaTinta)
            }
        }
    }
}

/** Monto de un fijo. Sin título pide también el nombre (Agregar otro). */
@Composable
private fun FixedAmountSheet(title: String?, minor: Long, onDismiss: () -> Unit, onSave: (String?, Long) -> Unit) {
    var input by remember { mutableStateOf(if (minor > 0) AmountInput(text = (Money(minor).minor / Money(minor).currency.minorPerUnit).toString()) else AmountInput()) }
    var name by remember { mutableStateOf("") }
    var nameFocused by remember { mutableStateOf(title == null) }
    val canSave = input.money.minor > 0 && (title != null || name.isNotBlank())
    OverlaySheet(onDismiss, Modifier.fillMaxSize().padding(top = 48.dp)) {
        Column(Modifier.weight(1f).padding(horizontal = Spacing.margen).padding(bottom = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s5),
            horizontalAlignment = Alignment.CenterHorizontally) {
            if (title != null) T(title, Type.titulo2, modifier = Modifier.padding(top = Spacing.s6))
            else Box(Modifier.fillMaxWidth().padding(top = Spacing.s6).clickable { nameFocused = true }, contentAlignment = Alignment.Center) {
                if (name.isEmpty()) T("Nombre: internet, colegio, celular…", Type.titulo2, Palette.texto2, align = TextAlign.Center)
                BasicTextField(name, { name = it; nameFocused = true }, Modifier.appTextField().fillMaxWidth(), singleLine = true,
                    textStyle = Type.titulo2.copy(color = Palette.texto1, textAlign = TextAlign.Center), cursorBrush = SolidColor(Palette.brasa))
            }
            AmountDisplay("$", input.display, !nameFocused || title != null, empty = input.text.isEmpty()) { nameFocused = false }
            Spacer(Modifier.weight(1f))
            PrimaryButton(if (title == null) "Agregar" else "Listo", enabled = canSave) { onSave(if (title == null) name else null, input.money.minor) }
            if (!nameFocused || title != null) Keypad(input.allowsDecimals, { input = input.press(it) }, { input = input.deleteLast() })
        }
    }
}

// MARK: Paso 4 · Fechas y con qué se paga

@Composable
private fun DatesStep(state: OnboardingState) {
    var pickingDay by remember { mutableStateOf<PlannedFixed?>(null) }
    ScrollStep(
        bottom = Spacing.s2,
        footer = {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3), verticalAlignment = Alignment.CenterVertically) {
                SecondaryButton("Todo más tarde", Modifier.weight(1f)) { state.allLater() }
                PrimaryButton("Siguiente", Modifier.weight(1f)) { state.next() }
            }
            T("Atrás", Type.cuerpo2, Palette.texto2, Modifier.align(Alignment.CenterHorizontally).heightIn(min = Size.toqueMinimo).clip(CircleShape)
                .clickable { state.back() }.padding(horizontal = Spacing.s4, vertical = 14.dp))
        },
        overlay = {
            pickingDay?.let { item ->
                DayPickerSheet(item.day, "¿Qué día se paga ${item.name}?", { pickingDay = null }) { state.setDay(it, item.id); pickingDay = null }
            }
        },
    ) {
        StepHeader("¿Cuándo y con qué pagas cada uno?", "Elige el día del mes y de dónde sale. Si no lo sabes ahora, toca Más tarde y lo pones en Pagos fijos.")
        if (state.income.money.minor > 0) {
            Card(padding = Spacing.s3) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    IconTile(Icons.Outlined.Payments, Palette.hieloVelo, Palette.hielo)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T("Sueldo · día ${state.payday}", Type.titulo3, maxLines = 1)
                        T("¿A dónde te llega?", Type.cuerpo2, Palette.texto2, maxLines = 1)
                    }
                    ProductMenu(state, state.incomeProductId, Modifier.widthIn(max = 136.dp)) { state.incomeProductId = it }
                }
            }
        }
        state.selectedFixed.forEach { item ->
            Card(padding = Spacing.s3) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    Row(Modifier.alpha(if (item.later) 0.55f else 1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                        FixedTile(item)
                        T(item.name, Type.titulo3, modifier = Modifier.weight(1f), maxLines = 1)
                        T(Money(item.amountMinor).formatted(), Type.cifraPequena)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        Box(Modifier.alpha(if (item.later) 0.4f else 1f)) {
                            Chip(item.day?.let { "Día $it" } ?: "Elegir día", item.day != null) { if (!item.later) pickingDay = item }
                        }
                        ProductMenu(state, item.productId, Modifier.weight(1f, fill = false).alpha(if (item.later) 0.4f else 1f), enabled = !item.later) { state.setProduct(it, item.id) }
                        Spacer(Modifier.weight(0.001f))
                        Chip("Más tarde", item.later) { state.setLater(!item.later, item.id) }
                    }
                }
            }
        }
    }
}

/** Menú de productos planeados: tarjetas, cuentas, cajitas y efectivo. */
@Composable
private fun ProductMenu(state: OnboardingState, selection: String?, modifier: Modifier = Modifier, enabled: Boolean = true, onPick: (String?) -> Unit) {
    val products = state.plannedProducts
    val current = products.firstOrNull { it.id == selection }
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Row(
            Modifier.heightIn(min = 36.dp).clip(CircleShape).background(if (current == null) Palette.superficie3 else Palette.brasa)
                .clickable(enabled = enabled && products.isNotEmpty()) { open = true }.padding(horizontal = Spacing.s3),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1),
        ) {
            val c = if (current == null) Palette.texto1 else Palette.sobreBrasa
            Icon(current?.let { InstitutionStyle.symbol(it.kind) } ?: Icons.Rounded.CreditCard, null, Modifier.size(15.dp), tint = c)
            Text1(current?.label ?: if (products.isEmpty()) "Sin bancos" else "Con qué", c)
        }
        DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
            DropdownMenuItem({ T("Sin elegir", Type.cuerpo) }, { onPick(null); open = false })
            state.banks.forEach { bank ->
                T(bank.name.uppercase(), Type.leyenda, Palette.texto2, Modifier.padding(horizontal = Spacing.s3, vertical = Spacing.s1))
                bank.products.forEach { p ->
                    DropdownMenuItem({ T(p.label, Type.cuerpo) }, { onPick(p.id); open = false },
                        leadingIcon = { Icon(InstitutionStyle.symbol(p.kind), null, Modifier.size(18.dp), tint = Palette.texto2) })
                }
            }
        }
    }
}

@Composable
private fun Text1(text: String, color: Color) =
    androidx.compose.material3.Text(text, style = Type.etiqueta, color = color, maxLines = 1, overflow = TextOverflow.Ellipsis)

// MARK: Paso 5 · Intereses

@Composable
private fun InterestsStep(state: OnboardingState) {
    ScrollStep(footer = {
        StepFooter("Ahora no", if (state.interests.isEmpty()) "Siguiente" else "Muéstramelo (${state.interests.size})",
            onBack = { state.interests = emptySet(); state.next() }, onNext = state::next)
    }) {
        StepHeader("¿Qué más quieres que haga por ti?", "Elige lo que te interese y te lo muestro.")
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            Interest.entries.chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    row.forEach { i -> InterestCard(i, i in state.interests, Modifier.weight(1f)) { state.toggleInterest(i) } }
                }
            }
        }
    }
}

@Composable
private fun InterestCard(interest: Interest, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.heightIn(min = 120.dp).clip(RoundedCornerShape(Radius.boton)).background(if (selected) Palette.brasaVelo else Palette.superficie1)
            .border(2.dp, if (selected) Palette.brasa else Color.Transparent, RoundedCornerShape(Radius.boton)).clickable(onClick = onClick).padding(Spacing.s4),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(interest.icon, null, Modifier.size(26.dp), tint = Palette.texto1)
            Spacer(Modifier.weight(1f))
            CheckCircle(selected)
        }
        T(interest.title, Type.titulo3)
    }
}

// MARK: Paso 6 · Funciones elegidas

@Composable
private fun FeatureStep(state: OnboardingState, onFinish: () -> Unit) {
    val interest = state.slides.getOrNull(state.slideIndex)
    Column(Modifier.fillMaxSize().padding(horizontal = Spacing.margen).padding(bottom = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
        if (interest != null) {
            FeatureArt(interest, Modifier.padding(top = Spacing.s5).fillMaxWidth().height(340.dp))
            T(interest.slideTitle, Type.titulo1)
            T(interest.slideMessage, Type.cuerpo, Palette.texto2)
        } else {
            Spacer(Modifier.weight(1f))
            StepHeader("Todo listo", "Puedes activar más funciones cuando quieras desde Ajustes.")
        }
        Spacer(Modifier.weight(1f))
        val last = state.isLastSlide || state.slides.isEmpty()
        StepFooter("Atrás", if (last) "Empezar a usar" else "Siguiente", onBack = state::back) { if (last) onFinish() else state.next() }
    }
}

/** Ilustración de cada función: una notificación de ejemplo sobre la tarjeta. */
@Composable
private fun FeatureArt(interest: Interest, modifier: Modifier) {
    Box(modifier.clip(RoundedCornerShape(Radius.hoja)).background(Brush.linearGradient(listOf(Palette.brasaVelo, Palette.superficie1)))) {
        Icon(interest.icon, null, Modifier.align(Alignment.Center).size(140.dp), tint = Palette.brasa.copy(alpha = 0.25f))
        Row(
            Modifier.padding(horizontal = Spacing.s5).padding(top = Spacing.s6).fillMaxWidth().clip(RoundedCornerShape(Radius.boton))
                .background(Palette.vidrioTinte.copy(alpha = 0.85f)).border(1.dp, Palette.vidrioBorde, RoundedCornerShape(Radius.boton)).padding(Spacing.s4),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
        ) {
            IconTile(Icons.Rounded.RadioButtonChecked, Palette.brasa, Palette.sobreBrasa, size = 40.dp)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(interest.sampleTitle, Type.titulo3)
                T(interest.sampleDetail, Type.cuerpo2, Palette.texto2)
            }
        }
    }
}

