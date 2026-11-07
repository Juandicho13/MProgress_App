package com.olarte.mprogress.domain

import java.time.Duration
import java.time.Instant

/** La pastilla de sincronización de Inicio (F10-04, pantalla 36), igual que SyncPill de iOS. Solo sale con cuenta. */
sealed class SyncPill {
    data object AlDia : SyncPill()
    data object Sincronizando : SyncPill()
    data class SinConexion(val pending: Int) : SyncPill()
    data object Error : SyncPill()

    /** "Al día", "Sincronizando…", "Sin conexión · 3 pendientes", "Error al sincronizar". */
    val text: String get() = when (this) {
        AlDia -> "Al día"
        Sincronizando -> "Sincronizando…"
        is SinConexion -> if (pending == 0) "Sin conexión" else "Sin conexión · $pending ${if (pending == 1) "pendiente" else "pendientes"}"
        Error -> "Error al sincronizar"
    }

    companion object {
        /** El estado a partir de lo que se sabe. Orden: sin conexión, sincronizando, error, pendientes por subir, al día. */
        fun state(signedIn: Boolean, online: Boolean, running: Boolean, pending: Int, failed: Int, hasError: Boolean): SyncPill? = when {
            !signedIn -> null
            !online -> SinConexion(pending.coerceAtLeast(0))
            running -> Sincronizando
            failed > 0 || hasError -> Error
            pending > 0 -> Sincronizando
            else -> AlDia
        }
    }
}

/** Textos de la hoja "Estado de sincronización" (F10-04, pantalla 37), iguales a SyncText de iOS. */
object SyncText {
    /** "Hace un momento", "Hace 2 min", "Hace 3 h", "Ayer", "Hace 4 días". Sin fecha: "Todavía no". */
    fun relative(date: Instant?, now: Instant): String {
        date ?: return "Todavía no"
        val minutes = Duration.between(date, now).seconds.coerceAtLeast(0) / 60
        if (minutes < 1) return "Hace un momento"
        if (minutes < 60) return "Hace $minutes min"
        val hours = minutes / 60
        if (hours < 24) return "Hace $hours h"
        val days = hours / 24
        return if (days == 1L) "Ayer" else "Hace $days días"
    }

    fun connection(online: Boolean) = if (online) "Conectado" else "Sin conexión"

    /** Orden en que se nombran los pendientes: primero lo que más se ve. */
    val DISPLAY_ORDER = listOf("entries", "recurring", "transfers", "products", "institutions", "budgets", "savings_goals",
        "goal_contributions", "reminders", "categories", "merchant_alias", "debts", "debt_payments", "reward_programs", "splits", "spaces")

    /** "movimiento" o "movimientos", "pago fijo" o "pagos fijos". */
    fun noun(table: String, count: Int): String {
        val one = count == 1
        return when (table) {
            "entries" -> if (one) "movimiento" else "movimientos"
            "recurring" -> if (one) "pago fijo" else "pagos fijos"
            "transfers" -> if (one) "transferencia" else "transferencias"
            "products" -> if (one) "cuenta o tarjeta" else "cuentas o tarjetas"
            "institutions" -> if (one) "banco" else "bancos"
            "budgets" -> if (one) "límite" else "límites"
            "savings_goals" -> if (one) "meta de ahorro" else "metas de ahorro"
            "goal_contributions" -> if (one) "aporte" else "aportes"
            "reminders" -> if (one) "aviso" else "avisos"
            "categories" -> if (one) "categoría" else "categorías"
            "merchant_alias" -> if (one) "nombre de comercio" else "nombres de comercios"
            "debts" -> if (one) "deuda" else "deudas"
            "debt_payments" -> if (one) "abono" else "abonos"
            "reward_programs" -> if (one) "programa de puntos" else "programas de puntos"
            "splits" -> if (one) "división" else "divisiones"
            "spaces" -> if (one) "ajuste de la cuenta" else "ajustes de la cuenta"
            else -> if (one) "cambio" else "cambios"
        }
    }

    /** "3 movimientos, 1 pago fijo". Sin nada: "Nada pendiente". */
    fun pendingSummary(counts: Map<String, Int>): String {
        val known = DISPLAY_ORDER.filter { (counts[it] ?: 0) > 0 }
        val others = counts.keys.filter { it !in DISPLAY_ORDER && (counts[it] ?: 0) > 0 }.sorted()
        val parts = (known + others).map { "${counts.getValue(it)} ${noun(it, counts.getValue(it))}" }
        return if (parts.isEmpty()) "Nada pendiente" else parts.joinToString(", ")
    }

    /** Los que no subieron después de 3 intentos, en palabras. */
    fun failedText(failed: Int): String? = when {
        failed <= 0 -> null
        failed == 1 -> "1 cambio no subió después de 3 intentos."
        else -> "$failed cambios no subieron después de 3 intentos."
    }

    const val GENERIC_ERROR = "No se pudo sincronizar. Tus cambios siguen guardados en este dispositivo."
    const val MISSING_KEY_ERROR = "Este dispositivo no tiene la llave de tu cuenta. Apruébalo desde tu otro dispositivo."
    const val OFFLINE_NOTE = "Todo queda guardado en este dispositivo y se sube solo cuando vuelva el internet."
}

/**
 * Espera antes de reintentar después de un error de la nube (no de conexión: sin internet se espera a que vuelva).
 * Crece y se queda en 5 minutos, así nunca gira en vacío. Igual que SyncBackoff de iOS.
 */
object SyncBackoff {
    val STEPS = listOf(5L, 15L, 30L, 60L, 120L, 300L)

    fun delaySeconds(failures: Int): Long = STEPS[failures.coerceIn(1, STEPS.size) - 1]
}
