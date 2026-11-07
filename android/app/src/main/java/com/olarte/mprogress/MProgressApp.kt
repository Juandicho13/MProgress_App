package com.olarte.mprogress

import android.app.Application
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.notify.Notifier
import com.olarte.mprogress.ui.Permissions

/** Arranque: canales de avisos y reprogramación cada vez que cambian los datos. */
class MProgressApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val store = Store.get(this)
        Notifier.ensureChannels(this)
        AppHooks.extra += { ctx, _ -> com.olarte.mprogress.widgets.WidgetRefresher.refresh(ctx) }
        store.onChange = { ledger -> runCatching { Notifier.reschedule(this, store, ledger) }; AppHooks.onChange(this, store) }
        Permissions.shouldAsk = { !Notifier.permitted(this) && !store.prefs.getBoolean(Notifier.KEY_ASKED, false) }
        runCatching { Notifier.reschedule(this, store) }
        Thread { com.olarte.mprogress.data.BackupService.autoIfNeeded(this, store) }.start()
        startCloud(store)
    }

    /** Cuenta en la nube (F10): lee la sesión, sincroniza después de cada cambio y cuando vuelve el internet. */
    private fun startCloud(store: Store) {
        val cloud = runCatching { com.olarte.mprogress.data.cloud.CloudAccount.get(this) }.getOrNull() ?: return
        runCatching { cloud.start() }
        store.onLocalChange = { cloud.scheduleSync() }
        // Sin conexión la pastilla lo dice; al volver el internet se sincroniza de una vez (F10-04).
        runCatching { com.olarte.mprogress.data.cloud.Connectivity.watch(this) { online -> cloud.connectivityChanged(online) } }
    }
}

/** Ganchos que se agregan por fases (widgets). */
object AppHooks {
    var extra: MutableList<(android.content.Context, Store) -> Unit> = mutableListOf()
    fun onChange(context: android.content.Context, store: Store) = extra.forEach { runCatching { it(context, store) } }
}
