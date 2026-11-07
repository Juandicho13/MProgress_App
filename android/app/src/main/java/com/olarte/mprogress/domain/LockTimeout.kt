package com.olarte.mprogress.domain

/** Cuánto puede estar la app en segundo plano antes de pedir la huella otra vez (como WhatsApp). Se guarda por dispositivo. */
enum class LockDelay(val seconds: Int, val title: String) {
    INMEDIATAMENTE(0, "Inmediatamente"),
    TREINTA_SEGUNDOS(30, "Después de 30 segundos"),
    UN_MINUTO(60, "Después de 1 minuto");

    companion object {
        const val STORAGE_KEY = "seguridad.bloquearTras"
        /** Lo guardado, o Inmediatamente si no hay nada (o un valor que no se conoce). */
        fun from(seconds: Int?) = entries.firstOrNull { it.seconds == seconds } ?: INMEDIATAMENTE
    }
}

object LockTimeout {
    /**
     * Decide si al volver se pide desbloquear. `backgroundedAt` y `now` son milisegundos de un reloj que solo avanza y sigue
     * contando con el teléfono dormido (SystemClock.elapsedRealtime). Sin hora de salida (arranque en frío) siempre se bloquea;
     * si el reloj retrocedió (el teléfono se reinició) también.
     */
    fun requiresAuth(backgroundedAt: Long?, now: Long, delay: LockDelay): Boolean {
        if (backgroundedAt == null) return true
        if (now < backgroundedAt) return true
        return now - backgroundedAt >= delay.seconds * 1000L
    }
}
