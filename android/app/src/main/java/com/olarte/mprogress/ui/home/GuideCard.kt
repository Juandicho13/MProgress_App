package com.olarte.mprogress.ui.home

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Cloud
import androidx.compose.material.icons.outlined.Fingerprint
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.Guide
import com.olarte.mprogress.domain.GuidePartKind
import com.olarte.mprogress.domain.GuideSnapshot
import com.olarte.mprogress.domain.GuideStep
import com.olarte.mprogress.domain.GuideStepId
import com.olarte.mprogress.domain.GuideVisibility
import com.olarte.mprogress.domain.QuickActionKind
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.Sym
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing

/** Lo mismo que Ajustes muestra en Registro automático: en la estándar no hay nada que configurar. */
private fun autoCaptureConfigured(context: Context) = !com.olarte.mprogress.auto.AutoCapture.fullCapture ||
    com.olarte.mprogress.auto.AutoCapture.enabled(context) || com.olarte.mprogress.auto.AutoCapture.smsEnabled(context)

/**
 * "Saca todo el provecho a MProgress": primeros pasos en Inicio, debajo de los accesos rápidos, igual que GuideCard de iOS.
 * Cada paso se marca solo con los datos reales (`domain/Guide.kt`) y al tocarlo abre su pantalla con los mismos caminos
 * de los accesos rápidos. Se pliega con el chevrón, se oculta con la X y, con los ocho hechos, celebra una vez y se va.
 * Las marcas (oculta, celebrada, plegada) son de este dispositivo.
 */
