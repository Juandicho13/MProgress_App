package com.olarte.mprogress.shots

import android.content.Context
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.data.addDebtPayment
import com.olarte.mprogress.data.saveDebt
import com.olarte.mprogress.domain.DebtDirection
import com.olarte.mprogress.domain.DebtMath
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.FormDivider
import com.olarte.mprogress.ui.components.FormToggle
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.money.DebtForm
import com.olarte.mprogress.ui.money.DebtScreen
import com.olarte.mprogress.ui.money.DebtScreens
import com.olarte.mprogress.ui.money.MoneyScreen
import com.olarte.mprogress.ui.money.ProductFormSheet
import com.olarte.mprogress.ui.settings.LockDelayRow
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.LocalDate

/** Capturas de Quién te debe, Bloquear después de y Bolsillo o Cajita (18a a 18g). Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class DebtShots {
    private val context = ApplicationProvider.getApplicationContext<Context>()

    private fun shot(name: String, screen: Boolean = false, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        // Los menús desplegables son ventanas aparte: solo salen en la captura de toda la pantalla.
        if (screen) captureScreenRoboImage("build/shots/$name.png") else activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    @Test fun capturas() {
        val dir = File(context.filesDir, "capturas-18-${System.nanoTime()}").apply { mkdirs() }
        val store = Store(File(dir, "mprogress.json"), context.getSharedPreferences("capturas-18-${System.nanoTime()}", 0))
        val today = LocalDate.now()
        val bank = store.addInstitution("Bancolombia", 0xFDDA24)
        val cuenta = store.addProduct(bank, ProductKind.CUENTA, "Ahorros", null, 2_400_000_00, null)
        val nu = store.addInstitution("Nu", 0xA68CFF)
        store.addProduct(nu, ProductKind.CAJITA, "Viaje", null, 1_500_000_00, null)
        val ana = store.saveDebt(null, "Ana María", DebtDirection.ME_DEBE, 300_000_00, today.minusDays(9), today.plusDays(6), "Arriendo de diciembre", cuenta)
        store.addDebtPayment(ana.id, 100_000_00, today.minusDays(2), cuenta)
        store.saveDebt(null, "Ana María", DebtDirection.ME_DEBE, 150_000_00, today.minusDays(3), null, "Tiquetes", null)
        store.saveDebt(null, "Ana María", DebtDirection.LE_DEBO, 50_000_00, today.minusDays(1), null, "Almuerzo", null)
        store.saveDebt(null, "Carlos", DebtDirection.LE_DEBO, 30_000_00, today.minusDays(5), today.minusDays(1), null, cuenta)
        val pedro = store.saveDebt(null, "Pedro", DebtDirection.ME_DEBE, 20_000_00, today.minusDays(20), null, null, null)
        store.addDebtPayment(pedro.id, 20_000_00, today.minusDays(4), null)
        val l = store.ledger.value
        assertEquals("Te deben $ 350.000 · Debes $ 80.000", DebtMath.summaryText(DebtMath.totals(l.debts, l.debtPayments), com.olarte.mprogress.domain.Currency.COP))

        shot("18a_dinero_quien_te_debe") { MoneyScreen(store) }
        shot("18b_nueva_deuda") { DebtForm(store, store.ledger.value, null, "", {}) }
        val key = DebtMath.personKey("Ana María")
        shot("18c_persona") { DebtScreens(store, listOf(DebtScreen.Person(key)), false, {}, {}) }
        shot("18d_detalle_con_abonos") { DebtScreens(store, listOf(DebtScreen.Person(key), DebtScreen.Detail(ana.id)), false, {}, {}) }
        shot("18e_abono") { DebtScreens(store, listOf(DebtScreen.Detail(ana.id), DebtScreen.Pay(ana.id)), false, {}, {}) }
        shot("18f_bloquear_despues_de", screen = true) {
            Column(Modifier.padding(horizontal = Spacing.margen).padding(top = 80.dp), verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                SectionLabel("General")
                Card(padding = Spacing.s2) {
                    FormToggle("Bloqueo con huella o rostro", true) {}
                    FormDivider()
                    LockDelayRow(store.prefs, startsOpen = true)
                }
            }
        }
        val inst = store.ledger.value.institutions.first { it.id == nu }
        shot("18g_tipo_bolsillo_cajita") { ProductFormSheet(store, store.ledger.value, inst, ProductKind.CAJITA, null) {} }
    }
}
