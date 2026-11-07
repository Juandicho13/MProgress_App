package com.olarte.mprogress.domain

import java.util.Locale

/**
 * Lista fija de las monedas activas de ISO 4217 (sin fondos, metales ni códigos de prueba), para que el
 * dominio no dependa de los datos del sistema. Nombres y símbolos salen del sistema en español de Colombia,
 * con una tabla propia para las 30 más usadas. Igual que `Domain/CurrencyCatalog.swift` en iOS.
 */
object CurrencyCatalog {
    val ISO_CODES: List<String> = ("AED AFN ALL AMD AOA ARS AUD AWG AZN BAM BBD BDT BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD " +
        "CAD CDF CHF CLP CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS " +
        "GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW " +
        "KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR " +
        "MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR " +
        "SDG SEK SGD SHP SLE SOS SRD SSP STN SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX " +
        "USD UYU UZS VED VES VND VUV WST XAF XCD XCG XOF XPF YER ZAR ZMW ZWG").split(' ')

    /** Cifras decimales de ISO; las demás tienen 2. */
    val ZERO_DIGITS = setOf("BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF")
    val THREE_DIGITS = setOf("BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND")

    val POPULAR = listOf("COP", "USD", "EUR", "MXN", "CLP", "PEN", "ARS", "BRL", "GBP", "CAD")

    /** Nombre y símbolo fijos de las 30 más usadas (no dependen del sistema). */
    val FALLBACK: Map<String, Pair<String, String>> = mapOf(
        "COP" to ("Peso colombiano" to "$"), "USD" to ("Dólar estadounidense" to "US$"), "EUR" to ("Euro" to "€"),
        "MXN" to ("Peso mexicano" to "MX$"), "CLP" to ("Peso chileno" to "$"), "PEN" to ("Sol peruano" to "S/"),
        "ARS" to ("Peso argentino" to "$"), "BRL" to ("Real brasileño" to "R$"), "GBP" to ("Libra esterlina" to "£"),
        "CAD" to ("Dólar canadiense" to "CA$"), "JPY" to ("Yen japonés" to "¥"), "CHF" to ("Franco suizo" to "CHF"),
        "CNY" to ("Yuan chino" to "CN¥"), "UYU" to ("Peso uruguayo" to "\$U"), "PYG" to ("Guaraní paraguayo" to "₲"),
        "BOB" to ("Boliviano" to "Bs"), "VES" to ("Bolívar venezolano" to "Bs."), "CRC" to ("Colón costarricense" to "₡"),
        "DOP" to ("Peso dominicano" to "RD$"), "GTQ" to ("Quetzal guatemalteco" to "Q"), "HNL" to ("Lempira hondureño" to "L"),
        "NIO" to ("Córdoba nicaragüense" to "C$"), "PAB" to ("Balboa panameño" to "B/."), "CUP" to ("Peso cubano" to "\$MN"),
        "AUD" to ("Dólar australiano" to "AU$"), "KRW" to ("Won surcoreano" to "₩"), "INR" to ("Rupia india" to "₹"),
        "KWD" to ("Dinar kuwaití" to "KD"), "SEK" to ("Corona sueca" to "kr"), "NOK" to ("Corona noruega" to "kr"),
    )

    private val LOCALE = Locale("es", "CO")

    /** Se arma una sola vez, la primera vez que se pide una moneda. */
    val byCode: Map<String, Currency> by lazy {
        val m = LinkedHashMap<String, Currency>()
        ISO_CODES.forEach { m[it] = make(it) }
        Currency.legacy.forEach { m[it.code] = it }
        m
    }

    val sorted: List<Currency> by lazy {
        byCode.values.sortedWith(compareBy<Currency> { HistoryMath.normalize(it.name) }.thenBy { it.code })
    }

    fun digits(code: String) = when (code) { in ZERO_DIGITS -> 0; in THREE_DIGITS -> 3; else -> 2 }

    fun make(code: String): Currency {
        val d = digits(code)
        FALLBACK[code]?.let { (name, symbol) -> return Currency(code, symbol, name, d, d) }
        return Currency(code, systemSymbol(code) ?: code, systemName(code) ?: code, d, d)
    }

    private fun system(code: String): java.util.Currency? = runCatching { java.util.Currency.getInstance(code) }.getOrNull()

    fun systemName(code: String): String? {
        val raw = system(code)?.getDisplayName(LOCALE)?.takeIf { it.isNotBlank() && it.uppercase() != code } ?: return null
        return raw.replaceFirstChar { it.titlecase(LOCALE) }
    }

    fun systemSymbol(code: String): String? = system(code)?.getSymbol(LOCALE)?.trim()?.takeIf { it.isNotEmpty() }

    /** Bandera del país (las dos primeras letras del código casi siempre son el país). El euro lleva la de la UE; XAF, XOF, XPF y XCD no llevan. */
    fun flag(code: String): String? {
        val region = when {
            code == "EUR" -> "EU"
            code == "XCG" -> "CW"
            code.length != 3 || code.startsWith("X") -> return null
            else -> code.take(2)
        }
        return region.map { String(Character.toChars(0x1F1E6 + (it - 'A'))) }.joinToString("")
    }
}
