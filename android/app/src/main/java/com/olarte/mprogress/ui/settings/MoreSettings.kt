package com.olarte.mprogress.ui.settings

import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.notify.Notifier
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/** Pantalla de Ajustes con botón para volver y título grande. */
@Composable
fun SettingsPage(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        BackButton("Volver", onBack)
        T(title, Type.titulo1)
        content()
    }
}

/** Avisos (pantalla 22): lo de hoy y mañana, permiso, aviso general y otros avisos. */
@Composable
fun AlertsScreen(store: Store, onBack: () -> Unit) {
    val context = LocalContext.current
    val ledger by store.ledger.collectAsState()
    val alerts by store.alerts.collectAsState()
    var permitted by remember { mutableStateOf(Notifier.permitted(context)) }
    val asked = store.prefs.getBoolean(Notifier.KEY_ASKED, false)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        permitted = Notifier.permitted(context); store.prefs.edit().putBoolean(Notifier.KEY_ASKED, true).apply(); Notifier.reschedule(context, store)
    }
    var daysMenu by remember { mutableStateOf(false) }
    var pickingTime by remember { mutableStateOf(false) }
    val today = LocalDate.now()

    SettingsPage("Avisos", onBack) {
        SectionLabel("Hoy")
        Card(padding = Spacing.s3) {
            val charges = BalanceCalculator.upcoming(ledger.recurring, today, kind = null, limit = 50).filter { it.daysLeft <= 1 }
            val budgets = BudgetMath.statuses(ledger.budgets, ledger.entries, today).filter { it.level > BudgetLevel.BIEN }
            if (charges.isEmpty() && budgets.isEmpty()) T("Nada pendiente por hoy.", Type.cuerpo2, Palette.texto2, Modifier.padding(Spacing.s2))
            charges.forEach { c ->
                ListRow(icon = Icons.Outlined.Notifications, tint = Palette.oroRelleno.copy(alpha = 0.18f), fg = Palette.oro,
                    title = "${c.name} ${if (c.kind == EntryKind.INGRESO) "llega" else "se cobra"} ${if (c.daysLeft < 0) "y está vencido" else ReminderPlanner.inDays(maxOf(0, c.daysLeft))}",
                    subtitle = Money(c.amountMinor).formatted())
            }
            budgets.forEach { b ->
                val over = b.level == BudgetLevel.SUPERADO
                val name = Categories.byId(b.budget.categoryId)?.name ?: "El total del mes"
                ListRow(icon = Icons.Outlined.WarningAmber, tint = if (over) Palette.peligroVelo else Palette.brasaVelo, fg = if (over) Palette.peligro else Palette.brasaTinta,
                    title = if (over) "Te pasaste del límite" else "Te acercas al límite", subtitle = "$name al ${Math.round(b.ratio * 100)} %")
            }
        }
        if (!permitted) {
            Card {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    T("Las notificaciones están apagadas", Type.titulo3)
                    if (asked) {
                        T("Para que te avisemos antes de cada pago: abre Ajustes del teléfono › Notificaciones › MProgress y activa Permitir notificaciones.", Type.cuerpo2, Palette.texto2)
                        SecondaryButton("Abrir ajustes del teléfono") {
                            context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                    } else {
                        T("Actívalas para que te avisemos antes de cada pago y cuando te acerques a un límite.", Type.cuerpo2, Palette.texto2)
                        PrimaryButton("Activar notificaciones") { if (Build.VERSION.SDK_INT >= 33) launcher.launch(android.Manifest.permission.POST_NOTIFICATIONS) }
                    }
                }
            }
        }
        SectionLabel("Aviso general de pagos fijos")
        Card(padding = Spacing.s2) {
            FormToggle("Avisarme antes de cada pago", alerts.enabled) {
                store.setAlerts(alerts.copy(enabled = it))
                if (it && !permitted && Build.VERSION.SDK_INT >= 33) launcher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            }
            FormDivider()
            Box {
                FormRow("Días antes", if (alerts.daysBefore == 0) "El mismo día" else "${alerts.daysBefore}", enabled = alerts.enabled, onClick = { daysMenu = true })
                DropdownMenu(daysMenu, { daysMenu = false }, containerColor = Palette.superficie2) {
                    (0..14).forEach { d -> DropdownMenuItem({ T(if (d == 0) "El mismo día" else "$d", Type.cuerpo) }, { store.setAlerts(alerts.copy(daysBefore = d)); daysMenu = false }) }
                }
            }
            FormDivider()
            FormRow("Hora del aviso", ReminderPlanner.timeText(alerts.atMinutes), onClick = { pickingTime = true })
        }
        T("Cada pago fijo usa este aviso, uno propio o ninguno: en Pagos fijos tócalo y elige Aviso.", Type.leyenda, Palette.texto2)
        SectionLabel("Otros avisos")
        Card(padding = Spacing.s2) {
            FormToggle("Avisar al acercarme a un límite", alerts.budgets) { store.setAlerts(alerts.copy(budgets = it)) }
            FormDivider()
            FormToggle("Avisar el pago de mis tarjetas", alerts.cards) { store.setAlerts(alerts.copy(cards = it)) }
        }
        T("Los límites avisan al 80 % y al 100 %. Las tarjetas usan los días y la hora del aviso general.", Type.leyenda, Palette.texto2)
    }
    if (pickingTime) TimePickDialog(alerts.atMinutes, { pickingTime = false }) { store.setAlerts(alerts.copy(atMinutes = it)); pickingTime = false }
}

