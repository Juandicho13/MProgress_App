package com.olarte.mprogress.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentDataType
import androidx.compose.ui.composed
import androidx.compose.ui.focus.onFocusEvent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDataType
import androidx.compose.ui.semantics.semantics

/**
 * Modifier de todos los campos de texto de la app (va en cada BasicTextField):
 * - Sin autocompletar: ningún gestor de contraseñas (Samsung Pass, Google) ofrece "ID y contraseñas" en montos,
 *   nombres ni últimos 4 dígitos. Compose deja de avisarle al servicio cuando el campo tiene `ContentDataType.None`.
 * - Siempre a la vista: cuando el campo tiene el foco y el teclado aparece o cambia de alto, la lista o la hoja
 *   que lo contiene se desplaza para mostrarlo encima del teclado.
 */
@OptIn(ExperimentalFoundationApi::class)
fun Modifier.appTextField(): Modifier = composed {
    val requester = remember { BringIntoViewRequester() }
    var focused by remember { mutableStateOf(false) }
    val imeBottom = WindowInsets.ime.getBottom(LocalDensity.current)
    LaunchedEffect(focused, imeBottom) {
        if (focused) {
            // Espera a que la pantalla se acomode al nuevo alto del teclado antes de desplazar.
            withFrameNanos { }
            withFrameNanos { }
            requester.bringIntoView()
        }
    }
    this.semantics { contentDataType = ContentDataType.None }
        .bringIntoViewRequester(requester)
        .onFocusEvent { focused = it.isFocused }
}
