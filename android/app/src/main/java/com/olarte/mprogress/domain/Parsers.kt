package com.olarte.mprogress.domain

/** Lo que se pudo leer de un SMS, una notificación o un recibo. */
data class ParsedCharge(val kind: EntryKind, val amountMinor: Long, val merchant: String?, val last4: String?, val bank: String?) {
    /** Sin comercio y sin últimos 4 no sabemos bien qué fue: queda para revisar. */
    val needsReview: Boolean get() = merchant == null || last4 == null
}

/** Lector de SMS y notificaciones de bancos colombianos, el mismo SmsParser de iOS. */
object SmsParser {
    val banks = listOf("Bancolombia", "Nequi", "Nu", "Davivienda", "Daviplata", "BBVA", "Banco de Bogota", "Banco de Bogotá",
        "Scotiabank", "Colpatria", "Itau", "Itaú", "Lulo", "Falabella", "Rappipay", "Banco Popular", "AV Villas")

    private val incomeWords = listOf("recibiste", "te consignaron", "consignacion", "consignación", "abono", "te enviaron", "transferencia recibida", "te llego", "te llegó", "deposito", "depósito")
    private val expenseWords = listOf("compra", "compraste", "pagaste", "pago", "retiro", "retiraste", "transferiste", "enviaste", "debito", "débito", "cargo")

    fun parse(text: String, currency: Currency = Currency.COP): ParsedCharge? {
        val clean = text.replace("\n", " ")
        val lower = clean.lowercase()
        val amount = amount(clean, currency) ?: return null
        if (amount <= 0) return null
        val isIncome = incomeWords.any { lower.contains(it) }
        val isExpense = expenseWords.any { lower.contains(it) }
        if (!isIncome && !isExpense) return null
        val kind = if (isIncome && !lower.contains("compra")) EntryKind.INGRESO else EntryKind.GASTO
        return ParsedCharge(kind, amount, merchant(clean), last4(clean), bank(clean))
    }

    fun amount(text: String, currency: Currency): Long? {
        val m = Regex("""(?:\$|COP|cop)\s?([0-9][0-9.,]*)""").find(text) ?: return null
        return parseNumber(m.groupValues[1].trim('.', ','), currency)
    }

    /** "84.300,00", "1,250.50" o "45.500" a unidades menores. */
    fun parseNumber(raw: String, currency: Currency): Long? {
        var units = raw
        var fraction = ""
        val sep = maxOf(raw.lastIndexOf(','), raw.lastIndexOf('.'))
        if (sep >= 0) {
            val tail = raw.substring(sep + 1)
            if (tail.length <= 2) { units = raw.substring(0, sep); fraction = tail }
        }
        val whole = units.filter(Char::isDigit).toLongOrNull() ?: return null
        var minor = whole * currency.minorPerUnit
        if (fraction.isNotEmpty() && currency.minorDigits > 0) minor += fraction.padEnd(currency.minorDigits, '0').take(currency.minorDigits).toLongOrNull() ?: 0
        return minor
    }

    fun merchant(text: String): String? {
        val r = Regex("""(?i)\s(?:en|a)\s+([A-Za-zÁÉÍÓÚÑáéíóúñ0-9&*' .\-]{2,40}?)(?=\s+(?:con|el|desde|por|hora|a las|fecha)\b|[,.;]|\s+\d{2}[/:-]|$)""")
        for (m in r.findAll(text)) {
            val c = m.groupValues[1].trim()
            val l = c.lowercase()
            if (l.startsWith("tu ") || l.startsWith("su ") || l.firstOrNull()?.isDigit() == true || l.startsWith("$")) continue
            return prettify(c)
        }
        return null
    }

    fun last4(text: String): String? =
        Regex("""(?i)(?:\*|termina(?:da)?\s+en\s+|terminacion\s+|terminación\s+|ultimos\s+(?:4\s+)?digitos\s+|últimos\s+(?:4\s+)?dígitos\s+)(\d{4})\b""").find(text)?.groupValues?.get(1)

    fun bank(text: String): String? {
        val lower = text.lowercase()
        return banks.sortedByDescending { it.length }.firstOrNull { name ->
            val key = name.lowercase()
            if (key == "nu") Regex("""\bnu\b""").containsMatchIn(lower) else lower.contains(key)
        }
    }