/** Moneda (pantalla 28): buscador y lista con las mismas monedas de iOS. */
@Composable
fun CurrencyScreen(store: Store, onBack: () -> Unit) {
    val current by store.currency.collectAsState()
    var query by remember { mutableStateOf("") }
    val key = HistoryMath.normalize(query)
    val items = if (key.isEmpty()) Currency.all else Currency.all.filter { HistoryMath.normalize("${it.code} ${it.name}").contains(key) }
    SettingsPage("Moneda", onBack) {
        SearchField(query, "Buscar moneda") { query = it }
        Card(padding = Spacing.s2) {
            items.forEachIndexed { i, c ->
                val on = c.code == current.code
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable { store.setCurrency(c) }.padding(horizontal = Spacing.s2),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    T(c.code, Type.titulo3, modifier = Modifier.width(52.dp))
                    T(c.symbol, Type.cuerpo2, Palette.texto2, Modifier.width(40.dp))
                    T(c.name, Type.cuerpo, modifier = Modifier.weight(1f))
                    Box(Modifier.size(22.dp).clip(CircleShape).background(if (on) Palette.brasa else Color.Transparent)
                        .border(2.dp, if (on) Palette.brasa else Palette.texto2.copy(alpha = 0.6f), CircleShape), contentAlignment = Alignment.Center) {
                        if (on) Icon(Icons.Rounded.Check, null, Modifier.size(14.dp), tint = Palette.sobreBrasa)
                    }
                }
                if (i < items.lastIndex) FormDivider()
            }
        }
        T("Cada cuenta puede tener su moneda. Un viaje en euros no cambia tu cuenta personal. Cambiar la moneda no convierte los montos ya guardados.", Type.leyenda, Palette.texto2)
    }
}

fun lastBackupText(store: Store): String {
    val last = store.prefs.getLong(com.olarte.mprogress.data.BackupService.KEY_LAST, 0)
    if (last == 0L) return "Nunca"
    val dt = java.time.Instant.ofEpochMilli(last).atZone(java.time.ZoneId.systemDefault())
    return DueText.describe(dt.toLocalDate(), LocalDate.now())
}

