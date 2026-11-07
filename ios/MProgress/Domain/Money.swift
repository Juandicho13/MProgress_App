import Foundation

/// Moneda (ISO 4217). `minorDigits` es cuántas cifras tiene la unidad mínima
/// (centavos) y `shownDigits` cuántas se muestran en pantalla. Dos monedas son
/// iguales si tienen el mismo código: el nombre y el símbolo son solo para mostrar.
struct Currency: Hashable, Codable, Sendable {
    let code: String
    let symbol: String
    let name: String
    let minorDigits: Int
    let shownDigits: Int

    init(code: String, symbol: String, name: String, minorDigits: Int, shownDigits: Int) {
        self.code = code
        self.symbol = symbol
        self.name = name
        self.minorDigits = minorDigits
        self.shownDigits = shownDigits
    }

    // Las de siempre: no cambian (los montos guardados dependen de `minorDigits`).
    static let cop = Currency(code: "COP", symbol: "$", name: "Peso colombiano", minorDigits: 2, shownDigits: 0)
    static let eur = Currency(code: "EUR", symbol: "€", name: "Euro", minorDigits: 2, shownDigits: 2)
    static let usd = Currency(code: "USD", symbol: "US$", name: "Dólar estadounidense", minorDigits: 2, shownDigits: 2)
    static let mxn = Currency(code: "MXN", symbol: "MX$", name: "Peso mexicano", minorDigits: 2, shownDigits: 2)
    static let gbp = Currency(code: "GBP", symbol: "£", name: "Libra esterlina", minorDigits: 2, shownDigits: 2)
    static let ars = Currency(code: "ARS", symbol: "$", name: "Peso argentino", minorDigits: 2, shownDigits: 0)
    static let clp = Currency(code: "CLP", symbol: "$", name: "Peso chileno", minorDigits: 0, shownDigits: 0)
    static let pen = Currency(code: "PEN", symbol: "S/", name: "Sol peruano", minorDigits: 2, shownDigits: 2)

    static let legacy: [Currency] = [.cop, .eur, .usd, .mxn, .gbp, .ars, .clp, .pen]

    /// Todas las monedas activas, de la A a la Z por nombre.
    static var all: [Currency] { CurrencyCatalog.shared.sorted }

    /// Las que más se usan, para arriba del selector.
    static var popular: [Currency] { CurrencyCatalog.popularCodes.compactMap { CurrencyCatalog.shared.byCode[$0] } }

    /// Un código desconocido cae en COP, como antes.
    static func from(code: String) -> Currency {
        known(code: code) ?? .cop
    }

    static func known(code: String) -> Currency? {
        CurrencyCatalog.shared.byCode[code.trimmingCharacters(in: .whitespaces).uppercased()]
    }

    /// Busca por código o nombre, sin tildes ni mayúsculas. Vacío devuelve todas.
    static func search(_ query: String) -> [Currency] {
        let words = HistoryMath.normalize(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return all }
        let hits = all.filter { currency in
            let haystack = HistoryMath.normalize("\(currency.code) \(currency.name)")
            return words.allSatisfy { haystack.contains($0) }
        }
        // El código exacto va primero ("usd" muestra el dólar arriba).
        let key = words.joined().uppercased()
        return hits.filter { $0.code == key } + hits.filter { $0.code != key }
    }

    /// Bandera del país de la moneda, si tiene uno claro.
    var flag: String? { CurrencyCatalog.flag(for: code) }

    /// Unidades mínimas que hay en una unidad (100 para centavos, 1 para CLP).
    var minorPerUnit: Int64 {
        var value: Int64 = 1
        for _ in 0..<minorDigits { value *= 10 }
        return value
    }

    static func == (lhs: Currency, rhs: Currency) -> Bool { lhs.code == rhs.code }
    func hash(into hasher: inout Hasher) { hasher.combine(code) }

    private enum CodingKeys: String, CodingKey { case code, symbol, name, minorDigits, shownDigits }

    /// Lo guardado manda por el código: si es conocida se usa la del catálogo.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let code = try c.decode(String.self, forKey: .code)
        if let known = Currency.known(code: code) { self = known; return }
        let digits = try c.decodeIfPresent(Int.self, forKey: .minorDigits) ?? 2
        self.init(code: code.uppercased(),
                  symbol: try c.decodeIfPresent(String.self, forKey: .symbol) ?? code.uppercased(),
                  name: try c.decodeIfPresent(String.self, forKey: .name) ?? code.uppercased(),
                  minorDigits: digits,
                  shownDigits: try c.decodeIfPresent(Int.self, forKey: .shownDigits) ?? digits)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(symbol, forKey: .symbol)
        try c.encode(name, forKey: .name)
        try c.encode(minorDigits, forKey: .minorDigits)
        try c.encode(shownDigits, forKey: .shownDigits)
    }
}

/// Monto en enteros de la unidad mínima. Nunca Double (HANDOFF 7).
struct Money: Hashable, Codable, Sendable, Comparable {
    var minor: Int64
    var currency: Currency

    init(minor: Int64, currency: Currency = .cop) {
        self.minor = minor
        self.currency = currency
    }

    /// Crea un monto desde unidades enteras: `Money(units: 45_500)` son $ 45.500.
    init(units: Int64, currency: Currency = .cop) {
        self.init(minor: units * currency.minorPerUnit, currency: currency)
    }

    static func zero(_ currency: Currency = .cop) -> Money { Money(minor: 0, currency: currency) }

