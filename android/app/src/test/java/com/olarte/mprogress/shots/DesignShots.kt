package com.olarte.mprogress.shots

import android.content.Context
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AccentPresets
import com.olarte.mprogress.ui.settings.ColorsSection
import com.olarte.mprogress.ui.settings.DesignScreen
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LightColors
import com.olarte.mprogress.ui.theme.LiveColors
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

/** Capturas de Diseño (22a a 22e): la pantalla unida y la sección Colores con varios colores. Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class DesignShots {
    private fun store(): Store {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val dir = File(ctx.filesDir, "capturas-22-${System.nanoTime()}").apply { mkdirs() }
        return Store(File(dir, "mprogress.json"), ctx.getSharedPreferences("capturas-22-${System.nanoTime()}", 0))
    }

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

    @Composable
    private fun Colors(store: Store) {
        Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen, vertical = Spacing.s4)) {
            ColorsSection(store)
        }
    }

    @Test fun capturas() {
        val s = store()
        assertEquals("original", LiveColors.accentId)
        shot("22a_diseno_arriba") { DesignScreen(s) {} }
        shot("22b_colores_original") { Colors(s) }

        s.setAccent("rubi"); s.setIncome("verde")
        assertEquals("rubi", s.prefs.getString(AccentPresets.ACCENT_KEY, null))
        shot("22c_colores_rubi_verde") { Colors(s) }

        s.setAccent("ambar"); s.setIncome("indigo")
        shot("22d_colores_ambar_claro", dark = false) { Colors(s) }

        s.setAccent("violeta"); s.setIncome("original")
        shot("22e_diseno_violeta_claro", dark = false) { DesignScreen(s) {} }

        // Restablecer vuelve a los originales y lo guarda.
        s.resetColors()
        assertEquals("original", LiveColors.accentId)
        assertEquals("original", s.prefs.getString(AccentPresets.INCOME_KEY, null))
        // Un Store nuevo lee lo guardado.
        s.setAccent("menta")
        Store(File(ApplicationProvider.getApplicationContext<Context>().cacheDir, "otra-${System.nanoTime()}.json"), s.prefs)
        assertEquals("menta", LiveColors.accentId)
        s.resetColors()
    }

    @Test fun moneda() {
        val s = store()
        shot("22f_moneda_mas_usadas") { com.olarte.mprogress.ui.settings.CurrencyScreen(s) {} }
        shot("22g_moneda_buscar_yen") { com.olarte.mprogress.ui.settings.CurrencyScreen(s, initialQuery = "yen") {} }
        shot("22h_moneda_buscar_dinar", dark = false) { com.olarte.mprogress.ui.settings.CurrencyScreen(s, initialQuery = "dinar") {} }
    }
}