@Composable
fun GuideCard(store: Store, onAction: (QuickActionKind) -> Unit, onOpenFixed: () -> Unit, onOpenAlerts: () -> Unit, onAddIncome: () -> Unit,
              onAddBank: () -> Unit) {
    val context = LocalContext.current
    val ledger by store.ledger.collectAsState()
    val alerts by store.alerts.collectAsState()
    val lock by store.lock.collectAsState()
    val cloudUi = rememberCloudUi()
    val prefs = store.prefs
    var dismissed by remember { mutableStateOf(prefs.getBoolean(Guide.DISMISSED_KEY, false)) }
    var celebrated by remember { mutableStateOf(prefs.getBoolean(Guide.CELEBRATED_KEY, false)) }
    var collapsed by remember { mutableStateOf(prefs.getBoolean(Guide.COLLAPSED_KEY, false)) }
    var firstOpen by remember { mutableStateOf(prefs.getBoolean(Guide.FIRST_STEP_OPEN_KEY, false)) }
    var permitted by remember { mutableStateOf(com.olarte.mprogress.notify.Notifier.permitted(context)) }
    var autoOn by remember { mutableStateOf(autoCaptureConfigured(context)) }
    var confirmHide by remember { mutableStateOf(false) }
    var confirmLock by remember { mutableStateOf(false) }
    // Al volver a la app (de Ajustes del teléfono o del permiso) se vuelve a leer lo que no vive en el ledger.
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val obs = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_RESUME) { permitted = com.olarte.mprogress.notify.Notifier.permitted(context); autoOn = autoCaptureConfigured(context) }
        }
        owner.lifecycle.addObserver(obs); onDispose { owner.lifecycle.removeObserver(obs) }
    }

    val active = ledger.recurring.filter { it.active }
    val snapshot = GuideSnapshot(
        hasIncome = active.any { it.kind == EntryKind.INGRESO } || ledger.entries.any { it.kind == EntryKind.INGRESO },
        hasFixedExpense = active.any { it.kind == EntryKind.GASTO },
        hasExpense = ledger.entries.any { it.kind == EntryKind.GASTO },
        hasInstitution = ledger.institutions.isNotEmpty(),
        autoCaptureConfigured = autoOn,
        hasBudget = ledger.budgets.isNotEmpty(),
        hasGoal = ledger.goals.isNotEmpty(),
        notificationsAllowed = permitted,
        hasReminder = Guide.hasReminder(active.map { it.alert.mode }, alerts.enabled),
        lockEnabled = lock,
        signedIn = cloudUi?.isSignedIn == true,
    )
    val steps = Guide.steps(snapshot)

    fun open(id: GuideStepId) {
        when (id) {
            GuideStepId.PRIMEROS_DATOS -> when (Guide.nextPart(snapshot)) {
                GuidePartKind.INGRESO -> onAddIncome()
                GuidePartKind.FIJO -> onOpenFixed()
                GuidePartKind.GASTO -> onAction(QuickActionKind.GASTO)
                null -> {}
            }
            GuideStepId.BANCOS -> onAddBank()
            GuideStepId.AUTOMATICO -> onAction(QuickActionKind.AUTOMATICO)
            GuideStepId.LIMITES -> onAction(QuickActionKind.LIMITES)
            GuideStepId.AHORRO -> onAction(QuickActionKind.AHORRO)
            GuideStepId.AVISOS -> onOpenAlerts()
            GuideStepId.BLOQUEO -> confirmLock = true
            GuideStepId.CUENTA -> com.olarte.mprogress.auto.LaunchAction.pending.value = "cuenta"
        }
    }

    when (Guide.visibility(steps, dismissed, celebrated)) {
        GuideVisibility.HIDDEN -> {}
        GuideVisibility.CELEBRATION -> {
            LaunchedEffect(Unit) {
                // Se ve unos segundos y se va sola; si sales antes de Inicio, igual queda vista.
                try { kotlinx.coroutines.delay(Guide.CELEBRATION_MILLIS) } finally {
                    prefs.edit().putBoolean(Guide.CELEBRATED_KEY, true).apply(); celebrated = true
                }
            }
            Card {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    IconTile(Icons.Outlined.Verified, Palette.exito.copy(alpha = 0.16f), Palette.exito)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                        T(Guide.CELEBRATION_TITLE, Type.titulo3)
                        T(Guide.CELEBRATION_TEXT, Type.cuerpo2, Palette.texto2)
                        GuideProgressBar(1f, Modifier.padding(top = Spacing.s1))
                    }
                }
            }
        }
        GuideVisibility.CHECKLIST -> Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T(Guide.TITLE, Type.titulo3)
                        T(Guide.progressText(steps), Type.cuerpo2, Palette.texto2)
                    }
                    GuideIconButton(if (collapsed) Icons.Rounded.KeyboardArrowDown else Icons.Rounded.KeyboardArrowUp,
                        if (collapsed) "Mostrar los pasos" else "Plegar los pasos") {
                        collapsed = !collapsed; prefs.edit().putBoolean(Guide.COLLAPSED_KEY, collapsed).apply()
                    }
                    GuideIconButton(Icons.Rounded.Close, "Ocultar los primeros pasos") { confirmHide = true }
                }
                GuideProgressBar(Guide.progress(steps))
                if (!collapsed) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                        val first = steps.first()
                        if (first.done) {
                            GuideRow(Icons.Rounded.Check, first.title, Guide.firstStepSubtitle(snapshot), done = true,
                                trailing = if (firstOpen) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown) {
                                firstOpen = !firstOpen; prefs.edit().putBoolean(Guide.FIRST_STEP_OPEN_KEY, firstOpen).apply()
                            }
                            if (firstOpen) Guide.parts(snapshot).forEach { part ->
                                Row(Modifier.padding(start = Size.baldosa + Spacing.s3).heightIn(min = 28.dp), verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                                    val c = if (part.done) Palette.exito else Palette.texto2
                                    Icon(if (part.done) Icons.Rounded.CheckCircle else Icons.Outlined.RadioButtonUnchecked, null, Modifier.size(18.dp), tint = c)
                                    T(part.title, Type.cuerpo2, c)
                                }
                            }
                        }
                        Guide.visiblePendingSteps(steps).forEach { step ->
                            GuideRow(iconOf(step), step.title, if (step.id == GuideStepId.PRIMEROS_DATOS) Guide.firstStepSubtitle(snapshot) else null) { open(step.id) }
                        }
                    }
                    Guide.moreText(steps)?.let { T(it, Type.leyenda, Palette.texto2, maxLines = 2) }
                }
            }
        }
    }

    if (confirmHide) AlertDialog(
        onDismissRequest = { confirmHide = false },
        title = { T(Guide.HIDE_QUESTION, Type.titulo3) },
        text = { T(Guide.HIDE_MESSAGE, Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({
            confirmHide = false; dismissed = true; prefs.edit().putBoolean(Guide.DISMISSED_KEY, true).apply()
        }) { T("Ocultar", Type.etiqueta, Palette.peligro) } },
        dismissButton = { TextButton({ confirmHide = false }) { T("Cancelar", Type.etiqueta) } },
        containerColor = Palette.superficie2,
    )
    if (confirmLock) AlertDialog(
        onDismissRequest = { confirmLock = false },
        title = { T("¿Proteger MProgress con huella o rostro?", Type.titulo3) },
        text = { T("Cada vez que abras la app te pide tu huella, tu rostro o el código del teléfono. Lo cambias en Ajustes.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({
            confirmLock = false
            // Igual que el interruptor de Ajustes: se confirma que funciona; si no, se queda apagado.
            val activity = context as? androidx.fragment.app.FragmentActivity
            if (activity != null && com.olarte.mprogress.ui.Biometric.available(activity)) {
                com.olarte.mprogress.ui.Biometric.authenticate(activity, "Activar el bloqueo") { ok -> store.setLock(ok) }
            } else store.showUndo("Configura una huella, rostro o código en el teléfono para usar el bloqueo.")
        }) { T("Activar bloqueo", Type.etiqueta, Palette.brasaTinta) } },
        dismissButton = { TextButton({ confirmLock = false }) { T("Ahora no", Type.etiqueta) } },
        containerColor = Palette.superficie2,
    )
}

