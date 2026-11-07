package com.olarte.mprogress.domain

/**
 * Primeros pasos de Inicio ("Saca todo el provecho a MProgress"): ocho pasos que se marcan solos con los datos
 * reales, para que cada función se descubra sin tener que buscarla. Funciones puras; la tarjeta solo lee esto.
 * Igual que Domain/Guide.swift de iOS.
 */
enum class GuideStepId { PRIMEROS_DATOS, BANCOS, AUTOMATICO, LIMITES, AHORRO, AVISOS, BLOQUEO, CUENTA }

/** Lo que hay en la app y en el teléfono, leído por la tarjeta cada vez que cambia algo. */
data class GuideSnapshot(
    /** Un ingreso fijo activo o un ingreso anotado. */
    val hasIncome: Boolean = false,
    /** Un gasto fijo activo. */
    val hasFixedExpense: Boolean = false,
    /** Un gasto anotado. */
    val hasExpense: Boolean = false,
    /** Un banco o billetera en Dinero. */
    val hasInstitution: Boolean = false,
    /** Lo mismo que Ajustes muestra en Registro automático (activo, o nada que configurar en la versión estándar). */
    val autoCaptureConfigured: Boolean = false,
    val hasBudget: Boolean = false,
    val hasGoal: Boolean = false,
    /** Permiso de notificaciones del sistema. */
    val notificationsAllowed: Boolean = false,
    /** Al menos un pago fijo que avisa (aviso general prendido o uno personalizado). */
    val hasReminder: Boolean = false,
    val lockEnabled: Boolean = false,
    val signedIn: Boolean = false,
)

enum class GuidePartKind { INGRESO, FIJO, GASTO }

/** Una de las tres partes del primer paso. */
data class GuidePart(val kind: GuidePartKind, val title: String, val done: Boolean)

/** `shortTitle` es cómo se nombra en la línea "Y 2 más: …". */
data class GuideStep(val id: GuideStepId, val title: String, val shortTitle: String, val done: Boolean)

enum class GuideVisibility { HIDDEN, CHECKLIST, CELEBRATION }

object Guide {
    /** En este dispositivo: la persona ocultó la tarjeta con la X. */
    const val DISMISSED_KEY = "guia.oculta"
    /** En este dispositivo: ya se vio "Listo, ya usas todo MProgress". */
    const val CELEBRATED_KEY = "guia.celebrada"
    /** En este dispositivo: la tarjeta está plegada. */
    const val COLLAPSED_KEY = "guia.plegada"
    /** En este dispositivo: el primer paso hecho se ve abierto con sus tres partes. */
    const val FIRST_STEP_OPEN_KEY = "guia.primerPasoAbierto"

    const val TITLE = "Saca todo el provecho a MProgress"
    const val CELEBRATION_TITLE = "Listo, ya usas todo MProgress"
    const val CELEBRATION_TEXT = "Ya tienes todo a la mano. Si algo cambia, lo encuentras en Ajustes."
    const val HIDE_QUESTION = "¿Ocultar los primeros pasos?"
    const val HIDE_MESSAGE = "Los encuentras en Ajustes"
    const val SETTINGS_TITLE = "Primeros pasos"
    const val SETTINGS_VALUE = "Mostrar en Inicio"
    /** Cuántos pasos pendientes se ven; el resto va en "Y 2 más: …". */
    const val VISIBLE_PENDING = 3
    /** Milisegundos que se ve la celebración antes de irse sola. */
    const val CELEBRATION_MILLIS = 4_000L

    fun parts(s: GuideSnapshot) = listOf(
        GuidePart(GuidePartKind.INGRESO, "Tu ingreso", s.hasIncome),
        GuidePart(GuidePartKind.FIJO, "Tus fijos", s.hasFixedExpense),
        GuidePart(GuidePartKind.GASTO, "Tu primer gasto", s.hasExpense),
    )

    /** La primera parte que falta del primer paso: a dónde lleva tocarlo. */
    fun nextPart(s: GuideSnapshot): GuidePartKind? = parts(s).firstOrNull { !it.done }?.kind

