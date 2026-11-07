package com.olarte.mprogress.shots

import android.os.Looper
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
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.QuincenaDays
import com.olarte.mprogress.ui.home.AddEntryContent
import com.olarte.mprogress.ui.home.AddRequest
import com.olarte.mprogress.ui.home.AddSection
import com.olarte.mprogress.ui.home.NewFixedContent
import com.olarte.mprogress.ui.home.RecurringEditSheet
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

/** Capturas de Agregar (solo una vez, con el calendario de semana) y del pago fijo con "¿Cada cuánto?". Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class RepeatShots {
    private fun shot(name: String, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f))) {
                    Box(Modifier.fillMaxSize().padding(top = 40.dp).clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)).background(Palette.superficie2)) { content() }
                }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    @Test fun capturas() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val dir = File(context.filesDir, "capturas-16").apply { mkdirs() }
        val store = Store(File(dir, "mprogress.json"), context.getSharedPreferences("capturas-16", 0))
        shot("19a_agregar_gasto_vacio") { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Puntual)) {} }
        shot("19b_agregar_gasto") { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Puntual, "Mercado", 84_300_00)) {} }
        shot("19c_agregar_ingreso_mes") { AddEntryContent(store, AddRequest(EntryKind.INGRESO, Cycle.Puntual, "Venta", 250_000_00), startsWithMonth = true) {} }
        shot("19d_fijo_otra") { NewFixedContent(store, AddRequest(EntryKind.GASTO, Cycle.CadaMeses(3), "Seguro del carro", 300_000_00), AddSection.CADA_CUANTO) {} }
        shot("19e_fijo_quincenal") { NewFixedContent(store, AddRequest(EntryKind.INGRESO, Cycle.Quincenal(QuincenaDays.STANDARD), "Sueldo", 2_000_000_00), AddSection.DIAS) {} }
        shot("19f_fijo_mensual") { NewFixedContent(store, AddRequest(EntryKind.GASTO, Cycle.Mensual, "Arriendo", 1_800_000_00)) {} }
        shot("19g_fijo_dia_del_mes") { NewFixedContent(store, AddRequest(EntryKind.GASTO, Cycle.Mensual, "Arriendo", 1_800_000_00), AddSection.DIA_DEL_MES) {} }
        store.add(EntryKind.INGRESO, "Sueldo", 2_000_000_00, Cycle.Quincenal(QuincenaDays.STANDARD), com.olarte.mprogress.domain.QuincenaMath.onOrAfter(LocalDate.now(), QuincenaDays.STANDARD), null)
        val sueldo = store.ledger.value.recurring.single()
        assertTrue(sueldo.cycle == Cycle.Quincenal(QuincenaDays.STANDARD))
        shot("19h_editar_fijo_quincenal") { RecurringEditSheet(store, sueldo.id) {} }
        assertTrue(File("build/shots/19e_fijo_quincenal.png").exists())
    }
}
