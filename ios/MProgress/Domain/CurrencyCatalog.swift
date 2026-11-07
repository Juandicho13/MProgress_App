import Foundation

/// Lista fija de las monedas activas de ISO 4217 (sin fondos, metales ni códigos de prueba),
/// para que el dominio no dependa de los datos del sistema. Los nombres y símbolos salen
/// del sistema en español de Colombia, con una tabla propia para las 30 más usadas.
/// Igual que `domain/CurrencyCatalog.kt` en Android.
enum CurrencyCatalog {
    static let isoCodes: [String] = """
    AED AFN ALL AMD AOA ARS AUD AWG AZN BAM BBD BDT BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD \
    CAD CDF CHF CLP CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS \
    GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW \
    KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR \
    MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR \
    SDG SEK SGD SHP SLE SOS SRD SSP STN SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX \
    USD UYU UZS VED VES VND VUV WST XAF XCD XCG XOF XPF YER ZAR ZMW ZWG
    """.split(separator: " ").map(String.init)

    /// Cifras decimales de ISO; las demás tienen 2.
    static let zeroDigits: Set<String> = ["BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF"]
    static let threeDigits: Set<String> = ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]

    static let popularCodes = ["COP", "USD", "EUR", "MXN", "CLP", "PEN", "ARS", "BRL", "GBP", "CAD"]

    /// Nombre y símbolo fijos de las 30 más usadas (no dependen del sistema).
    static let fallback: [String: (name: String, symbol: String)] = [
        "COP": ("Peso colombiano", "$"), "USD": ("Dólar estadounidense", "US$"), "EUR": ("Euro", "€"),
        "MXN": ("Peso mexicano", "MX$"), "CLP": ("Peso chileno", "$"), "PEN": ("Sol peruano", "S/"),
        "ARS": ("Peso argentino", "$"), "BRL": ("Real brasileño", "R$"), "GBP": ("Libra esterlina", "£"),
        "CAD": ("Dólar canadiense", "CA$"), "JPY": ("Yen japonés", "¥"), "CHF": ("Franco suizo", "CHF"),
        "CNY": ("Yuan chino", "CN¥"), "UYU": ("Peso uruguayo", "$U"), "PYG": ("Guaraní paraguayo", "₲"),
        "BOB": ("Boliviano", "Bs"), "VES": ("Bolívar venezolano", "Bs."), "CRC": ("Colón costarricense", "₡"),
        "DOP": ("Peso dominicano", "RD$"), "GTQ": ("Quetzal guatemalteco", "Q"), "HNL": ("Lempira hondureño", "L"),
        "NIO": ("Córdoba nicaragüense", "C$"), "PAB": ("Balboa panameño", "B/."), "CUP": ("Peso cubano", "$MN"),
        "AUD": ("Dólar australiano", "AU$"), "KRW": ("Won surcoreano", "₩"), "INR": ("Rupia india", "₹"),
        "KWD": ("Dinar kuwaití", "KD"), "SEK": ("Corona sueca", "kr"), "NOK": ("Corona noruega", "kr"),
    ]

    struct Table: Sendable {
        let byCode: [String: Currency]
        let sorted: [Currency]
    }

    /// Se arma una sola vez, la primera vez que se pide una moneda.
    static let shared: Table = {
        var map: [String: Currency] = [:]
        for code in isoCodes { map[code] = make(code) }
        for currency in Currency.legacy { map[currency.code] = currency }
        let list = map.values.sorted {
            let a = HistoryMath.normalize($0.name), b = HistoryMath.normalize($1.name)
            return a == b ? $0.code < $1.code : a < b
        }
        return Table(byCode: map, sorted: list)
    }()

    static func digits(_ code: String) -> Int {
        zeroDigits.contains(code) ? 0 : threeDigits.contains(code) ? 3 : 2
    }

    static func make(_ code: String) -> Currency {
        let digits = digits(code)
        if let fixed = fallback[code] {
            return Currency(code: code, symbol: fixed.symbol, name: fixed.name, minorDigits: digits, shownDigits: digits)
        }
        return Currency(code: code, symbol: systemSymbol(code) ?? code, name: systemName(code) ?? code, minorDigits: digits, shownDigits: digits)
    }

    static let locale = Locale(identifier: "es_CO")

    static func systemName(_ code: String) -> String? {
        guard let raw = locale.localizedString(forCurrencyCode: code), !raw.isEmpty, raw.uppercased() != code else { return nil }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func systemSymbol(_ code: String) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let symbol = formatter.currencySymbol.trimmingCharacters(in: .whitespaces)
        return symbol.isEmpty ? nil : symbol
    }

    /// Bandera del país (las dos primeras letras del código casi siempre son el país).
    /// El euro lleva la de la Unión Europea; las monedas regionales (XAF, XOF, XPF, XCD) no llevan.
    static func flag(for code: String) -> String? {
        let region: String
        switch code {
        case "EUR": region = "EU"
        case "XCG": region = "CW"
        default:
            guard code.count == 3, !code.hasPrefix("X") else { return nil }
            region = String(code.prefix(2))
        }
        var result = ""
        for scalar in region.unicodeScalars {
            guard let flagScalar = Unicode.Scalar(127_397 + scalar.value) else { return nil }
            result.unicodeScalars.append(flagScalar)
        }
        return result
    }
}
