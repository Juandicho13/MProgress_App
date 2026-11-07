package com.olarte.mprogress.domain

import kotlin.math.abs

/** Moneda soportada. `minorDigits`: cifras de la unidad mínima; `shownDigits`: las que se ven. Igual que iOS. */
data class Currency(val code: String, val symbol: String, val name: String, val minorDigits: Int, val shownDigits: Int) {
    val minorPerUnit: Long get() = pow10(minorDigits)

    companion object {
        val COP = Currency("COP", "$", "Peso colombiano", 2, 0)
        val EUR = Currency("EUR", "€", "Euro", 2, 2)
        val USD = Currency("USD", "US$", "Dólar estadounidense", 2, 2)
        val MXN = Currency("MXN", "MX$", "Peso mexicano", 2, 2)
        val GBP = Currency("GBP", "£", "Libra esterlina", 2, 2)
        val ARS = Currency("ARS", "$", "Peso argentino", 2, 0)
        val CLP = Currency("CLP", "$", "Peso chileno", 0, 0)
        val PEN = Currency("PEN", "S/", "Sol peruano", 2, 2)
        val all = listOf(COP, EUR, USD, MXN, GBP, ARS, CLP, PEN)
        fun from(code: String) = all.firstOrNull { it.code == code.uppercase() } ?: COP
        /** Moneda del espacio elegida en Ajustes › Moneda. La pone el Store al abrir y al cambiarla. */
        @Volatile var current: Currency = COP
    }
}

internal fun pow10(n: Int): Long { var v = 1L; repeat(n) { v *= 10 }; return v }

/** Monto en enteros de la unidad mínima. Nunca Double (HANDOFF 7). */
data class Money(val minor: Long, val currency: Currency = Currency.current) : Comparable<Money> {
    operator fun plus(o: Money): Money { require(currency == o.currency); return Money(minor + o.minor, currency) }
    operator fun minus(o: Money): Money { require(currency == o.currency); return Money(minor - o.minor, currency) }
    operator fun unaryMinus() = Money(-minor, currency)
    override fun compareTo(other: Money) = minor.compareTo(other.minor)

    /** "$ 1.901.100", "€ 12,50", "− $ 84.300". `sign` agrega "+ " a los positivos. */
    fun formatted(sign: Boolean = false): String {
        val negative = minor < 0
        val absolute = abs(minor)
        val perUnit = currency.minorPerUnit
        var units = absolute / perUnit
        var fraction = absolute % perUnit
        val hidden = currency.minorDigits - currency.shownDigits
        if (hidden > 0) {
            val divisor = pow10(hidden)
            val rounded = (fraction + divisor / 2) / divisor
            if (rounded >= pow10(currency.shownDigits)) { units += 1; fraction = 0 } else fraction = rounded
        }
        var text = groupThousands(units)
        if (currency.shownDigits > 0) text += "," + fraction.toString().padStart(currency.shownDigits, '0')
        val body = "${currency.symbol} $text"
        return when {
            negative -> "− $body"
            sign && minor > 0 -> "+ $body"
            else -> body
        }
    }

    companion object {
        fun units(units: Long, currency: Currency = Currency.COP) = Money(units * currency.minorPerUnit, currency)
        fun groupThousands(value: Long): String {
            val digits = value.toString()
            val sb = StringBuilder()
            digits.forEachIndexed { i, c ->
                if (i > 0 && (digits.length - i) % 3 == 0) sb.append('.')
                sb.append(c)
            }
            return sb.toString()
        }
    }
}

/** Lo que se escribe en el teclado numérico de Agregar: dígitos y una coma decimal. */
data class AmountInput(val currency: Currency = Currency.current, val text: String = "") {
    val allowsDecimals get() = currency.shownDigits > 0

    fun press(key: Char): AmountInput {
        if (key == ',') {
            if (!allowsDecimals || text.contains(',')) return this
            return copy(text = if (text.isEmpty()) "0," else "$text,")
        }
        if (!key.isDigit()) return this
        val comma = text.indexOf(',')
        var base = text
        if (comma >= 0) {
            if (text.length - comma - 1 >= currency.shownDigits) return this
        } else {
            if (text.length >= 12) return this
            if (text == "0") base = ""
        }
        return copy(text = base + key)
    }

    fun deleteLast(): AmountInput {
        if (text.isEmpty()) return this
        val t = text.dropLast(1)
        return copy(text = if (t == "0") "" else t)
    }

    val money: Money get() {
        val parts = text.split(',')
        val units = parts.getOrNull(0)?.toLongOrNull() ?: 0
        var fraction = 0L
        if (parts.size > 1) fraction = parts[1].padEnd(currency.minorDigits, '0').take(currency.minorDigits).toLongOrNull() ?: 0
        return Money(units * currency.minorPerUnit + fraction, currency)
    }

    val display: String get() {
        if (text.isEmpty()) return "0"
        val parts = text.split(',')
        var r = Money.groupThousands(parts[0].toLongOrNull() ?: 0)
        if (parts.size > 1) r += "," + parts[1]
        return r
    }

    companion object {
        /** Arranca con un monto guardado, para editar. */
        fun fromMinor(minor: Long, currency: Currency): AmountInput {
            val v = maxOf(0, minor)
            val units = v / currency.minorPerUnit
            val fraction = v % currency.minorPerUnit
            var text = if (units == 0L && fraction == 0L) "" else units.toString()
            if (currency.shownDigits > 0 && fraction > 0) {
                val dec = fraction.toString().padStart(currency.minorDigits, '0').take(currency.shownDigits).trimEnd('0')
                if (dec.isNotEmpty()) text = "$units,$dec"
            }
            return AmountInput(currency, text)
        }
    }
}
