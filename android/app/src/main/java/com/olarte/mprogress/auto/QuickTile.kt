package com.olarte.mprogress.auto

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.olarte.mprogress.MainActivity
import kotlinx.coroutines.flow.MutableStateFlow

/** Acción pedida desde fuera de la app (botón de ajustes rápidos, widget). La pantalla principal la abre y la limpia. */
object LaunchAction {
    const val EXTRA = "mp.accion"
    val pending = MutableStateFlow<String?>(null)
    fun from(intent: Intent?) {
        intent?.getStringExtra(EXTRA)?.let { pending.value = it }
        // Enlace mágico del correo: mprogress://auth-callback?code=... entra a la cuenta y abre Ajustes › Cuenta y nube.
        val data = intent?.dataString
        if (data != null && data.startsWith("mprogress://auth-callback")) {
            intent!!.data = null
            pending.value = "cuenta"
            authCallback.value = data
        }
    }
    /** El enlace del correo que falta procesar (lo toma la cuenta en la nube). */
    val authCallback = MutableStateFlow<String?>(null)
    fun intent(context: android.content.Context, action: String) =
        Intent(context, MainActivity::class.java).putExtra(EXTRA, action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
}

/** "Registro rápido" en los ajustes rápidos: abre la hoja corta de registro rápido encima de todo. */
class QuickAddTile : TileService() {
    override fun onStartListening() {
        qsTile?.apply { state = Tile.STATE_INACTIVE; label = "Registro rápido"; updateTile() }
    }

    override fun onClick() {
        val intent = LaunchAction.intent(this, "rapido")
        if (Build.VERSION.SDK_INT >= 34) startActivityAndCollapse(PendingIntent.getActivity(this, 7, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        else @Suppress("DEPRECATION") startActivityAndCollapse(intent)
    }
}
