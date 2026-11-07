package com.olarte.mprogress.ui.settings

import com.olarte.mprogress.ui.components.appTextField

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Drafts
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.PhoneIphone
import androidx.compose.material.icons.outlined.Sync
import androidx.compose.material.icons.outlined.MobileFriendly
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.cloud.CloudAccount
import com.olarte.mprogress.data.cloud.CloudPhase
import com.olarte.mprogress.data.cloud.CloudUi
import com.olarte.mprogress.data.cloud.RemoteDevice
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.RecoveryCode
import com.olarte.mprogress.ui.components.BackButton
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Ajustes › Cuenta y nube (docs/PLAN_F10.md), igual que AccountView de iOS: entrar con el enlace del correo, estado de la
 * sincronización, "Sincronizar ahora", código de recuperación, dispositivos y cerrar sesión. La nube es opcional.
 */
@Composable
fun AccountScreen(account: CloudAccount, onBack: () -> Unit) {
    val ui by account.ui.collectAsState()
    var page by remember { mutableStateOf<String?>(null) }
    var emailText by remember { mutableStateOf("") }
    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmNewCode by remember { mutableStateOf(false) }
    var recoveryEntry by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler(enabled = page != null) { page = null }
    LaunchedEffect(ui.phase) { if (ui.phase == CloudPhase.Ready) account.refreshDevices() }
    if (page == "dispositivos") { DevicesScreen(account) { page = null }; return }

    fun send() { account.sendLink(emailText) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        BackButton("Volver a Ajustes", onBack)
        T("Cuenta", Type.titulo1)
        when (val phase = ui.phase) {
            CloudPhase.SignedOut -> SignInCard(emailText, ui.isWorking, { emailText = it }, ::send)
            is CloudPhase.LinkSent -> LinkSentCard(phase.email, ui.isWorking, onResend = { emailText = phase.email; account.sendLink(phase.email) }, onOther = { account.cancelLink() })
            CloudPhase.Connecting -> ConnectingCard()
            CloudPhase.NeedsApproval -> ApprovalCard(ui, onCheck = { account.checkApproval() }, onRecovery = { recoveryEntry = true }, onSignOut = { confirmSignOut = true })
            CloudPhase.Ready -> ReadyContent(ui, onApprove = { account.approve(it) }, onSync = { account.syncNow() }, onRetry = { account.retryFailed() },
                onDevices = { page = "dispositivos" }, onNewCode = { confirmNewCode = true }, onSignOut = { confirmSignOut = true })
        }
        ui.errorText?.let { T(it, Type.cuerpo2, Palette.peligro) }
        T("Tus datos se cifran en este teléfono antes de subir. Ni Supabase ni nadie más puede leer tus montos, nombres o notas: solo tus dispositivos.",
            Type.leyenda, Palette.texto2)
    }

    if (recoveryEntry) RecoveryEntrySheet(ui, onCancel = { recoveryEntry = false }) { code -> account.useRecoveryCode(code) { ok -> if (ok) recoveryEntry = false } }
    if (confirmSignOut) AlertDialog(
        onDismissRequest = { confirmSignOut = false },
        title = { T("¿Cerrar sesión?", Type.titulo3) },
        text = { T("Tus datos se quedan en este teléfono. Este dispositivo sale de tu cuenta y para volver a ver lo de la nube tendrás que entrar y aprobarlo otra vez.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({ confirmSignOut = false; account.signOut() }) { T("Cerrar sesión", Type.etiqueta, Palette.peligro) } },
        dismissButton = { TextButton({ confirmSignOut = false }) { T("Cancelar", Type.etiqueta) } },
        containerColor = Palette.superficie2,
    )
    if (confirmNewCode) AlertDialog(
        onDismissRequest = { confirmNewCode = false },
        title = { T("¿Crear un código nuevo?", Type.titulo3) },
        text = { T("El código que tienes guardado deja de servir.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({ confirmNewCode = false; account.newRecoveryCode() }) { T("Crear código nuevo", Type.etiqueta, Palette.brasaTinta) } },
        dismissButton = { TextButton({ confirmNewCode = false }) { T("Cancelar", Type.etiqueta) } },
        containerColor = Palette.superficie2,
    )
}

@Composable
private fun InputBox(value: String, hint: String, keyboard: KeyboardType, capitalization: KeyboardCapitalization = KeyboardCapitalization.None,
                     style: androidx.compose.ui.text.TextStyle = Type.cuerpo, singleLine: Boolean = true, onDone: (() -> Unit)? = null, onChange: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3)
        .padding(horizontal = Spacing.s4, vertical = Spacing.s3), contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) T(hint, style, Palette.texto2, maxLines = 1)
        BasicTextField(value, onChange, Modifier.appTextField().fillMaxWidth(), textStyle = style.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa),
            singleLine = singleLine, keyboardOptions = KeyboardOptions(capitalization = capitalization, autoCorrectEnabled = false, keyboardType = keyboard,
                imeAction = if (onDone != null) ImeAction.Send else ImeAction.Default),
            keyboardActions = KeyboardActions(onSend = { onDone?.invoke() }))
    }
}