    /** Los ocho pasos, siempre en el mismo orden. */
    fun steps(s: GuideSnapshot): List<GuideStep> = GuideStepId.entries.map { id ->
        when (id) {
            GuideStepId.PRIMEROS_DATOS -> GuideStep(id, "Anota tu ingreso, tus fijos y tu primer gasto", "tus primeros movimientos",
                s.hasIncome && s.hasFixedExpense && s.hasExpense)
            GuideStepId.BANCOS -> GuideStep(id, "Agrega tus bancos y tarjetas", "bancos y tarjetas", s.hasInstitution)
            GuideStepId.AUTOMATICO -> GuideStep(id, "Activa el registro automático", "registro automático", s.autoCaptureConfigured)
            GuideStepId.LIMITES -> GuideStep(id, "Ponle un límite a una categoría", "límites", s.hasBudget)
            GuideStepId.AHORRO -> GuideStep(id, "Crea una meta de ahorro", "meta de ahorro", s.hasGoal)
            GuideStepId.AVISOS -> GuideStep(id, "Activa los avisos de tus cobros", "avisos", s.notificationsAllowed && s.hasReminder)
            GuideStepId.BLOQUEO -> GuideStep(id, "Protege la app con huella o rostro", "bloqueo", s.lockEnabled)
            GuideStepId.CUENTA -> GuideStep(id, "Crea tu cuenta para tener todo cifrado en la nube", "cuenta en la nube", s.signedIn)
        }
    }

    fun doneCount(steps: List<GuideStep>) = steps.count { it.done }

    /** "3 de 8" */
    fun progressText(steps: List<GuideStep>) = "${doneCount(steps)} de ${steps.size}"

    /** De 0 a 1, para la barra. */
    fun progress(steps: List<GuideStep>): Float = if (steps.isEmpty()) 0f else doneCount(steps).toFloat() / steps.size

    /** Los primeros pasos pendientes que se ven en la tarjeta (3). */
    fun visiblePendingSteps(steps: List<GuideStep>, limit: Int = VISIBLE_PENDING) = steps.filter { !it.done }.take(maxOf(0, limit))

    /** "Y 2 más: avisos y cuenta en la nube", o null si no queda nada escondido. */
    fun moreText(steps: List<GuideStep>, limit: Int = VISIBLE_PENDING): String? {
        val rest = steps.filter { !it.done }.drop(maxOf(0, limit)).map { it.shortTitle }
        if (rest.isEmpty()) return null
        return "Y ${rest.size} más: ${joined(rest)}"
    }

    /** Debajo del primer paso: lo que falta ("Te falta: tus fijos y tu primer gasto") o, hecho, las tres partes. */
    fun firstStepSubtitle(s: GuideSnapshot): String {
        val missing = parts(s).filter { !it.done }.map { it.title.lowercase() }
        return if (missing.isEmpty()) "Ingreso, fijos y primer gasto anotados" else "Te falta: ${joined(missing)}"
    }

    fun visibility(steps: List<GuideStep>, dismissed: Boolean, celebrated: Boolean): GuideVisibility = when {
        dismissed -> GuideVisibility.HIDDEN
        doneCount(steps) == steps.size -> if (celebrated) GuideVisibility.HIDDEN else GuideVisibility.CELEBRATION
        else -> GuideVisibility.CHECKLIST
    }

    /**
     * Hay al menos un pago fijo activo que avisa. `modes` trae el aviso de cada uno: "Como el general" avisa si
     * el general está prendido, "Personalizado" siempre y "Sin aviso" nunca.
     */
    fun hasReminder(modes: List<AlertMode>, generalEnabled: Boolean): Boolean = modes.any { mode ->
        when (mode) {
            AlertMode.GENERAL -> generalEnabled
            AlertMode.PERSONALIZADO -> true
            AlertMode.NINGUNO -> false
        }
    }

    /** "a", "a y b", "a, b y c". */
    fun joined(items: List<String>): String = when (items.size) {
        0 -> ""
        1 -> items[0]
        else -> items.dropLast(1).joinToString(", ") + " y " + items.last()
    }
}
