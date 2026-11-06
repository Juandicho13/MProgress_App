import Foundation

/// De dónde vino un movimiento (Entry.sourceRaw).
enum EntrySource: String, Codable, Sendable, CaseIterable {
    case manual, applePay, sms, recibo

    var title: String {
        switch self {
        case .manual: "Manual"
        case .applePay: "Apple Pay"
        case .sms: "SMS"
        case .recibo: "Recibo"
        }
    }
}

/// Lo que se pudo leer de un SMS o de un pago con Apple Pay.
struct ParsedCharge: Equatable, Sendable {
    var kind: EntryKind
    var amountMinor: Int64
    var merchant: String?
    var last4: String?
    /// Banco que se nombra en el mensaje, si alguno.
    var bank: String?
    /// Sin comercio y sin últimos 4 no sabemos bien qué fue: queda para revisar.
    var needsReview: Bool { merchant == nil || last4 == nil }
}

/// Lector de SMS de bancos colombianos (F08-03). Funciona con reglas generales, no con plantillas
/// fijas: monto con "$" o "COP", comercio después de "en" o "a", últimos 4 después de "*" o "terminada en".
/// Las pruebas usan ejemplos con la forma de los SMS reales; el ticket se cierra con SMS reales de Juan.
enum SmsParser {
    static let banks = ["Bancolombia", "Nequi", "Nu", "Davivienda", "Daviplata", "BBVA", "Banco de Bogota", "Banco de Bogotá",
                        "Scotiabank", "Colpatria", "Itau", "Itaú", "Lulo", "Falabella", "Rappipay", "Banco Popular", "AV Villas"]

    private static let incomeWords = ["recibiste", "te consignaron", "consignacion", "consignación", "abono", "te enviaron", "transferencia recibida", "te llego", "te llegó", "deposito", "depósito"]
    private static let expenseWords = ["compra", "compraste", "pagaste", "pago", "retiro", "retiraste", "transferiste", "enviaste", "debito", "débito", "cargo"]

    static func parse(_ text: String, currency: Currency = .cop) -> ParsedCharge? {
        let clean = text.replacingOccurrences(of: "\n", with: " ")
        let lower = clean.lowercased()
        guard let amount = amount(in: clean, currency: currency), amount > 0 else { return nil }

        let isIncome = incomeWords.contains { lower.contains($0) }
        let isExpense = expenseWords.contains { lower.contains($0) }
        guard isIncome || isExpense else { return nil }
        let kind: EntryKind = isIncome && !lower.contains("compra") ? .ingreso : .gasto

        return ParsedCharge(kind: kind, amountMinor: amount, merchant: merchant(in: clean, kind: kind),
                            last4: last4(in: clean), bank: bank(in: clean))
    }

    /// "$84.300,00", "$ 45.500", "COP 1.234.567", "$1,250.50" (formato inglés si la coma va antes del punto).
    static func amount(in text: String, currency: Currency) -> Int64? {
        let pattern = #"(?:\$|COP|cop)\s?([0-9][0-9.,]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return parseNumber(String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,")), currency: currency)
    }

    /// Convierte "84.300,00" o "1,250.50" o "45.500" a unidades menores.
    static func parseNumber(_ raw: String, currency: Currency) -> Int64? {
        var units = raw
        var fraction = ""
        let lastComma = raw.lastIndex(of: ",")
        let lastDot = raw.lastIndex(of: ".")
        // El último separador es decimal si le siguen 1 o 2 dígitos; si le siguen 3 es de miles.
        if let separator = [lastComma, lastDot].compactMap({ $0 }).max() {
            let tail = raw[raw.index(after: separator)...]
            if tail.count <= 2 {
                units = String(raw[..<separator])
                fraction = String(tail)
            }
        }
        let digits = units.filter(\.isNumber)
        guard let whole = Int64(digits) else { return nil }
        var minor = whole * currency.minorPerUnit
        if !fraction.isEmpty, currency.minorDigits > 0 {
            var padded = fraction
            while padded.count < currency.minorDigits { padded += "0" }
            minor += Int64(padded.prefix(currency.minorDigits)) ?? 0
        }
        return minor
    }

