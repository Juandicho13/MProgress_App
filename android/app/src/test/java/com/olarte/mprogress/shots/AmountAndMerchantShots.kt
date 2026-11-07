package com.olarte.mprogress.shots

import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.Categories
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.LocalDate

/** Capturas de los montos editables (Pagar tarjeta, Marcar pagado) y de Nombres de comercios. Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class AmountAndMerchantShots {
    private fun shot(name: String, screen: Boolean = false, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        // Las hojas de ventana (ModalBottomSheet) solo salen en la captura de toda la pantalla.
        if (screen) captureScreenRoboImage("build/shots/$name.png") else activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    @Test fun capturas() {
        val dir = File(ApplicationProvider.getApplicationContext<android.content.Context>().filesDir, "capturas-15").apply { mkdirs() }
        val store = Store(File(dir, "mprogress.json"), ApplicationProvider.getApplicationContext<android.content.Context>().getSharedPreferences("capturas-15", 0))
        shot("15a_comercios_vacio") { com.olarte.mprogress.ui.settings.MerchantAliasesScreen(store) {} }

        val bank = store.addInstitution("Bancolombia", 0xF5C451)
        val account = store.addProduct(bank, ProductKind.CUENTA, "Ahorros", null, 2_500_000_00, null)
        val card = store.addProduct(bank, ProductKind.CREDITO, "Crédito Oro", "4417", 0, 10)
        store.add(EntryKind.GASTO, "Éxito", 384_300_00, Cycle.Puntual, LocalDate.now(), card)
        shot("15b_pagar_tarjeta") { com.olarte.mprogress.ui.money.TransferSheet(store, account, card) {} }

        store.add(EntryKind.GASTO, "Energía", 120_000_00, Cycle.CadaMeses(2), LocalDate.now().plusDays(3), account)
        val energy = store.ledger.value.recurring.single()
        shot("15c_marcar_pagado", screen = true) { com.olarte.mprogress.ui.home.MarkPaidSheet(store, energy.id) {} }

        val e = store.add(EntryKind.GASTO, "Pepepollo Sas 123", 32_000_00, Cycle.Puntual, LocalDate.now(), null, source = "sms", merchant = "PEPEPOLLO SAS 123")!!
        store.updateEntry(store.ledger.value.entries.first { it.id == e.id }.copy(name = "El Corral", categoryId = Categories.byName("Salidas")!!.id))
        store.add(EntryKind.GASTO, "Éxito", 9_900_00, Cycle.Puntual, LocalDate.now(), null, source = "notificacion", merchant = "EXITO CALLE 80 BOGOTA",
            categoryId = Categories.byName("Mercado")!!.id)
        shot("15d_comercios") { com.olarte.mprogress.ui.settings.MerchantAliasesScreen(store) {} }
        shot("15e_fijos_trimestral") { com.olarte.mprogress.ui.fixed.FixedScreen(store, onBack = {}, onAdd = {}, onEdit = {}) }
        assertTrue(File("build/shots/15d_comercios.png").exists())
    }
}
