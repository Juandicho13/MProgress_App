package com.olarte.mprogress.notify

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.olarte.mprogress.MainActivity
import com.olarte.mprogress.R
import com.olarte.mprogress.data.Ledger
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.domain.ReminderPlanner
import java.time.LocalDateTime
import java.time.ZoneId

/** Avisos locales: pagos fijos, tarjetas y límites. Igual que NotificationScheduler de iOS, con AlarmManager. */
object Notifier {
    const val CHANNEL_PAGOS = "pagos"
    const val CHANNEL_LIMITES = "limites"
    const val CHANNEL_REGISTRO = "registro"
    private const val KEY_IDS = "avisos.programados"
    const val KEY_ASKED = "avisos.preguntado"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL_PAGOS, "Pagos fijos y tarjetas", NotificationManager.IMPORTANCE_DEFAULT))
        nm.createNotificationChannel(NotificationChannel(CHANNEL_LIMITES, "Límites", NotificationManager.IMPORTANCE_DEFAULT))
        nm.createNotificationChannel(NotificationChannel(CHANNEL_REGISTRO, "Registro automático", NotificationManager.IMPORTANCE_LOW))
    }

    fun permitted(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** Reprograma todo: cancela lo anterior y pone lo que sale de ReminderPlanner. */
    fun reschedule(context: Context, store: Store, ledger: Ledger = store.ledger.value) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val prefs = store.prefs
        prefs.getStringSet(KEY_IDS, emptySet())!!.forEach { id -> am.cancel(pending(context, id, "", "")) }
        val cards = ledger.products.filter { it.kind == ProductKind.CREDITO && it.dueDay != null }.map { Triple(it.id, it.name, it.dueDay!!) }
        val plan = ReminderPlanner.plan(ledger.recurring, store.alerts.value, store.currency.value, LocalDateTime.now(), cards = cards)
        plan.forEach { n ->
            val at = n.fireAt.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, n.id, n.title, n.body))
        }
        prefs.edit().putStringSet(KEY_IDS, plan.map { it.id }.toSet()).apply()
    }

    private fun pending(context: Context, id: String, title: String, body: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).setAction("mp.aviso.$id").putExtra("id", id).putExtra("title", title).putExtra("body", body)
        return PendingIntent.getBroadcast(context, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** Muestra un aviso ya mismo (límites, "Terminaste de pagar", registro automático). */
    fun show(context: Context, id: String, title: String, body: String, channel: String = CHANNEL_PAGOS, action: String? = null) {
        if (!permitted(context)) return
        ensureChannels(context)
        val target = action?.let { com.olarte.mprogress.auto.LaunchAction.intent(context, it) } ?: Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = PendingIntent.getActivity(context, id.hashCode(), target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(context, channel).setSmallIcon(R.drawable.ic_notificacion).setContentTitle(title).setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true).build()
        try { NotificationManagerCompat.from(context).notify(id.hashCode(), n) } catch (_: SecurityException) {}
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Notifier.show(context, intent.getStringExtra("id") ?: return, intent.getStringExtra("title").orEmpty(), intent.getStringExtra("body").orEmpty())
    }
}

/** Al reiniciar el teléfono las alarmas se pierden: se vuelven a poner. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Notifier.reschedule(context, Store.get(context))
    }
}