// ---------- Sin cuenta ----------

@Composable
private fun SignInCard(email: String, working: Boolean, onChange: (String) -> Unit, onSend: () -> Unit) = Card {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        T("Crear cuenta o entrar", Type.titulo3)
        T("Con una cuenta tus datos quedan respaldados y cifrados en la nube, y los ves en tus otros dispositivos. Sin contraseña: te mandamos un enlace al correo.",
            Type.cuerpo2, Palette.texto2)
        InputBox(email, "tu@correo.com", KeyboardType.Email, onDone = onSend, onChange = onChange)
        PrimaryButton(if (working) "Enviando…" else "Enviarme el enlace", enabled = !working && email.isNotBlank(), onClick = onSend)
    }
}

@Composable
private fun LinkSentCard(email: String, working: Boolean, onResend: () -> Unit, onOther: () -> Unit) = Card {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        IconTile(Icons.Outlined.Drafts, Palette.brasaVelo, Palette.brasaTinta, size = 52.dp)
        T("Revisa tu correo", Type.titulo3)
        T("Te mandamos un enlace a $email. Ábrelo en este teléfono y entras de una vez. Si no llega, mira en correo no deseado.", Type.cuerpo2, Palette.texto2)
        SecondaryButton("Reenviar el enlace", enabled = !working, onClick = onResend)
        T("Usar otro correo", Type.etiqueta, Palette.texto2, Modifier.heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).clickable(onClick = onOther)
            .padding(vertical = 15.dp, horizontal = Spacing.s1))
    }
}

@Composable
private fun ConnectingCard() = Card {
    Row(Modifier.heightIn(min = Size.toqueMinimo), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        CircularProgressIndicator(Modifier.size(22.dp), color = Palette.texto2, strokeWidth = 2.5.dp)
        T("Conectando con tu cuenta…", Type.cuerpo)
    }
}

// ---------- Segundo dispositivo ----------

@Composable
private fun ApprovalCard(ui: CloudUi, onCheck: () -> Unit, onRecovery: () -> Unit, onSignOut: () -> Unit) = Card {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        IconTile(Icons.Outlined.MobileFriendly, Palette.hieloVelo, Palette.hielo, size = 52.dp)
        T("Aprueba este dispositivo en tu otro teléfono", Type.titulo3)
        T("Abre MProgress en el teléfono donde ya tienes tu cuenta. Verás un aviso para aprobar este; también está en Ajustes › Cuenta y nube › Dispositivos.",
            Type.cuerpo2, Palette.texto2)
        PrimaryButton(if (ui.isWorking) "Buscando…" else "Ya lo aprobé", enabled = !ui.isWorking, onClick = onCheck)
        SecondaryButton("Usar el código de recuperación", onClick = onRecovery)
        ui.email?.let { T("Entraste como $it", Type.leyenda, Palette.texto2) }
        T("Cerrar sesión", Type.etiqueta, Palette.texto2, Modifier.heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).clickable(onClick = onSignOut)
            .padding(vertical = 15.dp, horizontal = Spacing.s1))
    }
}

// ---------- Con cuenta ----------