/** Respaldo y dispositivos (pantalla 4): respaldo cifrado diario, Exportar (.mprogress y CSV) y Restaurar. Mismo formato de archivo que iOS. */
@Composable
fun BackupScreen(store: Store, onBack: () -> Unit) {
    val context = LocalContext.current
    var tick by remember { mutableStateOf(0) }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var pending by remember { mutableStateOf<Pair<com.olarte.mprogress.data.Ledger, Currency>?>(null) }
    val last = remember(tick) { store.prefs.getLong(com.olarte.mprogress.data.BackupService.KEY_LAST, 0) }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching { context.contentResolver.openOutputStream(uri)!!.use { it.write(com.olarte.mprogress.data.BackupCodec.encode(store.ledger.value, store.currency.value).toString().toByteArray()) } }
            .onSuccess { message = "Exportaste el respaldo." }.onFailure { error = "No se pudo guardar el archivo." }
    }
    val csv = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching { context.contentResolver.openOutputStream(uri)!!.use { it.write(com.olarte.mprogress.data.BackupCodec.csv(store.ledger.value, store.currency.value).toByteArray()) } }
            .onSuccess { message = "Exportaste los movimientos en CSV." }.onFailure { error = "No se pudo guardar el archivo." }
    }
    val restore = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching { com.olarte.mprogress.data.BackupCodec.decode(context.contentResolver.openInputStream(uri)!!.bufferedReader().readText()) }
            .onSuccess { pending = it }.onFailure { error = it.message ?: "Este archivo no es un respaldo de MProgress." }
    }
    SettingsPage("Respaldo", onBack) {
        Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    IconTile(if (last > 0) Icons.Rounded.Check else Icons.Outlined.WarningAmber, if (last > 0) Palette.brasa else Palette.oroRelleno.copy(alpha = 0.2f),
                        if (last > 0) Palette.sobreBrasa else Palette.oro, size = 40.dp, circle = true)
                    Column {
                        T(if (last > 0) "Todo está a salvo" else "Aún sin respaldo", Type.titulo3)
                        T(if (last > 0) "Último respaldo: ${lastBackupText(store).lowercase()}, ${java.time.Instant.ofEpochMilli(last).atZone(java.time.ZoneId.systemDefault()).toLocalTime().let { ReminderPlanner.timeText(it.hour * 60 + it.minute) }}"
                          else "La app se respalda sola una vez al día.", Type.cuerpo2, Palette.texto2)
                    }
                }
                PrimaryButton("Respaldar ahora") {
                    runCatching { com.olarte.mprogress.data.BackupService.backupNow(context, store) }.onSuccess { message = "Listo, respaldo guardado."; tick++ }
                        .onFailure { error = "No se pudo hacer el respaldo." }
                }
                message?.let { T(it, Type.leyenda, Palette.exito) }
            }
        }
        SectionLabel("Dónde se guarda")
        Card(padding = Spacing.s2) {
            Place("En este teléfono", "Cifrado, uno por día, los últimos 7.", true)
            FormDivider()
            Place("Google Drive", "Llega más adelante. Mientras tanto, exporta el archivo y guárdalo donde quieras.", false)
            FormDivider()
            val signedIn = remember { runCatching { com.olarte.mprogress.data.cloud.CloudAccount.get(context).ui.value.isSignedIn }.getOrDefault(false) }
            Place("Cuenta MProgress", if (signedIn) "Cifrado de extremo a extremo y sincronizado con tus otros teléfonos." else "Cifrada y sincronizada entre tus teléfonos. Actívala en Ajustes › Cuenta y nube.", signedIn)
        }
        SectionLabel("Exportar e importar")
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            SecondaryButton("Exportar", Modifier.weight(1f)) { export.launch(com.olarte.mprogress.data.BackupCodec.fileName(LocalDate.now())) }
            SecondaryButton("Restaurar", Modifier.weight(1f)) { restore.launch(arrayOf("*/*")) }
        }
        SecondaryButton("Movimientos en CSV") { csv.launch(com.olarte.mprogress.data.BackupCodec.fileName(LocalDate.now(), "csv")) }
        T("El archivo .mprogress trae todo: movimientos, pagos fijos, bancos, límites y metas, y se abre igual en el iPhone. El CSV abre en Excel o Google Sheets.", Type.leyenda, Palette.texto2)
        SignatureFooter()
    }
    pending?.let { (ledger, currency) ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { pending = null },
            title = { T("¿Restaurar este respaldo?", Type.titulo3) },
            text = { T("Trae ${com.olarte.mprogress.data.BackupCodec.summary(ledger)}. Lo que hay ahora en la app se reemplaza. Antes se guarda un respaldo de hoy por si acaso.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { androidx.compose.material3.TextButton({
                runCatching { com.olarte.mprogress.data.BackupService.backupNow(context, store) }
                store.replaceAll(ledger); store.setCurrency(currency); pending = null; message = "Restauraste el respaldo."; tick++
            }) { T("Restaurar y reemplazar", Type.etiqueta, Palette.peligro) } },
            dismissButton = { androidx.compose.material3.TextButton({ pending = null }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
    error?.let { e ->
        androidx.compose.material3.AlertDialog(onDismissRequest = { error = null }, title = { T("No se pudo", Type.titulo3) }, text = { T(e, Type.cuerpo2, Palette.texto2) },
            confirmButton = { androidx.compose.material3.TextButton({ error = null }) { T("Entendido", Type.etiqueta, Palette.brasaTinta) } }, containerColor = Palette.superficie2)
    }
}

@Composable
private fun Place(title: String, detail: String, on: Boolean) {
    Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.s2, vertical = Spacing.s3), horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
        Column(Modifier.weight(1f)) { T(title, Type.cuerpo); T(detail, Type.leyenda, Palette.texto2) }
        Icon(if (on) Icons.Rounded.Check else Icons.Outlined.Schedule, null, Modifier.size(20.dp), tint = if (on) Palette.brasa else Palette.texto2)
    }
}

