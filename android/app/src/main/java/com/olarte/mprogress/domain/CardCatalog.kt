package com.olarte.mprogress.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.Normalizer

/** Franquicia de una tarjeta. */
enum class CardFranchise(val title: String) {
    VISA("Visa"), MASTERCARD("Mastercard"), AMEX("American Express"), DINERS("Diners Club");

    companion object {
        fun from(raw: String?): CardFranchise? = entries.firstOrNull { it.name.equals(raw, ignoreCase = true) }
    }
}

/** Una tarjeta del catálogo (assets/card_catalog.json, igual a ios/MProgress/Resources/CardCatalog.json). */
data class CatalogCard(
    /** Estable: "bancolombia-visa-clasica". Se guarda en `Product.catalogCardId`. */
    val id: String,
    val name: String,
    val franchise: CardFranchise?,
    val tier: String?,
    val rewards: String?,
    /** Cuota de manejo mensual indicativa en pesos; null si no se sabe. */
    val handlingFeeCOP: Long?,
    val note: String?,
) {
    val handlingFeeMinor: Long? get() = handlingFeeCOP?.let { it * Currency.COP.minorPerUnit }
    /** "Visa · Puntos Colombia". */
    val subtitle: String get() = listOfNotNull(franchise?.title, rewards).joinToString(" · ")
}

data class CatalogBank(
    val id: String,
    val name: String,
    val aliases: List<String>,
    val source: String,
    val sources: List<String>,
    val checkedAt: String,
    /** False si no se pudo confirmar la lista completa en una fuente de 2026. */
    val verified: Boolean,
    val note: String?,
    val feeNote: String?,
    val cards: List<CatalogCard>,
)

