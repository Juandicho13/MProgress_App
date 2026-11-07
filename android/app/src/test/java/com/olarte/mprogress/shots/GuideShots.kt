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
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.BudgetRecord
import com.olarte.mprogress.domain.Categories
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.Guide
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

/** Capturas de la barra de filtros del Resumen y de los primeros pasos de Inicio. Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class GuideShots {
    private fun shot(name: String, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    private fun store(name: String): Store {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val dir = File(context.filesDir, name).apply { deleteRecursively(); mkdirs() }
        return Store(File(dir, "mprogress.json"), context.getSharedPreferences(name, 0).also { it.edit().clear().commit() })
    }

    @Test fun capturas() {
        val today = LocalDate.now()
        val s = store("capturas-21")
        // Inicio con el primer paso hecho (ingreso, fijo y gasto) y un límite: 2 de 8.
        s.add(EntryKind.INGRESO, "Sueldo", 4_200_000_00, Cycle.Mensual, today.withDayOfMonth(1), null)
        s.add(EntryKind.GASTO, "Arriendo", 1_350_000_00, Cycle.Mensual, today.plusDays(5), null)
        val mercado = Categories.byName("Mercado")!!.id
        val salidas = Categories.byName("Salidas")!!.id
        val mascotas = s.addCategory("Mascotas", "pawprint")
        s.add(EntryKind.GASTO, "Éxito", 384_300_00, Cycle.Puntual, today, null, categoryId = mercado)
        s.add(EntryKind.GASTO, "Ara", 96_000_00, Cycle.Puntual, today.minusMonths(1), null, categoryId = mercado)
        s.add(EntryKind.GASTO, "El Corral", 152_000_00, Cycle.Puntual, today, null, categoryId = salidas)
        s.add(EntryKind.GASTO, "Veterinaria", 210_000_00, Cycle.Puntual, today.minusMonths(2), null, categoryId = mascotas.id)
        s.add(EntryKind.GASTO, "Uber", 38_000_00, Cycle.Puntual, today, null, categoryId = Categories.byName("Transporte")!!.id)
        s.saveBudget(BudgetRecord(categoryId = mercado, limitMinor = 900_000_00))

        shot("21a_resumen_filtro_mercado") { com.olarte.mprogress.ui.summary.SummaryScreen(s, initialCategories = setOf(mercado)) }
        shot("21b_resumen_todas") { com.olarte.mprogress.ui.summary.SummaryScreen(s) }
        shot("21c_inicio_primeros_pasos") { com.olarte.mprogress.ui.home.HomeScreen(s, {}, {}, {}, {}) }
        s.prefs.edit().putBoolean(Guide.FIRST_STEP_OPEN_KEY, true).commit()
        shot("21d_inicio_primer_paso_abierto") { com.olarte.mprogress.ui.home.HomeScreen(s, {}, {}, {}, {}) }
        s.prefs.edit().putBoolean(Guide.COLLAPSED_KEY, true).commit()
        shot("21e_inicio_primeros_pasos_plegado") { com.olarte.mprogress.ui.home.HomeScreen(s, {}, {}, {}, {}) }

        // Recién instalada: nada hecho y el primer paso dice qué falta.
        val nuevo = store("capturas-21-nuevo")
        shot("21f_inicio_vacio_primeros_pasos") { com.olarte.mprogress.ui.home.HomeScreen(nuevo, {}, {}, {}, {}) }

        // Oculta con la X: no sale en Inicio.
        s.prefs.edit().putBoolean(Guide.DISMISSED_KEY, true).commit()
        shot("21g_inicio_sin_primeros_pasos") { com.olarte.mprogress.ui.home.HomeScreen(s, {}, {}, {}, {}) }
        assertTrue(File("build/shots/21a_resumen_filtro_mercado.png").exists())
        assertTrue(File("build/shots/21e_inicio_primeros_pasos_plegado.png").exists())
    }
}
