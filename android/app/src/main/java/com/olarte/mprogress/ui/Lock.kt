package com.olarte.mprogress.ui

import android.os.SystemClock
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.LockDelay
import com.olarte.mprogress.domain.LockTimeout
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing

/** Huella, rostro o el código del teléfono (BiometricPrompt), como LAContext de iOS. */
object Biometric {
    private const val AUTH = BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL

    fun available(activity: FragmentActivity) = BiometricManager.from(activity).canAuthenticate(AUTH) == BiometricManager.BIOMETRIC_SUCCESS

    fun authenticate(activity: FragmentActivity, title: String, onResult: (Boolean) -> Unit) {
        val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onResult(true)
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) = onResult(false)
        })
        prompt.authenticate(BiometricPrompt.PromptInfo.Builder().setTitle(title).setSubtitle("Abre tus finanzas").setAllowedAuthenticators(AUTH).build())
    }
}

/**
 * Bloqueo al abrir y al volver a la app, igual que LockGate de iOS. Con "Bloquear" en Ajustes (como WhatsApp) solo pide la huella
 * si estuvo fuera al menos ese tiempo; al abrirla en frío, siempre. Fuera de la app siempre queda tapada.
 */
@Composable
fun LockGate(enabled: Boolean, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val activity = context as? FragmentActivity
    var locked by remember { mutableStateOf(enabled) }
    var covered by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    /** Cuándo se fue a segundo plano (reloj que sigue contando con el teléfono dormido). */
    var backgroundedAt by remember { mutableStateOf<Long?>(null) }
    /** Mientras se muestra la huella o el código, salir y volver no cuenta como salir de la app. */
    var authenticating by remember { mutableStateOf(false) }
    fun unlock() {
        val a = activity ?: run { locked = false; return }
        authenticating = true
        Biometric.authenticate(a, "Desbloquear MProgress") { ok -> authenticating = false; locked = !ok; failed = !ok }
    }
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner, enabled) {
        val obs = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_STOP && enabled && !authenticating) {
                covered = true
                if (backgroundedAt == null) backgroundedAt = SystemClock.elapsedRealtime()
            }
            if (e == Lifecycle.Event.ON_START && enabled && !authenticating) {
                covered = false
                backgroundedAt?.let { at ->
                    val delay = LockDelay.from(runCatching { Store.get(context).prefs.getInt(LockDelay.STORAGE_KEY, 0) }.getOrDefault(0))
                    if (LockTimeout.requiresAuth(at, SystemClock.elapsedRealtime(), delay)) locked = true
                }
                backgroundedAt = null
                if (locked) unlock()
            }
        }
        owner.lifecycle.addObserver(obs)
        onDispose { owner.lifecycle.removeObserver(obs) }
    }
    LaunchedEffect(enabled) { if (!enabled) locked = false }
    Box(Modifier.fillMaxSize()) {
        content()
        if (enabled && !locked && covered) {
            // Lo que se ve en el selector de apps mientras no hace falta desbloquear.
            Box(Modifier.fillMaxSize().background(Palette.fondo), contentAlignment = Alignment.Center) {
                IconTile(Icons.Rounded.Lock, Palette.brasaVelo, Palette.brasaTinta, size = 72.dp, circle = true)
            }
        }
        if (enabled && locked) {
            Column(Modifier.fillMaxSize().background(Palette.fondo).padding(Spacing.margen), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.s5, Alignment.CenterVertically)) {
                IconTile(Icons.Rounded.Lock, Palette.brasaVelo, Palette.brasaTinta, size = 72.dp, circle = true)
                T("MProgress está bloqueada", Type.titulo2)
                if (failed) T("No pudimos reconocerte.", Type.cuerpo2, Palette.texto2)
                PrimaryButton("Desbloquear", Modifier.width(240.dp)) { unlock() }
            }
        }
    }
}
