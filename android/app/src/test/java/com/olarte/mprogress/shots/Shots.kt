package com.olarte.mprogress.shots

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import com.olarte.mprogress.ui.home.AddEntryContent
import com.olarte.mprogress.ui.home.AddRequest
import com.olarte.mprogress.ui.home.MoreContent
import com.olarte.mprogress.ui.theme.Radius
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.olarte.mprogress.MainActivity
import com.olarte.mprogress.data.BankDraft
import com.olarte.mprogress.data.FixedDraft
import com.olarte.mprogress.data.OnboardingDraft
import com.olarte.mprogress.data.ProductDraft
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.onboarding.OnboardingScreen
import com.olarte.mprogress.ui.onboarding.OnboardingState
import com.olarte.mprogress.ui.onboarding.OnboardingStep
import com.olarte.mprogress.ui.onboarding.PlannedProduct
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LightColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import android.os.Looper
import java.time.LocalDate

/** Capturas de pantalla para comparar con iOS. Se generan en build/shots. No es una prueba de lógica. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class Shots {
    private fun shot(name: String, dark: Boolean = true, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides if (dark) DarkColors else LightColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    private fun demoState(step: OnboardingStep) = OnboardingState().apply {
        income = AmountInput(text = "4000000")
        addBank("Bancolombia")
        val bank = banks.first()
        addProduct(PlannedProduct(ProductKind.CREDITO, "Crédito Oro", "4417"), bank.id)
        this.step = step
    }

    @Test fun onboarding() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        shot("01a_bienvenida") { OnboardingScreen(store) }
        shot("01b_ingreso") { OnboardingScreen(store, OnboardingState().apply { step = OnboardingStep.INGRESO; income = AmountInput(text = "4000000") }) }
        shot("01c_bancos") { OnboardingScreen(store, demoState(OnboardingStep.BANCOS)) }
        shot("01d_fijos") { OnboardingScreen(store, demoState(OnboardingStep.FIJOS)) }
        shot("01e_fechas") {
            OnboardingScreen(store, demoState(OnboardingStep.FECHAS).apply {
                val credit = plannedProducts.first { it.kind == ProductKind.CREDITO }.id
                incomeProductId = plannedProducts.first().id
                selectedFixed.forEach { setProduct(credit, it.id) }
                setDay(12, selectedFixed.first().id)
            })
        }
        shot("01f_intereses") { OnboardingScreen(store, demoState(OnboardingStep.INTERESES)) }
        shot("01g_funciones") { OnboardingScreen(store, demoState(OnboardingStep.FUNCIONES)) }
        shot("01h_bienvenida_claro", dark = false) { OnboardingScreen(store) }
    }

    private fun seed(store: Store) {
        if (store.onboarded.value) return
        store.finishOnboarding(OnboardingDraft(incomeMinor = 4_000_000_00, incomeDay = 1,
            banks = listOf(BankDraft("Bancolombia", listOf(ProductDraft(ProductKind.CUENTA, "Cuenta de ahorros"), ProductDraft(ProductKind.CREDITO, "Crédito Oro", "4417")))),
            fixed = listOf(FixedDraft("Gimnasio", 119_900_00, LocalDate.now().plusDays(2).dayOfMonth), FixedDraft("Música", 8_000_00, null))))
        store.add(EntryKind.GASTO, "Éxito", 84_300_00, Cycle.Puntual, LocalDate.now(), null)
    }

    /** Hoja inferior como la de la app: esquinas de 36 sobre la pantalla oscurecida. */
    @Composable
    private fun SheetFrame(top: Int, content: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f))) {
            Box(Modifier.fillMaxSize().padding(top = top.dp).clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)).background(Palette.superficie2)) { content() }
        }
    }

    @Test fun hojas() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        shot("03a_agregar") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Puntual)) {} } }
        shot("03b_agregar_fijo") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Mensual)) {} } }
        shot("03c_mas") { SheetFrame(200) { MoreContent(store) {} } }
    }

    @Test fun ajustes() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        shot("04a_ajustes") { com.olarte.mprogress.ui.settings.SettingsScreen(store) }
        shot("04b_apariencia") { com.olarte.mprogress.ui.settings.AppearanceScreen(store) {} }
        shot("04c_icono") { com.olarte.mprogress.ui.settings.AppIconScreen {} }
        shot("04d_ajustes_claro", dark = false) { com.olarte.mprogress.ui.settings.SettingsScreen(store) }
    }

    @Test fun pantallas() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        shot("05a_dinero_vacio") { com.olarte.mprogress.ui.money.MoneyScreen(store) }
        shot("05h_historial_vacio") { com.olarte.mprogress.ui.history.HistoryScreen(store) {} }
        seed(store)
        val today = LocalDate.now()
        store.add(EntryKind.GASTO, "Mercado", 120_000_00, Cycle.Puntual, today.minusMonths(1), null)
        store.add(EntryKind.INGRESO, "Sueldo", 4_000_000_00, Cycle.Puntual, today.minusMonths(1).withDayOfMonth(1), null)
        store.add(EntryKind.GASTO, "Cine", 32_000_00, Cycle.Puntual, today.minusDays(1), null)
        val bank = store.ledger.value.institutions.first().id
        store.addProduct(bank, ProductKind.BOLSILLO, "Emergencias", null, 1_500_000_00, null)
        store.addInstitution("Nu", 0xA68CFF)
        shot("05b_dinero") { com.olarte.mprogress.ui.money.MoneyScreen(store) }
        shot("05c_banco") { com.olarte.mprogress.ui.money.MoneyScreen(store, bank) }
        shot("05d_resumen") { com.olarte.mprogress.ui.summary.SummaryScreen(store) }
        shot("05e_calendario") { com.olarte.mprogress.ui.calendar.CalendarScreen(store) }
        shot("05f_historial") { com.olarte.mprogress.ui.history.HistoryScreen(store) {} }
        shot("05g_fijos") { com.olarte.mprogress.ui.fixed.FixedScreen(store, {}, {}) }
    }

    @Test fun capturas() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val store = Store.get(ctx)
        store.finishOnboarding(OnboardingDraft(incomeMinor = 4_000_000_00, incomeDay = 1,
            banks = listOf(BankDraft("Bancolombia", listOf(ProductDraft(ProductKind.CUENTA, "Cuenta de ahorros"), ProductDraft(ProductKind.CREDITO, "Crédito Oro", "4417")))),
            fixed = listOf(FixedDraft("Gimnasio", 119_900_00, LocalDate.now().plusDays(2).dayOfMonth), FixedDraft("Música", 8_000_00, null))))
        store.add(EntryKind.GASTO, "Éxito", 84_300_00, Cycle.Puntual, LocalDate.now(), null)
        ActivityScenario.launch(MainActivity::class.java).use { s ->
            s.onActivity { it.window.decorView.captureRoboImage("build/shots/02_inicio.png") }
        }
    }
}
