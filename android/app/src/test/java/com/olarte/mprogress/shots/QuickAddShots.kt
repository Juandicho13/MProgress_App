package com.olarte.mprogress.shots

import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.Categories
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.ui.home.CategoryFormSheet
import com.olarte.mprogress.ui.home.CategoryPickerSheet
import com.olarte.mprogress.ui.home.MoreContent
import com.olarte.mprogress.ui.home.QuickAddSheet
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
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

/** Capturas del registro rápido, Más acciones, la campana de Inicio y Nueva categoría. Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class QuickAddShots {
    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun newStore(): Store {
        val dir = File(context.filesDir, "capturas-17-${System.nanoTime()}").apply { mkdirs() }
        return Store(File(dir, "mprogress.json"), context.getSharedPreferences("capturas-17-${System.nanoTime()}", 0))
    }

    /** Dibuja, opcionalmente toca un punto (en dp) y guarda la captura. */
    private fun shot(name: String, tapDp: Pair<Float, Float>? = null, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        tapDp?.let { (x, y) ->
            val d = activity.resources.displayMetrics.density
            val view = activity.window.decorView
            val t = SystemClock.uptimeMillis()
            view.dispatchTouchEvent(MotionEvent.obtain(t, t, MotionEvent.ACTION_DOWN, x * d, y * d, 0))
            view.dispatchTouchEvent(MotionEvent.obtain(t, t + 50, MotionEvent.ACTION_UP, x * d, y * d, 0))
            shadowOf(Looper.getMainLooper()).idle()
        }
        activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    @Composable
    private fun SheetFrame(top: Int, content: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f))) {
            Box(Modifier.fillMaxSize().padding(top = top.dp).clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)).background(Palette.superficie2)) { content() }
        }
    }

    @Test fun capturas() {
        val store = newStore()
        val today = LocalDate.now()
        val salidas = Categories.byName("Salidas")!!.id
        listOf("Almuerzo" to salidas, "Taxi" to null, "Almuerzo" to null, "Mercado" to Categories.byName("Mercado")!!.id, "Café" to null,
            "Taxi" to null, "Almuerzo" to null, "Arriendo" to null, "Gasto rápido" to null).forEachIndexed { i, (n, c) ->
            store.add(EntryKind.GASTO, n, (12_000 + i * 1_000) * 100L, Cycle.Puntual, today.minusDays(i.toLong()), null, categoryId = c)
        }
        shot("17a_registro_rapido") { QuickAddSheet(store) {} }

        // Más acciones: sin Gasto fijo, Sueldo o fijo, Pago anual ni Historial.
        shot("17b_mas_acciones") { SheetFrame(200) { MoreContent(store) {} } }

        // Selector de categoría con "+ Nueva categoría" y una propia; y el formulario.
        store.addCategory("Mascotas", "pawprint")
        shot("17c_categorias") { CategoryPickerSheet(store.ledger.value.entries, salidas, {}, store) {} }
        shot("17d_nueva_categoria") { CategoryFormSheet(store, null, {}) {} }
        shot("17e_editar_categoria") { CategoryFormSheet(store, store.ledger.value.categories.single(), {}) {} }

        // Inicio: tocar la campana abre Avisos (como en iOS).
        shot("17f_campana_avisos", tapDp = 349f to 40f) { com.olarte.mprogress.RootScreen(store) }
        assertTrue(File("build/shots/17a_registro_rapido.png").exists())
    }
}