    fun prettify(name: String): String = name.split(" ").filter { it.isNotEmpty() }.joinToString(" ") { w ->
        if (w.length <= 2 && w.any(Char::isDigit)) w else w.take(1).uppercase() + w.drop(1).lowercase()
    }
}

/** Lector de recibos: busca el total entre las líneas leídas por la cámara. */
object ReceiptParser {
    private val totalWords = listOf("total a pagar", "valor total", "total")
    private val skipWords = listOf("subtotal", "sub total", "iva", "propina", "cambio", "efectivo recibido", "base")

    fun total(lines: List<String>, currency: Currency = Currency.COP): Long? {
        val candidates = mutableListOf<Long>()
        lines.forEachIndexed { i, line ->
            val lower = line.lowercase()
            if (totalWords.none { lower.contains(it) } || skipWords.any { lower.contains(it) }) return@forEachIndexed
            val v = number(line, currency) ?: lines.getOrNull(i + 1)?.let { number(it, currency) }
            if (v != null) candidates += v
        }
        return candidates.maxOrNull() ?: lines.mapNotNull { number(it, currency) }.maxOrNull()
    }

    fun merchant(lines: List<String>): String? = lines.firstOrNull { line ->
        val lower = line.lowercase()
        line.count(Char::isLetter) >= 3 && listOf("nit", "factura", "calle", "cra", "carrera", "tel", "fecha", "www", "regimen", "régimen").none { lower.contains(it) }
    }?.let { SmsParser.prettify(it.trim()) }

    private fun number(line: String, currency: Currency): Long? =
        Regex("""\$?\s?([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)""").findAll(line)
            .mapNotNull { SmsParser.parseNumber(it.groupValues[1], currency) }.maxOrNull()
}

/** Registro automático por notificaciones (Paso 3, Android): Google Wallet y apps de bancos y billeteras. */
object NotificationParser {
    /** Paquetes de apps que avisan pagos. Las demás notificaciones no se leen. */
    val packages = mapOf(
        "com.google.android.apps.walletnfcrel" to "Google Wallet",
        "com.todo1.mobile" to "Bancolombia", "com.bancolombia.mibancolombia" to "Bancolombia",
        "com.nequi.MobileApp" to "Nequi", "com.davivienda.daviviendaapp" to "Davivienda", "com.davivienda.daviplataapp" to "Daviplata",
        "com.nu.production" to "Nu", "co.com.bbva.mb" to "BBVA", "com.bancodebogota.bancamovil" to "Banco de Bogotá",
        "com.lulobank.app" to "Lulo", "com.rappi.pay" to "Rappipay", "co.com.falabella.bancofalabella" to "Falabella",
        "com.scotiabank.colpatria.movil" to "Colpatria", "com.itau.co" to "Itaú", "com.avvillas.mobile" to "AV Villas",
        "com.google.android.apps.messaging" to "Mensajes", "com.samsung.android.messaging" to "Mensajes",
    )

    /**
     * Wallet avisa "Éxito" con el texto "$ 84.300,00 con Visa •••• 4417": el título es el comercio y no trae la palabra compra.
     * Los bancos y los SMS usan SmsParser.
     */
    fun parse(packageName: String, title: String?, text: String?, currency: Currency = Currency.COP): ParsedCharge? {
        val body = listOfNotNull(title, text).joinToString(" · ")
        if (packageName == "com.google.android.apps.walletnfcrel") {
            val amount = SmsParser.amount(text ?: return null, currency) ?: return null
            val last4 = Regex("""(?:•+|\*+|\.{2,})\s?(\d{4})""").find(text)?.groupValues?.get(1) ?: SmsParser.last4(text)
            val merchant = title?.trim()?.takeIf { it.isNotEmpty() && !it.contains("$") }?.let(SmsParser::prettify)
            return ParsedCharge(EntryKind.GASTO, amount, merchant, last4, SmsParser.bank(text))
        }
        val parsed = SmsParser.parse(body, currency) ?: return null
        return if (parsed.bank == null) parsed.copy(bank = packages[packageName]?.takeIf { it != "Mensajes" }) else parsed
    }

    /** Llave para no anotar dos veces el mismo pago (llega por SMS y por notificación). */
    fun dedupKey(c: ParsedCharge, day: java.time.LocalDate) = "${day}|${c.kind}|${c.amountMinor}|${c.last4 ?: ""}"
}