private fun iconOf(step: GuideStep): ImageVector = when (step.id) {
    GuideStepId.PRIMEROS_DATOS -> Icons.Rounded.Add
    GuideStepId.BANCOS -> Sym.bank
    GuideStepId.AUTOMATICO -> Sym.of(QuickActionKind.AUTOMATICO)
    GuideStepId.LIMITES -> Sym.of(QuickActionKind.LIMITES)
    GuideStepId.AHORRO -> Sym.of(QuickActionKind.AHORRO)
    GuideStepId.AVISOS -> Sym.bell
    GuideStepId.BLOQUEO -> Icons.Outlined.Fingerprint
    GuideStepId.CUENTA -> Icons.Outlined.Cloud
}

@Composable
private fun GuideRow(icon: ImageVector, title: String, subtitle: String?, done: Boolean = false, trailing: ImageVector = Icons.Rounded.ChevronRight, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).clickable(onClick = onClick).padding(vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
    ) {
        if (done) IconTile(icon, Palette.exito.copy(alpha = 0.16f), Palette.exito) else IconTile(icon, Palette.brasaVelo, Palette.brasaTinta)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, Type.cuerpo, if (done) Palette.texto2 else Palette.texto1, maxLines = 2)
            subtitle?.let { T(it, Type.cuerpo2, Palette.texto2, maxLines = if (done) 1 else 2) }
        }
        Icon(trailing, null, Modifier.size(18.dp), tint = Palette.texto2)
    }
}

@Composable
private fun GuideIconButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    Box(Modifier.size(Size.toqueMinimo).clip(CircleShape).clickable(onClick = onClick).semantics { contentDescription = label }, contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(20.dp), tint = Palette.texto2)
    }
}

@Composable
private fun GuideProgressBar(ratio: Float, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(Palette.superficie3)) {
        Box(Modifier.fillMaxWidth(ratio.coerceIn(0.02f, 1f)).height(6.dp).clip(CircleShape).background(Palette.brasa))
    }
}
