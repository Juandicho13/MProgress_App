package com.olarte.mprogress.auto

import android.Manifest
import android.app.Notification
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.olarte.mprogress.data.Ledger
import com.olarte.mprogress.data.PendingCapture
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import com.olarte.mprogress.notify.Notifier
import java.time.LocalDate

/** Registro automático (Paso 3, Android): lee notificaciones de Wallet y de los bancos, y SMS si se da permiso. */
object AutoCapture {
    const val KEY_SMS = "auto.sms"
    private const val KEY_RECENT = "auto.recientes"

    /**
     * Leer notificaciones y SMS solo viene en la versión completa (se instala desde el Mac). La estándar no los declara porque
     * Google Play Protect bloquea instalar por archivo una app que los pide.
     */
    val fullCapture get() = com.olarte.mprogress.BuildConfig.CAPTURA_COMPLETA

    fun enabled(context: Context) = fullCapture && NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)
    fun smsEnabled(context: Context) = fullCapture && Store.get(context).prefs.getBoolean(KEY_SMS, false) &&
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    /** El producto del pago: la tarjeta con esos últimos 4, o la cuenta o tarjeta del banco que se nombra. */
    fun matchProduct(l: Ledger, c: ParsedCharge): String? {
        c.last4?.let { l4 -> l.products.firstOrNull { it.last4 == l4 }?.let { return it.id } }
        val bank = c.bank ?: return null
        val inst = l.institutions.firstOrNull { HistoryMath.normalize(it.name) == HistoryMath.normalize(bank) } ?: return null
        val products = l.products.filter { it.institutionId == inst.id }
        return (products.firstOrNull { it.kind == ProductKind.CUENTA } ?: products.firstOrNull { it.kind != ProductKind.BOLSILLO })?.id
    }

    /** Procesa un texto: si está claro lo anota; si no, queda para revisar. Devuelve true si se usó. */
    fun handle(context: Context, source: String, packageName: String, title: String?, text: String?): Boolean {
        val store = Store.get(context)
        val parsed = NotificationParser.parse(packageName, title, text, store.currency.value) ?: return false
        val today = LocalDate.now()
        val key = NotificationParser.dedupKey(parsed, today)
        val recent = store.prefs.getStringSet(KEY_RECENT, emptySet())!!.filter { it.startsWith(today.toString()) || it.startsWith(today.minusDays(1).toString()) }.toSet()
        if (key in recent) return true
        store.prefs.edit().putStringSet(KEY_RECENT, recent + key).apply()

        val ledger = store.ledger.value
        val productId = matchProduct(ledger, parsed)
        val raw = listOfNotNull(title, text).joinToString(" · ")
        if (parsed.needsReview || productId == null) {
            store.addCapture(PendingCapture(kind = parsed.kind, amountMinor = parsed.amountMinor, merchant = parsed.merchant, last4 = parsed.last4,
                bank = parsed.bank, source = source, text = raw, receivedAt = today))
            Notifier.show(context, "mp.auto.$key", "Revisa un pago", "${signedAmount(parsed)} · ${parsed.merchant ?: parsed.bank ?: "sin comercio"}. Tócalo para confirmarlo.", Notifier.CHANNEL_REGISTRO, "revisar")
        } else {
            store.add(parsed.kind, parsed.merchant ?: parsed.bank ?: "Pago", parsed.amountMinor, Cycle.Puntual, today, productId, today, source = source)
            val l = store.ledger.value
            val remaining = BalanceCalculator.monthSummary(l.entries, l.recurring.filter { it.active }, today).remainingMinor
            Notifier.show(context, "mp.auto.$key", if (parsed.kind == EntryKind.INGRESO) "Ingreso registrado" else "Gasto registrado",
                "${signedAmount(parsed)} en ${parsed.merchant ?: parsed.bank} · ${if (remaining < 0) "te pasaste ${Money(-remaining).formatted()}" else "te quedan ${Money(remaining).formatted()}"}",
                Notifier.CHANNEL_REGISTRO)
        }
        return true
    }

    private fun signedAmount(c: ParsedCharge) = Money(if (c.kind == EntryKind.INGRESO) c.amountMinor else -c.amountMinor).formatted(sign = true)

    fun openListenerSettings(context: Context) {
        val intent = if (android.os.Build.VERSION.SDK_INT >= 30)
            Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(android.provider.Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, ComponentName(context, CaptureListener::class.java).flattenToString())
        else Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
        runCatching { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            .onFailure { context.startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
}

/** Lee las notificaciones de las apps de pagos de la lista. Nunca guarda el texto de otras apps. */
class CaptureListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName || sbn.packageName !in NotificationParser.packages) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()
        runCatching { AutoCapture.handle(this, "notificacion", sbn.packageName, title, text) }
    }
}

/** SMS del banco (opción de la versión de pruebas, con permiso). */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!AutoCapture.smsEnabled(context)) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val body = messages.joinToString("") { it.messageBody ?: "" }
        runCatching { AutoCapture.handle(context, "sms", "sms", null, body) }
    }
}
