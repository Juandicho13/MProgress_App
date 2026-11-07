package com.olarte.mprogress.shots

import android.content.Context
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
import com.github.takahirom.roborazzi.captureScreenRoboImage
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.data.cloud.CloudAccount
import com.olarte.mprogress.data.cloud.CloudPhase
import com.olarte.mprogress.data.cloud.CloudUi
import com.olarte.mprogress.data.cloud.MemorySecretStore
import com.olarte.mprogress.data.cloud.RemoteDevice
import com.olarte.mprogress.data.cloud.UploadProgress
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.SyncStatus
import com.olarte.mprogress.ui.home.HomeScreen
import com.olarte.mprogress.ui.home.SyncStatusContent
import com.olarte.mprogress.ui.home.SyncStatusSheet
import com.olarte.mprogress.ui.settings.AccountScreen
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LightColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Instant
import java.time.LocalDate

/** Capturas de F10-04 y F10-05: la pastilla en sus cuatro estados, la hoja de estado y la primera subida. Se generan en build/shots. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class SyncShots {
    private fun shot(name: String, dark: Boolean = true, screen: Boolean = false, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides if (dark) DarkColors else LightColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        // Las hojas de ventana (ModalBottomSheet) solo salen en la captura de toda la pantalla.
        if (screen) captureScreenRoboImage("build/shots/$name.png") else activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    /** Hoja inferior como la de la app: esquinas de 36 sobre la pantalla oscurecida. */
    @Composable
    private fun SheetFrame(content: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f))) {
            Box(Modifier.fillMaxSize().padding(top = 120.dp).clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)).background(Palette.superficie2)) { content() }
        }
    }

    @Test fun capturas() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val dir = File(ctx.filesDir, "capturas-16").apply { mkdirs() }
        val store = Store(File(dir, "mprogress.json"), ctx.getSharedPreferences("capturas-16", 0))
        val today = LocalDate.now()
        val synced = store.add(EntryKind.GASTO, "Éxito", 84_300_00, Cycle.Puntual, today.minusDays(1), null)!!
        val pending1 = store.add(EntryKind.GASTO, "Taxi", 18_000_00, Cycle.Puntual, today, null)!!
        val pending2 = store.add(EntryKind.INGRESO, "Venta", 250_000_00, Cycle.Puntual, today, null)!!
        val cloud = CloudAccount(store, MemorySecretStore())
        CloudAccount.install(cloud)

        val me = "0d000000-0000-4000-8000-00000000000a"
        val now = Instant.now()
        val phone = RemoteDevice(me, "Galaxy S24 de Juan", "android", "AAAA", now.minusSeconds(86400 * 3), now)
        val iphone = RemoteDevice("0d000000-0000-4000-8000-00000000000b", "iPhone 18 Pro", "ios", "BBBB", now.minusSeconds(86400 * 20), now)
        val ready = CloudUi(phase = CloudPhase.Ready, email = "juan@correo.com", thisDeviceId = me, lastSyncAt = now.minusSeconds(120),
            devices = listOf(iphone, phone), initialUploadDone = true)
        val offline = ready.copy(online = false, status = SyncStatus.SinConexion(3), pendingCounts = mapOf("entries" to 2, "recurring" to 1),
            pendingEntryIds = setOf(pending1.id, pending2.id))
        val syncing = ready.copy(running = true, status = SyncStatus.Sincronizando, pendingCounts = mapOf("entries" to 2), pendingEntryIds = setOf(pending1.id, pending2.id))
        val failed = ready.copy(lastError = "La nube respondió con un error (503).", status = SyncStatus.Error("La nube respondió con un error (503)."),
            pendingCounts = mapOf("entries" to 1), pendingEntryIds = setOf(pending1.id))
        assertEquals("Sin conexión · 3 pendientes", offline.pill?.text)
        assertEquals(null, CloudUi().pill)
        assertEquals(false, ready.showsPendingMark(synced.id))

        fun home(name: String, ui: CloudUi, dark: Boolean = true) {
            cloud.preview(ui)
            shot(name, dark) { HomeScreen(store, {}, {}, {}, {}) }
        }
        home("16a_pastilla_al_dia", ready)
        home("16b_pastilla_sincronizando", syncing)
        home("16c_pastilla_sin_conexion", offline)
        home("16d_pastilla_error", failed, dark = false)
        home("16e_sin_cuenta", CloudUi(thisDeviceId = me))

        shot("16f_estado_sin_conexion") { SheetFrame { SyncStatusContent(offline, now, {}, {}, {}) } }
        shot("16g_estado_error") { SheetFrame { SyncStatusContent(failed, now, {}, {}, {}) } }
        shot("16h_estado_al_dia", dark = false) { SheetFrame { SyncStatusContent(ready, now, {}, {}, {}) } }
        cloud.preview(offline)
        shot("16i_hoja_estado", screen = true) { SyncStatusSheet(cloud) {} }

        cloud.preview(ready.copy(initialUploadDone = false, running = true, upload = UploadProgress(120, 340)))
        shot("16j_cuenta_subiendo") { AccountScreen(cloud) {} }
        cloud.preview(ready)
        shot("16k_cuenta_en_la_nube") { AccountScreen(cloud) {} }
        cloud.preview(offline)
        shot("16l_historial_pendientes") { com.olarte.mprogress.ui.history.HistoryScreen(store) {} }
    }
}