/** Novedades (pantalla 30): tarjetas por versión. */
@Composable
fun WhatsNewScreen(onBack: () -> Unit) {
    val versions = listOf(
        Triple("1.1", "Nov 2026", listOf("Resumen sin predicciones: Este mes con lo que entró, gastaste, fijos que faltan y te quedan", "Los próximos 3 meses solo con tus pagos fijos", "¿Tu sueldo es $ 2? para arreglar un ingreso fijo mal escrito", "Próximos cargos con Ver todos y Ver menos", "El teclado ya no tapa lo que escribes y Samsung Pass no sale en los campos")),
        Triple("1.0", "Nov 2026", listOf("Cuenta y nube: entra con un enlace a tu correo, sin contraseña", "Tus datos se cifran en el teléfono y se sincronizan con tu iPhone y tus otros teléfonos", "Código de recuperación y aprobar dispositivos nuevos")),
        Triple("0.9.1", "Nov 2026", listOf("Dos versiones: la estándar se instala sin que Play Protect la bloquee; la completa, desde el Mac, también lee notificaciones y SMS del banco")),
        Triple("0.9", "Nov 2026", listOf("Registro automático con las notificaciones de Google Wallet y los bancos, y SMS con permiso", "Botón Registro rápido en los ajustes rápidos", "Widgets: Próximo cargo, Te quedan y Calendario de cobros")),
        Triple("0.8", "Nov 2026", listOf("Así vas a terminar el mes y los próximos 3 meses en Resumen", "Alerta en Inicio si a este ritmo terminas en negativo", "Día del mes al agregar un fijo mensual")),
        Triple("0.7", "Nov 2026", listOf("Escanear recibos con la cámara o una foto de la galería: lee el total y el comercio en el teléfono")),
        Triple("0.6", "Nov 2026", listOf("Transferir y pagar tarjeta", "Límites y metas de ahorro", "Puntos y millas que se suman solos con cada gasto", "Varios efectivos con nombre propio")),
        Triple("0.5", "Nov 2026", listOf("Avisos de pagos fijos, tarjetas y límites", "Bloqueo con huella o rostro", "Moneda del espacio", "Respaldo cifrado diario, exportar y restaurar con el mismo archivo de iOS")),
        Triple("0.4", "Nov 2026", listOf("Pagos fijos completos con cuotas y fecha final", "Detalle de movimiento con editar, duplicar y borrar", "Categorías en Agregar y en Resumen")),
    )
    SettingsPage("Novedades", onBack) {
        versions.forEach { (v, date, items) ->
            Card {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    Row { T("Versión $v", Type.titulo3, modifier = Modifier.weight(1f)); T(date, Type.leyenda, Palette.texto2) }
                    items.forEach { line ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                            Box(Modifier.size(5.dp).clip(CircleShape).background(Palette.brasa)); T(line, Type.cuerpo2, Palette.texto2)
                        }
                    }
                }
            }
        }
    }
}
