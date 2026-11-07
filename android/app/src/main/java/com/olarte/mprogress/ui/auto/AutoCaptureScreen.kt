package com.olarte.mprogress.ui.auto

import com.olarte.mprogress.ui.components.appTextField

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Sms
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Contactless
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.olarte.mprogress.auto.AutoCapture
import com.olarte.mprogress.data.PendingCapture
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.planning.PlanningPage
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing

/** Registro automático (pantalla 35): fuentes, por revisar, últimos detectados y cómo se lee un mensaje. */
@Composable
fun AutoCaptureScreen(store: Store, onReview: (PendingCapture) -> Unit, onOpenEntry: (String) -> Unit, onScan: () -> Unit = {}, full: Boolean = AutoCapture.fullCapture, onBack: () -> Unit) {
    val context = LocalContext.current
    val ledger by store.ledger.collectAsState()
    var listener by remember { mutableStateOf(AutoCapture.enabled(context)) }
    var sms by remember { mutableStateOf(AutoCapture.smsEnabled(context)) }
    var tileHelp by remember { mutableStateOf(false) }
    var sample by remember { mutableStateOf("Bancolombia: Compraste \$84.300 en EXITO con tu T.Cred *4417. 05/11 13:22") }
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val obs = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_RESUME) { listener = AutoCapture.enabled(context); sms = AutoCapture.smsEnabled(context) } }
        owner.lifecycle.addObserver(obs); onDispose { owner.lifecycle.removeObserver(obs) }
    }
    val smsPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        store.prefs.edit().putBoolean(AutoCapture.KEY_SMS, ok).apply(); sms = AutoCapture.smsEnabled(context)
    }
    val detected = ledger.entries.filter { it.source == "notificacion" || it.source == "sms" }.sortedByDescending { it.occurredAt }.take(15)

    PlanningPage("Registro automático", onBack) {
        T(if (full) "Elige cómo quieres que la app se entere de tus pagos." else "Escanea recibos y anota en segundos con el botón de ajustes rápidos.", Type.cuerpo, Palette.texto2)
        // La estándar no lee notificaciones ni SMS (Play Protect la bloquearía): solo muestra lo que sí funciona.
        if (full) {
            SectionLabel("Notificaciones y SMS")
            Card(padding = Spacing.s3) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    ListRow(icon = Icons.Rounded.Contactless, tint = Palette.brasa, fg = Palette.sobreBrasa, title = "Google Wallet y bancos",
                        subtitle = "Comercio, monto y tarjeta al pagar", onClick = { AutoCapture.openListenerSettings(context) }) { Status(listener) }
                    ListRow(icon = Icons.Outlined.Sms, title = "Mensajes del banco", subtitle = "SMS de compra (versión de pruebas)", onClick = {
                        if (sms) { store.prefs.edit().putBoolean(AutoCapture.KEY_SMS, false).apply(); sms = false }
                        else if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED) {
                            store.prefs.edit().putBoolean(AutoCapture.KEY_SMS, true).apply(); sms = true
                        } else smsPermission.launch(Manifest.permission.RECEIVE_SMS)
                    }) { Status(sms) }
                    Box0 { ListRow(icon = Icons.Outlined.Email, title = "Correos de compra", subtitle = "Próximamente") }
                }
            }
        }
        if (full) T("Solo leemos las notificaciones de Wallet y de las apps de bancos y billeteras. El texto no sale del teléfono.", Type.leyenda, Palette.texto2)
        if (ledger.captures.isNotEmpty()) {
            SectionLabel("Por revisar")
            Card(padding = Spacing.s3) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    ledger.captures.sortedByDescending { it.receivedAt }.forEach { c ->
                        ListRow(icon = Icons.Rounded.CreditCard, title = "${c.merchant ?: c.bank ?: "Sin comercio"} · ${Money(c.amountMinor).formatted()}",
                            subtitle = listOfNotNull(if (c.source == "sms") "SMS" else "Notificación", c.bank, c.last4?.let { "·· $it" }, DueText.describe(c.receivedAt, java.time.LocalDate.now())).joinToString(" · "),
                            onClick = { onReview(c) }) {
                            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                                T("Descartar", Type.etiqueta, Palette.texto2, Modifier.clip(RoundedCornerShape(Radius.campo)).clickable { store.removeCapture(c.id) }.padding(Spacing.s1))
                                T("Revisar", Type.etiqueta, Palette.oro)
                            }
                        }
                    }
                }
            }
        }
        if (detected.isNotEmpty()) {
            SectionLabel("Últimos detectados")
            Card(padding = Spacing.s3) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    detected.forEach { e ->
                        val p = ledger.product(e.productId)
                        ListRow(icon = Icons.Rounded.CreditCard, title = "${e.name} · ${Money(e.amountMinor).formatted()}",
                            subtitle = listOfNotNull((if (e.source == "sms") "SMS" else "Notificación") + (p?.let { ledger.institution(it)?.name }?.let { " $it" } ?: ""),
                                p?.let { listOfNotNull(if (it.kind == ProductKind.CREDITO) "Crédito" else if (it.kind == ProductKind.DEBITO) "Débito" else it.name, it.last4?.let { l -> "·· $l" }).joinToString(" ") }).joinToString(" · "),
                            onClick = { onOpenEntry(e.id) }) { T("Guardado", Type.etiqueta, Palette.exito) }
                    }
                }
            }
        }
        if (full) Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                T("Así se lee un mensaje", Type.leyenda, Palette.texto2)
                BasicTextField(sample, { sample = it }, Modifier.appTextField().fillMaxWidth().clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3).padding(Spacing.s3),
                    textStyle = Type.cuerpo2.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa))
                val parsed = SmsParser.parse(sample, Currency.current)
                if (parsed == null) T("Este texto no parece una compra ni un pago.", Type.leyenda, Palette.texto2)
                else {
                    val brasa = Palette.brasa; val hielo = Palette.hielo; val oro = Palette.oro; val ink = Palette.texto1
                    androidx.compose.material3.Text(buildAnnotatedString {
                        withStyle(SpanStyle(color = ink)) { append(if (parsed.kind == EntryKind.INGRESO) "Recibiste " else "Pagaste ") }
                        withStyle(SpanStyle(color = brasa)) { append(Money(parsed.amountMinor).formatted()) }
                        parsed.merchant?.let { withStyle(SpanStyle(color = ink)) { append(" en ") }; withStyle(SpanStyle(color = hielo)) { append(it) } }
                        parsed.last4?.let { withStyle(SpanStyle(color = ink)) { append(" con la tarjeta ") }; withStyle(SpanStyle(color = oro)) { append("*$it") } }
                    }, style = Type.cuerpo)
                    T(if (parsed.needsReview) "Quedaría para revisar: falta ${if (parsed.merchant == null) "el comercio" else "la tarjeta"}." else "Se guardaría solo.",
                        Type.leyenda, if (parsed.needsReview) Palette.oro else Palette.exito)
                }
            }
        }
        if (full && !listener) PrimaryButton("Permitir leer notificaciones") { AutoCapture.openListenerSettings(context) }

        SectionLabel("Escanear recibos")
        Card(padding = Spacing.s3) {
            ListRow(icon = Icons.Outlined.DocumentScanner, title = "Escanear recibo", subtitle = "Total y comercio con la cámara", onClick = onScan) {
                T("Abrir", Type.etiqueta, Palette.brasaTinta)
            }
        }

        SectionLabel("Registro rápido")
        Card(padding = Spacing.s3) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                ListRow(icon = Icons.Outlined.TouchApp, title = "Botón de ajustes rápidos", subtitle = "Anota un gasto o ingreso sin buscar la app", onClick = { tileHelp = !tileHelp }) {
                    T("Cómo", Type.etiqueta, Palette.brasaTinta)
                }
                if (tileHelp) T("Desliza dos veces desde arriba, toca el lápiz de los ajustes rápidos y arrastra \"Registro rápido\" de MProgress a tus botones.", Type.cuerpo2, Palette.texto2,
                    Modifier.padding(horizontal = Spacing.s2))
            }
        }
    }
}

@Composable
private fun Box0(content: @Composable () -> Unit) = androidx.compose.foundation.layout.Box(Modifier.alpha(0.6f)) { content() }

@Composable
private fun Status(on: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        if (on) Icon(Icons.Rounded.CheckCircle, null, Modifier.size(14.dp), tint = Palette.exito)
        T(if (on) "Configurado" else "Configurar", Type.etiqueta, if (on) Palette.exito else Palette.brasaTinta)
    }
}
