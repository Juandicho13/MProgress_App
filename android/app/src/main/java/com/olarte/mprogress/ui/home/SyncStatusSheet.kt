package com.olarte.mprogress.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudDone
import androidx.compose.material.icons.outlined.CloudOff
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.PhoneIphone
import androidx.compose.material.icons.outlined.SyncProblem
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.cloud.CloudAccount
import com.olarte.mprogress.data.cloud.CloudUi
import com.olarte.mprogress.domain.InitialUpload
import com.olarte.mprogress.domain.SyncPill
import com.olarte.mprogress.domain.SyncText
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.ListRow
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.settings.deviceTitle
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.Instant

/** El estado de la cuenta en la nube para las pantallas (null si la cuenta no se pudo abrir, por ejemplo en algunas pruebas). */
@Composable
fun rememberCloudUi(): CloudUi? {
    val context = LocalContext.current
    val cloud = remember { runCatching { CloudAccount.get(context) }.getOrNull() } ?: return null
    val ui by cloud.ui.collectAsState()
    return ui
}

/**
 * Pastilla de sincronización de Inicio (F10-04, pantalla 36): solo con cuenta. "Al día", "Sincronizando…",
 * "Sin conexión · 3 pendientes" o "Error al sincronizar". Al tocarla abre la hoja de estado (pantalla 37). Igual que iOS.
 */
@Composable
fun SyncPill() {
    val context = LocalContext.current
    val cloud = remember { runCatching { CloudAccount.get(context) }.getOrNull() } ?: return
    val ui by cloud.ui.collectAsState()
    var open by remember { mutableStateOf(false) }
    val pill = ui.pill ?: return
    SyncPillChip(pill) { open = true }
    if (open) SyncStatusSheet(cloud) { open = false }
}

fun syncPillIcon(pill: SyncPill): ImageVector = when (pill) {
    SyncPill.AlDia -> Icons.Outlined.CloudDone
    SyncPill.Sincronizando -> Icons.Outlined.CloudSync
    is SyncPill.SinConexion -> Icons.Outlined.CloudOff
    SyncPill.Error -> Icons.Outlined.SyncProblem
}

@Composable
fun SyncPillChip(pill: SyncPill, onClick: () -> Unit) {
    val fg = if (pill == SyncPill.Error) Palette.peligro else Palette.texto1
    Box(Modifier.heightIn(min = Size.toqueMinimo), contentAlignment = Alignment.CenterStart) {
        Row(Modifier.heightIn(min = 36.dp).clip(CircleShape).background(Palette.vidrioTinte.copy(alpha = 0.78f)).border(1.dp, Palette.vidrioBorde, CircleShape)
            .clickable(onClick = onClick).semantics(mergeDescendants = true) { contentDescription = pill.text + ". Toca para ver el estado de la sincronización" }
            .padding(horizontal = Spacing.s4), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            Icon(syncPillIcon(pill), null, Modifier.size(16.dp), tint = fg)
            T(pill.text, Type.etiqueta, fg, maxLines = 1)
        }
    }
}

/** Hoja "Estado de sincronización" (F10-04, pantalla 37), como SyncStatusSheet.swift. Hoja de ventana: queda encima de todo. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SyncStatusSheet(account: CloudAccount, onDismiss: () -> Unit) {
    val ui by account.ui.collectAsState()
    LaunchedEffect(Unit) { account.refreshDevices() }
    ModalBottomSheet(onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        dragHandle = null, containerColor = Palette.superficie2, shape = RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)) {
        SyncStatusContent(ui, Instant.now(), onRetry = { account.retryFailed() }, onSync = { account.syncNow() }, onClose = onDismiss)
    }
}

/** El contenido de la hoja, solo con lo que muestra (así sale igual en las capturas). */
@Composable
fun SyncStatusContent(ui: CloudUi, now: Instant, onRetry: () -> Unit, onSync: () -> Unit, onClose: () -> Unit) {
    val pill = ui.pill ?: SyncPill.AlDia
    Column(Modifier.fillMaxWidth().navigationBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.margen)
        .padding(top = Spacing.s3, bottom = Spacing.s6), verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.width(56.dp))
            T("Estado de sincronización", Type.titulo3, modifier = Modifier.weight(1f), align = TextAlign.Center, maxLines = 1)
            T("Listo", Type.etiqueta, Palette.brasaTinta, Modifier.width(56.dp).heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo))
                .clickable(onClick = onClose).padding(vertical = 15.dp), align = TextAlign.End)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3), modifier = Modifier.semantics(mergeDescendants = true) {}) {
            val (tint, fg) = pillColors(pill)
            IconTile(syncPillIcon(pill), tint, fg, size = 52.dp)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(pill.text, Type.titulo2)
                if (ui.initialUploadDone && ui.upload == null && pill == SyncPill.AlDia) T(InitialUpload.DONE_TEXT, Type.cuerpo2, Palette.texto2)
            }
        }
        Card(padding = Spacing.s2) {
            StatusRow("Conexión", SyncText.connection(ui.isReachable))
            StatusLine()
            StatusRow("Última sincronización", SyncText.relative(ui.lastSyncAt, now))
            StatusLine()
            StatusRow("Pendientes", SyncText.pendingSummary(ui.pendingCounts))
        }
        ui.upload?.let { p ->
            Card {
                Row(Modifier.heightIn(min = Size.toqueMinimo), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    CircularProgressIndicator(Modifier.size(22.dp), color = Palette.texto2, strokeWidth = 2.5.dp)
                    T(InitialUpload.progressText(p.done, p.total), Type.cuerpo)
                }
            }
        }
        if (!ui.isReachable) T(SyncText.OFFLINE_NOTE, Type.leyenda, Palette.texto2)
        val problem = ui.lastError ?: SyncText.failedText(ui.failedCount)
        if (problem != null) {
            Card {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    T("No se pudo sincronizar", Type.titulo3, Palette.peligro)
                    T(problem, Type.cuerpo2, Palette.texto2)
                    PrimaryButton("Reintentar", enabled = pill != SyncPill.Sincronizando, onClick = onRetry)
                }
            }
        } else {
            SecondaryButton("Sincronizar ahora", enabled = ui.isReachable && pill != SyncPill.Sincronizando, onClick = onSync)
        }
        if (ui.devices.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                SectionLabel("Dispositivos con acceso")
                Card(padding = Spacing.s3) {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                        ui.devices.forEach { device ->
                            val waiting = ui.pendingApprovals.any { it.id == device.id }
                            ListRow(icon = if (device.platform == "android") Icons.Outlined.PhoneAndroid else Icons.Outlined.PhoneIphone,
                                title = if (device.id == ui.thisDeviceId) "Este teléfono" else deviceTitle(device),
                                subtitle = if (waiting) "Espera tu aprobación" else "Con acceso")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun pillColors(pill: SyncPill): Pair<Color, Color> = when (pill) {
    SyncPill.AlDia -> Palette.superficie3 to Palette.exito
    SyncPill.Sincronizando -> Palette.hieloVelo to Palette.hielo
    is SyncPill.SinConexion -> Palette.oro.copy(alpha = 0.16f) to Palette.oro
    SyncPill.Error -> Palette.peligroVelo to Palette.peligro
}

@Composable
private fun StatusLine() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))

@Composable
private fun StatusRow(title: String, value: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = Spacing.s2, vertical = Spacing.s3).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically) {
        T(title, Type.cuerpo)
        Spacer(Modifier.width(Spacing.s3))
        T(value, Type.cuerpo2, Palette.texto2, Modifier.weight(1f), align = TextAlign.End, maxLines = 2)
    }
}
