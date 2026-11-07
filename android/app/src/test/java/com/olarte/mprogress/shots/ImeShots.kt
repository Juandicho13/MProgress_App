package com.olarte.mprogress.shots

import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import com.github.takahirom.roborazzi.captureRoboImage
import com.olarte.mprogress.ui.components.FormGroup
import com.olarte.mprogress.ui.components.FormSheet
import com.olarte.mprogress.ui.components.FormTextField
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.components.appTextField
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

/** Con el teclado abierto, la hoja sube y el campo con el foco queda a la vista (arreglo de 1.1). */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class ImeShots {
    @Test fun hojaConTeclado() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        WindowCompat.setDecorFitsSystemWindows(activity.window, false)
        var fieldBottom = 0f
        var rootHeight = 0
        var hadFocus = false
        activity.setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo).onGloballyPositioned { rootHeight = it.size.height }) {
                    // Igual que la raíz de MainActivity: todo se acomoda encima del teclado.
                    Box(Modifier.fillMaxSize().imePadding()) {
                        FormSheet("Nueva tarjeta", onCancel = {}, confirm = "Agregar", onConfirm = {}) {
                            FormGroup { FormTextField("Crédito", "Nombre") {} }
                            Spacer(Modifier.height(520.dp))
                            val focus = remember { FocusRequester() }
                            FormGroup {
                                Box(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 8.dp), contentAlignment = Alignment.CenterStart) {
                                    BasicTextField("44", {}, Modifier.appTextField().fillMaxWidth().focusRequester(focus).onFocusChanged { if (it.isFocused) hadFocus = true }
                                        .onGloballyPositioned { fieldBottom = it.boundsInRoot().bottom },
                                        textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true,
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                                }
                            }
                            T("Últimos 4 dígitos", Type.leyenda, Palette.texto2)
                            Spacer(Modifier.height(240.dp))
                            LaunchedEffect(Unit) { focus.requestFocus() }
                        }
                    }
                    // Teclado de mentira para la captura: ocupa el alto de las inserciones del teclado.
                    Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(300.dp).background(Color(0xFF2B2D31)))
                }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        val imePx = (300 * activity.resources.displayMetrics.density).toInt()
        val insets = WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, imePx))
            .setVisible(WindowInsetsCompat.Type.ime(), true)
            .build()
        val content = activity.window.decorView.findViewById<android.view.ViewGroup>(android.R.id.content).getChildAt(0)
        ViewCompat.dispatchApplyWindowInsets(content, insets)
        // Compose mide y acomoda al dibujar; en Robolectric nada dibuja solo, así que se dibuja cada cuadro como el teléfono.
        val decor = activity.window.decorView
        val canvas = android.graphics.Canvas(android.graphics.Bitmap.createBitmap(decor.width, decor.height, android.graphics.Bitmap.Config.ARGB_8888))
        repeat(12) {
            decor.draw(canvas)
            shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(100))
        }
        activity.window.decorView.captureRoboImage("build/shots/13a_hoja_con_teclado.png")
        assertTrue("El campo con el foco queda encima del teclado (foco $hadFocus, $fieldBottom > ${rootHeight - imePx})", fieldBottom > 0 && fieldBottom <= rootHeight - imePx)
        controller.pause().stop().destroy()
    }
}