    var isZero: Bool { minor == 0 }
    var isNegative: Bool { minor < 0 }
    var magnitude: Money { Money(minor: Swift.abs(minor), currency: currency) }

    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "No se suman monedas distintas")
        return Money(minor: lhs.minor + rhs.minor, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "No se restan monedas distintas")
        return Money(minor: lhs.minor - rhs.minor, currency: lhs.currency)
    }

    static prefix func - (value: Money) -> Money {
        Money(minor: -value.minor, currency: value.currency)
    }

    static func < (lhs: Money, rhs: Money) -> Bool { lhs.minor < rhs.minor }

    /// Formato local fijo, igual en cualquier dispositivo: "$ 1.901.100", "€ 12,50", "− $ 84.300".
    /// `sign` agrega "+ " a los positivos (para balances).
    func formatted(sign: Bool = false) -> String {
        let negative = minor < 0
        let absolute = Swift.abs(minor)
        let perUnit = currency.minorPerUnit
        var units = absolute / perUnit
        var fraction = absolute % perUnit

        // Redondeo al número de cifras que se muestran.
        let hidden = currency.minorDigits - currency.shownDigits
        if hidden > 0 {
            var divisor: Int64 = 1
            for _ in 0..<hidden { divisor *= 10 }
            let rounded = (fraction + divisor / 2) / divisor
            var shownPerUnit: Int64 = 1
            for _ in 0..<currency.shownDigits { shownPerUnit *= 10 }
            if rounded >= shownPerUnit {
                units += 1
                fraction = 0
            } else {
                fraction = rounded
            }
        }

        var text = Money.groupThousands(units)
        if currency.shownDigits > 0 {
            let digits = String(fraction)
            let padded = String(repeating: "0", count: max(0, currency.shownDigits - digits.count)) + digits
            text += "," + padded
        }
        let body = "\(currency.symbol) \(text)"
        if negative { return "− " + body }
        if sign && minor > 0 { return "+ " + body }
        return body
    }

    static func groupThousands(_ value: Int64) -> String {
        let digits = Array(String(value))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result += "." }
            result.append(digit)
        }
        return result
    }
}

/// Lo que se escribe en el teclado numérico de Agregar: dígitos y una coma decimal.
struct AmountInput: Equatable, Sendable {
    private(set) var text: String = ""
    let currency: Currency
    /// Monto ya puesto (Pagar tarjeta, Marcar pagado): la primera tecla lo reemplaza, como si estuviera seleccionado.
    private(set) var replacesOnNextKey = false

    init(currency: Currency = .cop, text: String = "") {
        self.currency = currency
        self.text = text
    }

    /// Arranca con un monto ya guardado, para editar: 4.550.000 centavos de COP se ven "45.500".
    init(minor: Int64, currency: Currency) {
        self.currency = currency
        let value = max(0, minor)
        let units = value / currency.minorPerUnit
        let fraction = value % currency.minorPerUnit
        var text = units == 0 && fraction == 0 ? "" : String(units)
        if currency.shownDigits > 0, fraction > 0 {
            var decimals = String(fraction)
            while decimals.count < currency.minorDigits { decimals = "0" + decimals }
            decimals = String(decimals.prefix(currency.shownDigits))
            while decimals.hasSuffix("0") { decimals.removeLast() }
            if !decimals.isEmpty { text = (units == 0 ? "0" : String(units)) + "," + decimals }
        }
        self.text = text
    }

    /// Arranca con un monto que se puede cambiar de una vez: la primera tecla escribe un monto nuevo y borrar lo deja vacío.
    static func prefilled(minor: Int64, currency: Currency) -> AmountInput {
        var input = AmountInput(minor: minor, currency: currency)
        input.replacesOnNextKey = !input.text.isEmpty
        return input
    }

    var allowsDecimals: Bool { currency.shownDigits > 0 }

    mutating func press(_ key: String) {
        let isDigit = key.count == 1 && key.first?.isNumber == true
        if replacesOnNextKey, isDigit || (key == "," && allowsDecimals) {
            replacesOnNextKey = false
            text = ""
        }
        switch key {
        case ",":
            guard allowsDecimals, !text.contains(",") else { return }
            text = text.isEmpty ? "0," : text + ","
        case "0"..."9":
            if let comma = text.firstIndex(of: ",") {
                let decimals = text.distance(from: comma, to: text.endIndex) - 1
                guard decimals < currency.shownDigits else { return }
            } else {
                guard text.count < 12 else { return }
                if text == "0" { text = "" }
            }
            text += key
        default:
            return
        }
    }

    mutating func deleteLast() {
        if replacesOnNextKey {
            replacesOnNextKey = false
            text = ""
            return
        }
        guard !text.isEmpty else { return }
        text.removeLast()
        if text == "0" { text = "" }
    }

    var money: Money {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let units = Int64(parts.first.map(String.init) ?? "") ?? 0
        var fraction: Int64 = 0
        if parts.count > 1 {
            var decimals = String(parts[1])
            while decimals.count < currency.minorDigits { decimals += "0" }
            fraction = Int64(decimals.prefix(currency.minorDigits)) ?? 0
        }
        return Money(minor: units * currency.minorPerUnit + fraction, currency: currency)
    }

    /// Lo que se ve mientras se escribe, con puntos de miles: "45.500" o "12,5".
    var display: String {
        if text.isEmpty { return "0" }
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let units = Int64(parts.first.map(String.init) ?? "") ?? 0
        var result = Money.groupThousands(units)
        if parts.count > 1 { result += "," + parts[1] }
        return result
    }
}
