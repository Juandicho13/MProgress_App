package com.olarte.mprogress.ui

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Permiso de notificaciones en el momento justo (Paso 2): al crear el primer pago fijo o al terminar el onboarding con fijos.
 * La pregunta "¿Te aviso antes de cada pago?" la muestra la pantalla principal cuando `ask` es verdadero.
 */
object Permissions {
    private val _ask = MutableStateFlow(false)
    val ask: StateFlow<Boolean> = _ask
    /** Lo pone la actividad: sabe si ya hay permiso o si ya se preguntó. */
    var shouldAsk: () -> Boolean = { false }

    fun askAfterFirstFixed() { if (shouldAsk()) _ask.value = true }
    fun done() { _ask.value = false }
}