@Composable
private fun ReadyContent(ui: CloudUi, onApprove: (RemoteDevice) -> Unit, onSync: () -> Unit, onRetry: () -> Unit, onDevices: () -> Unit, onNewCode: () -> Unit,
                         onSignOut: () -> Unit) {
    ui.pendingApprovals.forEach { device ->
        Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                T("Un dispositivo nuevo quiere entrar", Type.titulo3)
                T("${deviceTitle(device)} entró con tu correo. Si fuiste tú, apruébalo para que pueda leer tus datos.", Type.cuerpo2, Palette.texto2)
                PrimaryButton("Aprobar", enabled = !ui.isWorking) { onApprove(device) }
            }
        }
    }
    Card(padding = Spacing.s2) {
        InfoRow("Correo", ui.email ?: "")
        Line()
        InfoRow("Estado", statusText(ui))
        Line()
        ActionRow("Sincronizar ahora", icon = Icons.Outlined.Sync, onClick = onSync)
        if (ui.status is com.olarte.mprogress.domain.SyncStatus.Error) {
            Line()
            ActionRow("Reintentar lo que no subió", icon = Icons.Rounded.Refresh, onClick = onRetry)
        }
        Line()
        ActionRow("Dispositivos", value = "${ui.devices.size}", chevron = true, onClick = onDevices)
        Line()
        ActionRow("Código de recuperación", value = "Crear uno nuevo", chevron = true, onClick = onNewCode)
    }
    T("Con el código de recuperación entras en un teléfono nuevo aunque pierdas todos tus dispositivos. Si lo perdiste, crea uno nuevo aquí.", Type.leyenda, Palette.texto2)
    SecondaryButton("Cerrar sesión", onClick = onSignOut)
}

/** "Sincronizado · hace 3 min". */
fun statusText(ui: CloudUi, now: Instant = Instant.now()): String {
    val base = ui.status.title
    val last = ui.lastSyncAt ?: return base
    val minutes = Duration.between(last, now).toMinutes()
    val whenText = when {
        minutes < 1 -> "hace un momento"
        minutes < 60 -> "hace $minutes min"
        else -> DueText.describe(last.atZone(ZoneId.systemDefault()).toLocalDate(), LocalDate.now()).lowercase()
    }
    return "$base · $whenText"
}

fun deviceTitle(d: RemoteDevice) = d.name ?: if (d.platform == "android") "Un teléfono Android" else "Un iPhone"

@Composable
private fun Line() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))

@Composable
private fun InfoRow(title: String, value: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
        T(title, Type.cuerpo)
        Spacer(Modifier.width(Spacing.s3))
        T(value, Type.cuerpo2, Palette.texto2, Modifier.weight(1f), align = TextAlign.End, maxLines = 1)
    }
}

@Composable
private fun ActionRow(title: String, icon: ImageVector? = null, value: String? = null, chevron: Boolean = false, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).clickable(onClick = onClick).padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        icon?.let { Icon(it, null, Modifier.size(18.dp), tint = Palette.brasaTinta) }
        T(title, Type.cuerpo, modifier = Modifier.weight(1f))
        value?.let { T(it, Type.cuerpo2, Palette.texto2, maxLines = 1) }
        if (chevron) Icon(Icons.Rounded.ChevronRight, null, Modifier.size(18.dp), tint = Palette.texto2)
    }
}

// ---------- Código de recuperación ----------

/** El código de recuperación recién creado. Se muestra una sola vez y no se cierra hasta "Ya lo guardé". */
@Composable
fun RecoveryCodeScreen(code: String, onSaved: () -> Unit) {
    val clipboard = androidx.compose.ui.platform.LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler {}
    Column(
        Modifier.fillMaxSize().background(Palette.superficie2).verticalScroll(rememberScrollState()).statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = Spacing.margen, vertical = Spacing.s4),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        T("Código de recuperación", Type.titulo3, Palette.texto2, Modifier.fillMaxWidth(), align = TextAlign.Center)
        T("Guarda tu código de recuperación", Type.titulo2)
        T("Con él entras a tus datos en un teléfono nuevo si pierdes todos tus dispositivos. Guárdalo en tu gestor de contraseñas o escríbelo en papel. Nosotros no lo tenemos y no lo podemos recuperar.",
            Type.cuerpo2, Palette.texto2)
        Card {
            val groups = code.split("-")
            Column(Modifier.semantics(mergeDescendants = true) { contentDescription = "Código de recuperación: " + code.toList().joinToString(" ") },
                verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                groups.chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        row.forEach { g ->
                            Box(Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3), contentAlignment = Alignment.Center) {
                                T(g, Type.cifra)
                            }
                        }
                    }
                }
            }
        }
        SecondaryButton(if (copied) "Copiado" else "Copiar") { clipboard.setText(androidx.compose.ui.text.AnnotatedString(code)); copied = true }
        PrimaryButton("Ya lo guardé", onClick = onSaved)
    }
}

