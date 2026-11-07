package com.olarte.mprogress.domain

import java.text.Normalizer
import java.util.UUID

/** Regla aprendida de un comercio: el texto del banco ("PEPEPOLLO SAS 123") con el nombre y la categoría que le puso la persona. */
data class MerchantAliasRule(
    val id: String = UUID.randomUUID().toString(),
    /** Comercio normalizado (`MerchantAliasMath.normalize`), por ejemplo "PEPEPOLLO". */
    val key: String,
    val name: String,
    val categoryId: String? = null,
)

/**
 * Nombres de comercios, igual que MerchantAliasMath de iOS: normalizar lo que manda el banco, aprender del nombre que le da la
 * persona y buscar la regla cuando llega otro pago del mismo comercio.
 */
object MerchantAliasMath {
    /** Palabras que no dicen qué comercio es: tipo de sociedad, país y ciudades. */
    val noise = setOf(
        "SAS", "SA", "LTDA", "LTD", "CO", "COL", "COLOMBIA", "CIA", "INC", "LLC", "EU", "SUC", "SUCURSAL",
        "BOGOTA", "BOG", "DC", "MEDELLIN", "MED", "CALI", "BARRANQUILLA", "BQUILLA", "CARTAGENA", "BUCARAMANGA",
        "PEREIRA", "MANIZALES", "CHIA", "ENVIGADO", "SOACHA",
    )

    /**
     * "Pepepollo S.A.S. 123" pasa a "PEPEPOLLO": mayúsculas, sin tildes, sin números ni signos, sin SAS, LTDA, CO, BOGOTA y
     * parecidos, y con un solo espacio entre palabras. Si todo es ruido, se dejan las palabras para no quedar vacío.
     */
    fun normalize(raw: String): String {
        val folded = Normalizer.normalize(raw, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").uppercase()
        val cleaned = StringBuilder()
        for (c in folded) {
            when {
                // "S.A.S" es "SAS" y "MC'DONALDS" es "MCDONALDS".
                c == '.' || c == '\'' || c == '’' -> {}
                c in 'A'..'Z' -> cleaned.append(c)
                else -> cleaned.append(' ')
            }
        }
        val words = cleaned.split(' ').filter { it.isNotEmpty() }
        val meaningful = words.filter { it !in noise }
        return (meaningful.ifEmpty { words }).joinToString(" ")
    }

    /** La regla de un comercio: la de la misma clave o, si no hay, la más larga con la que empieza ("EXITO" sirve para "EXITO CALLE"). */
    fun match(raw: String?, rules: List<MerchantAliasRule>): MerchantAliasRule? {
        if (raw == null) return null
        val key = normalize(raw)
        if (key.isEmpty()) return null
        rules.firstOrNull { it.key == key }?.let { return it }
        return rules.filter { it.key.isNotEmpty() && key.startsWith(it.key + " ") }.maxByOrNull { it.key.length }
    }

    /**
     * Qué aprender al guardar un movimiento que llegó solo (SMS, notificación o recibo): el nombre que le dio la persona, si es
     * otro, y la categoría, si eligió una. Null si no hay nada que aprender.
     */
    fun learn(raw: String?, automatic: Boolean, name: String, categoryId: String?): MerchantAliasRule? {
        if (!automatic || raw == null) return null
        val key = normalize(raw)
        val clean = name.trim()
        if (key.isEmpty() || clean.isEmpty()) return null
        val renamed = normalize(clean) != key
        if (!renamed && categoryId == null) return null
        return MerchantAliasRule(key = key, name = clean, categoryId = categoryId)
    }

    /** Nombre y categoría para un pago que llega: los de la regla o, si no hay, el comercio tal como llegó. */
    fun prefill(raw: String?, rules: List<MerchantAliasRule>): Pair<String?, String?> =
        match(raw, rules)?.let { it.name to it.categoryId } ?: (raw to null)

    /** Lo que llegó solo: SMS, notificación (Wallet y bancos) o recibo. */
    fun isAutomatic(source: String) = source != "manual"
}
