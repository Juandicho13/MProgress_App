package com.olarte.mprogress.data.cloud

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper

/**
 * Si hay internet (F10-04), con ConnectivityManager.NetworkCallback (como NWPathMonitor en iOS). Avisa en el hilo principal cada
 * vez que cambia: sin conexión la pastilla lo dice y, al volver, se sincroniza de una vez.
 */
object Connectivity {
    fun watch(context: Context, onChange: (Boolean) -> Unit) {
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return
        val main = Handler(Looper.getMainLooper())
        main.post { onChange(isOnline(cm)) }
        cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { main.post { onChange(true) } }
            override fun onLost(network: Network) { main.post { onChange(isOnline(cm)) } }
        })
    }

    fun isOnline(cm: ConnectivityManager): Boolean {
        val network = cm.activeNetwork ?: return false
        return cm.getNetworkCapabilities(network)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
    }
}