/** Escribir el código de recuperación en un dispositivo nuevo. */
@Composable
private fun RecoveryEntrySheet(ui: CloudUi, onCancel: () -> Unit, onRecover: (String) -> Unit) {
    var text by remember { mutableStateOf("") }
    com.olarte.mprogress.ui.components.OverlaySheet(onCancel) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(top = Spacing.s3, bottom = Spacing.s6), verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("Cancelar", Type.etiqueta, Palette.brasaTinta, Modifier.heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).clickable(onClick = onCancel)
                    .padding(vertical = 15.dp, horizontal = Spacing.s1))
                T("Código de recuperación", Type.titulo3, modifier = Modifier.weight(1f).padding(end = 64.dp), align = TextAlign.Center)
            }
            T("Escribe los 24 caracteres del código que guardaste al crear tu cuenta. Los guiones y las mayúsculas no importan.", Type.cuerpo2, Palette.texto2)
            InputBox(text, "ABCD-EFGH-JKLM-NPQR-STUV-WXYZ", KeyboardType.Ascii, KeyboardCapitalization.Characters, Type.cifra, singleLine = false) { text = it }
            ui.errorText?.let { T(it, Type.cuerpo2, Palette.peligro) }
            PrimaryButton(if (ui.isWorking) "Recuperando…" else "Recuperar mis datos", enabled = RecoveryCode.normalize(text) != null && !ui.isWorking) { onRecover(text) }
        }
    }
}

// ---------- Dispositivos ----------

/** Dispositivos de la cuenta: este, los aprobados y los que esperan aprobación. */
@Composable
fun DevicesScreen(account: CloudAccount, onBack: () -> Unit) {
    val ui by account.ui.collectAsState()
    var removing by remember { mutableStateOf<RemoteDevice?>(null) }
    LaunchedEffect(Unit) { account.refreshDevices() }
    SettingsPage("Dispositivos", onBack) {
        Card(padding = Spacing.s3) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                ui.devices.forEach { device ->
                    val isThis = device.id == ui.thisDeviceId
                    val waiting = ui.pendingApprovals.any { it.id == device.id }
                    val since = device.createdAt?.let { "Desde el ${DueText.shortDate(it.atZone(ZoneId.systemDefault()).toLocalDate(), LocalDate.now())}" } ?: ""
                    ListRow(icon = if (device.platform == "android") Icons.Outlined.PhoneAndroid else Icons.Outlined.PhoneIphone,
                        title = if (isThis) "Este teléfono" else deviceTitle(device), subtitle = if (waiting) "Espera tu aprobación" else since) {
                        when {
                            waiting -> T("Aprobar", Type.etiqueta, Palette.brasaTinta, Modifier.heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo))
                                .clickable { account.approve(device) }.padding(vertical = 15.dp, horizontal = Spacing.s2))
                            !isThis -> Box(Modifier.size(Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).clickable { removing = device }
                                .semantics { contentDescription = "Quitar" }, contentAlignment = Alignment.Center) {
                                Icon(Icons.Outlined.Delete, null, Modifier.size(20.dp), tint = Palette.peligro)
                            }
                        }
                    }
                }
                if (ui.devices.isEmpty()) T("Cargando…", Type.cuerpo2, Palette.texto2, Modifier.padding(Spacing.s2))
            }
        }
        T("Quitar un dispositivo lo saca de tu cuenta: ya no recibe tus cambios nuevos. Lo que ya tenía guardado se queda en él.", Type.leyenda, Palette.texto2)
    }
    removing?.let { device ->
        AlertDialog(
            onDismissRequest = { removing = null },
            title = { T("¿Quitar este dispositivo?", Type.titulo3) },
            text = { T("${deviceTitle(device)} sale de tu cuenta.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ removing = null; account.remove(device) }) { T("Quitar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ removing = null }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}

/** "¿Apruebas tu otro dispositivo?": sale en cualquier pantalla cuando otro teléfono entró con tu correo. */
@Composable
fun ApprovalPrompt(account: CloudAccount) {
    val ui by account.ui.collectAsState()
    val device = ui.approvalPrompt ?: return
    AlertDialog(
        onDismissRequest = { account.dismissApproval(device) },
        title = { T("¿Apruebas tu otro dispositivo?", Type.titulo3) },
        text = { T("${deviceTitle(device)} entró con tu correo. Si fuiste tú, apruébalo para que pueda leer tus datos cifrados.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({ account.approve(device) }) { T("Aprobar", Type.etiqueta, Palette.brasaTinta) } },
        dismissButton = { TextButton({ account.dismissApproval(device) }) { T("Ahora no", Type.etiqueta) } },
        containerColor = Palette.superficie2,
    )
}