data class CardCatalog(
    val version: Int,
    val checkedAt: String,
    /** Tope de usura del mes como fracción (0,2834). Solo para sugerir la tasa. */
    val usuraEA: BigDecimal,
    val usuraMonth: String,
    val usuraSource: String,
    val usuraNote: String,
    val note: String,
    val banks: List<CatalogBank>,
) {
    /** Tasa sugerida en porcentaje, como `Product.rateEA` (28.34). */
    val usuraRateEA: BigDecimal get() = usuraEA.multiply(BigDecimal(100)).setScale(4, RoundingMode.HALF_UP).stripTrailingZeros()

    /** Banco que corresponde a lo que escribió la persona, sin tildes, mayúsculas ni "Banco de", con alias. */
    fun bank(matching: String): CatalogBank? {
        val query = tokens(matching)
        if (query.isEmpty()) return null
        var best: Pair<Int, CatalogBank>? = null
        for (bank in banks) {
            for (alias in listOf(bank.name, bank.id) + bank.aliases) {
                val target = tokens(alias)
                if (target.isEmpty()) continue
                val score = when {
                    target == query -> 1000 + target.size
                    contains(query, target) -> 500 + target.joinToString("").length
                    contains(target, query) && query.joinToString("").length >= 3 -> 100 + query.joinToString("").length
                    else -> continue
                }
                if (best == null || score > best.first) best = score to bank
            }
        }
        return best?.second
    }

    fun cards(forBank: String): List<CatalogCard> = bank(forBank)?.cards ?: emptyList()

    fun card(id: String): Pair<CatalogBank, CatalogCard>? {
        for (b in banks) b.cards.firstOrNull { it.id == id }?.let { return b to it }
        return null
    }

    companion object {
        /** Ruta dentro de los assets de la app. */
        const val ASSET = "card_catalog.json"

        val ignoredWords = setOf("banco", "de", "del", "la", "el", "colombia", "sa", "s", "a", "bank")

        /** "Banco de Bogotá S.A." da ["bogota"]; "Banco" no da nada. */
        fun tokens(raw: String): List<String> {
            val folded = Normalizer.normalize(raw, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()
            val words = mutableListOf<String>()
            val current = StringBuilder()
            for (c in folded) {
                when {
                    c == '.' || c == '\'' -> {}
                    c.isLetterOrDigit() -> current.append(c)
                    current.isNotEmpty() -> { words.add(current.toString()); current.clear() }
                }
            }
            if (current.isNotEmpty()) words.add(current.toString())
            return words.filter { it !in ignoredWords }
        }

        fun contains(haystack: List<String>, needle: List<String>): Boolean {
            if (needle.isEmpty() || needle.size > haystack.size) return false
            for (start in 0..(haystack.size - needle.size)) if (haystack.subList(start, start + needle.size) == needle) return true
            return false
        }

        /** Lee el JSON del catálogo (sin org.json, así corre en pruebas JVM sin Android). */
        fun decode(text: String): CardCatalog {
            @Suppress("UNCHECKED_CAST")
            val root = MiniJson(text).parse() as Map<String, Any?>
            fun Map<String, Any?>.str(k: String) = this[k] as? String
            fun Map<String, Any?>.list(k: String) = (this[k] as? List<*>).orEmpty()
            val banks = root.list("banks").map { raw ->
                @Suppress("UNCHECKED_CAST") val b = raw as Map<String, Any?>
                CatalogBank(
                    id = b.str("id")!!, name = b.str("name")!!, aliases = b.list("aliases").map { it as String },
                    source = b.str("source")!!, sources = b.list("sources").map { it as String }, checkedAt = b.str("checkedAt")!!,
                    verified = b["verified"] as Boolean, note = b.str("note"), feeNote = b.str("feeNote"),
                    cards = b.list("cards").map { rc ->
                        @Suppress("UNCHECKED_CAST") val c = rc as Map<String, Any?>
                        CatalogCard(
                            id = c.str("id")!!, name = c.str("name")!!, franchise = CardFranchise.from(c.str("franchise")),
                            tier = c.str("tier"), rewards = c.str("rewards"), handlingFeeCOP = (c["handlingFeeCOP"] as? BigDecimal)?.longValueExact(),
                            note = c.str("note"),
                        )
                    },
                )
            }
            return CardCatalog(
                version = (root["version"] as BigDecimal).toInt(), checkedAt = root.str("checkedAt")!!,
                usuraEA = root["usuraEA"] as BigDecimal, usuraMonth = root.str("usuraMonth")!!, usuraSource = root.str("usuraSource")!!,
                usuraNote = root.str("usuraNote")!!, note = root.str("note")!!, banks = banks,
            )
        }
    }
}

/** Lector JSON mínimo: objetos a Map, listas a List, números a BigDecimal, true/false/null. */
internal class MiniJson(private val s: String) {
    private var i = 0

    fun parse(): Any? {
        val v = value()
        skip()
        require(i == s.length) { "JSON con texto de más en $i" }
        return v
    }

    private fun skip() { while (i < s.length && s[i].isWhitespace()) i++ }

    private fun value(): Any? {
        skip()
        require(i < s.length) { "JSON incompleto" }
        return when (val c = s[i]) {
            '{' -> obj()
            '[' -> arr()
            '"' -> str()
            't' -> word("true", true)
            'f' -> word("false", false)
            'n' -> word("null", null)
            else -> if (c == '-' || c.isDigit()) num() else error("JSON inválido en $i")
        }
    }

    private fun word(w: String, v: Any?): Any? {
        require(s.startsWith(w, i)) { "JSON inválido en $i" }
        i += w.length
        return v
    }

    private fun obj(): Map<String, Any?> {
        val m = LinkedHashMap<String, Any?>()
        i++
        skip()
        if (s[i] == '}') { i++; return m }
        while (true) {
            skip()
            val k = str()
            skip()
            require(s[i] == ':') { "Falta : en $i" }
            i++
            m[k] = value()
            skip()
            when (s[i]) {
                ',' -> i++
                '}' -> { i++; return m }
                else -> error("JSON inválido en $i")
            }
        }
    }

    private fun arr(): List<Any?> {
        val l = mutableListOf<Any?>()
        i++
        skip()
        if (s[i] == ']') { i++; return l }
        while (true) {
            l.add(value())
            skip()
            when (s[i]) {
                ',' -> i++
                ']' -> { i++; return l }
                else -> error("JSON inválido en $i")
            }
        }
    }

    private fun str(): String {
        require(s[i] == '"') { "Se esperaba texto en $i" }
        i++
        val sb = StringBuilder()
        while (true) {
            val c = s[i++]
            when (c) {
                '"' -> return sb.toString()
                '\\' -> {
                    when (val e = s[i++]) {
                        'n' -> sb.append('\n'); 't' -> sb.append('\t'); 'r' -> sb.append('\r')
                        'b' -> sb.append('\b'); 'f' -> sb.append('\u000C')
                        'u' -> { sb.append(s.substring(i, i + 4).toInt(16).toChar()); i += 4 }
                        else -> sb.append(e)
                    }
                }
                else -> sb.append(c)
            }
        }
    }

    private fun num(): BigDecimal {
        val start = i
        while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++
        return BigDecimal(s.substring(start, i))
    }
}