    /// Comercio: después de " en " (compras) o " a " (pagos y envíos), hasta "con", "el", "desde", coma o punto.
    static func merchant(in text: String, kind: EntryKind) -> String? {
        let pattern = #"(?i)\s(?:en|a)\s+([A-Za-zÁÉÍÓÚÑáéíóúñ0-9&*' .\-]{2,40}?)(?=\s+(?:con|el|desde|por|hora|a las|fecha)\b|[,.;]|\s+\d{2}[/:-]|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let candidate = text[range].trimmingCharacters(in: .whitespaces)
            let lower = candidate.lowercased()
            // Descarta "tu cuenta", "tu tarjeta", "su cuenta" y montos.
            if lower.hasPrefix("tu ") || lower.hasPrefix("su ") || lower.first?.isNumber == true || lower.hasPrefix("$") { continue }
            return prettify(candidate)
        }
        return nil
    }

    /// "*4417", "terminada en 2210", "termina en 1032", "T.Cred *4417", "ultimos digitos 8831".
    static func last4(in text: String) -> String? {
        let pattern = #"(?i)(?:\*|termina(?:da)?\s+en\s+|terminacion\s+|terminación\s+|ultimos\s+(?:4\s+)?digitos\s+|últimos\s+(?:4\s+)?dígitos\s+)(\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    static func bank(in text: String) -> String? {
        let lower = text.lowercased()
        return banks.sorted { $0.count > $1.count }.first { name in
            let key = name.lowercased()
            // "Nu" solo cuenta como palabra suelta.
            if key == "nu" { return lower.range(of: #"\bnu\b"#, options: .regularExpression) != nil }
            return lower.contains(key)
        }
    }

    /// "EXITO CALLE 80" pasa a "Exito Calle 80"; deja como están los nombres cortos con números ("D1").
    static func prettify(_ name: String) -> String {
        name.split(separator: " ").map { word in
            word.count <= 2 && word.contains(where: \.isNumber) ? String(word) : word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}

/// Lector de recibos (F08-05): busca el total entre las líneas que reconoció la cámara.
enum ReceiptParser {
    private static let totalWords = ["total a pagar", "valor total", "total"]
    private static let skipWords = ["subtotal", "sub total", "iva", "propina", "cambio", "efectivo recibido", "base"]

    /// Total del recibo: la línea con "total" (sin subtotal ni IVA) y su monto; si no hay, el monto más grande.
    static func total(lines: [String], currency: Currency = .cop) -> Int64? {
        var candidates: [Int64] = []
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard totalWords.contains(where: { lower.contains($0) }), !skipWords.contains(where: { lower.contains($0) }) else { continue }
            if let value = number(in: line, currency: currency) {
                candidates.append(value)
            } else if index + 1 < lines.count, let next = number(in: lines[index + 1], currency: currency) {
                candidates.append(next)
            }
        }
        if let best = candidates.max() { return best }
        return lines.compactMap { number(in: $0, currency: currency) }.max()
    }

    /// Nombre del comercio: la primera línea con letras que no sea NIT, dirección ni fecha.
    static func merchant(lines: [String]) -> String? {
        lines.first { line in
            let lower = line.lowercased()
            let letters = line.filter(\.isLetter).count
            return letters >= 3 && !["nit", "factura", "calle", "cra", "carrera", "tel", "fecha", "www", "regimen", "régimen"].contains { lower.contains($0) }
        }
        .map { SmsParser.prettify($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func number(in line: String, currency: Currency) -> Int64? {
        let pattern = #"\$?\s?([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let values = regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { match -> Int64? in
            guard let range = Range(match.range(at: 1), in: line) else { return nil }
            return SmsParser.parseNumber(String(line[range]), currency: currency)
        }
        return values.max()
    }
}
