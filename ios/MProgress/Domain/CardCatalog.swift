import Foundation

/// Franquicia de una tarjeta.
enum CardFranchise: String, Codable, Sendable, CaseIterable {
    case visa, mastercard, amex, diners

    var title: String {
        switch self {
        case .visa: "Visa"
        case .mastercard: "Mastercard"
        case .amex: "American Express"
        case .diners: "Diners Club"
        }
    }
}

/// Una tarjeta de crédito del catálogo (Resources/CardCatalog.json, igual a assets/card_catalog.json en Android).
struct CatalogCard: Codable, Hashable, Sendable, Identifiable {
    /// Estable: "<banco>-<nombre>", por ejemplo "bancolombia-visa-clasica". Se guarda en `Product.catalogCardId`.
    let id: String
    let name: String
    let franchise: CardFranchise?
    /// Texto libre: clasica, oro, platinum, signature, infinite, black…
    let tier: String?
    /// Programa de puntos o millas: Puntos Colombia, LifeMiles, LATAM Pass, Cashback…
    let rewards: String?
    /// Cuota de manejo mensual indicativa en pesos, solo si se publica claro. Nil: no se sabe.
    let handlingFeeCOP: Int64?
    let note: String?

    /// Cuota de manejo en unidades mínimas de COP.
    var handlingFeeMinor: Int64? { handlingFeeCOP.map { $0 * Currency.cop.minorPerUnit } }

    /// "Visa · Puntos Colombia".
    var subtitle: String {
        [franchise?.title, rewards].compactMap { $0 }.joined(separator: " · ")
    }
}

struct CatalogBank: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let source: String
    let sources: [String]
    let checkedAt: String
    /// False si no se pudo confirmar la lista completa en una fuente de 2026.
    let verified: Bool
    let note: String?
    let feeNote: String?
    let cards: [CatalogCard]
}

struct CardCatalog: Codable, Hashable, Sendable {
    let version: Int
    let checkedAt: String
    /// Tope de usura del mes como fracción (0,2834 es 28,34 % E.A.). Solo para sugerir la tasa.
    let usuraEA: Decimal
    /// "2026-11".
    let usuraMonth: String
    let usuraSource: String
    /// "Tope legal de este mes, revisa tu extracto".
    let usuraNote: String
    let note: String
    let banks: [CatalogBank]

    static func decode(_ data: Data) throws -> CardCatalog {
        try JSONDecoder().decode(CardCatalog.self, from: data)
    }

    /// El catálogo que va dentro de la app (nil en las pruebas del paquete de dominio).
    static func bundled(_ bundle: Bundle = .main) -> CardCatalog? {
        guard let url = bundle.url(forResource: "CardCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }

    /// Tasa sugerida en porcentaje, como `Product.rateEA` (28,34).
    var usuraRateEA: Decimal {
        var value = usuraEA * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 4, .plain)
        return rounded
    }

    /// Banco que corresponde a lo que escribió la persona: sin tildes ni mayúsculas, sin "Banco", "de" ni
    /// "Colombia", y con alias ("Colpatria", "Nubank", "Itaú"). Nil si no se parece a ninguno.
    func bank(matching name: String) -> CatalogBank? {
        let query = CardCatalog.tokens(name)
        guard !query.isEmpty else { return nil }
        var best: (score: Int, bank: CatalogBank)?
        for bank in banks {
            for alias in [bank.name, bank.id] + bank.aliases {
                let target = CardCatalog.tokens(alias)
                guard !target.isEmpty else { continue }
                let score: Int
                if target == query {
                    score = 1000 + target.count
                } else if CardCatalog.contains(query, target) {
                    score = 500 + target.joined().count
                } else if CardCatalog.contains(target, query) && query.joined().count >= 3 {
                    score = 100 + query.joined().count
                } else {
                    continue
                }
                if best == nil || score > best!.score { best = (score, bank) }
            }
        }
        return best?.bank
    }

    /// Tarjetas del banco que escribió la persona (vacío si no se reconoce el banco).
    func cards(forBank name: String) -> [CatalogCard] { bank(matching: name)?.cards ?? [] }

    func card(id: String) -> (bank: CatalogBank, card: CatalogCard)? {
        for bank in banks {
            if let card = bank.cards.first(where: { $0.id == id }) { return (bank, card) }
        }
        return nil
    }

    /// Palabras que no ayudan a distinguir un banco.
    static let ignoredWords: Set<String> = ["banco", "de", "del", "la", "el", "colombia", "sa", "s", "a", "bank"]

    /// "Banco de Bogotá S.A." da ["bogota"]; "Lulo Bank" da ["lulo"]; "DAVIbank" da ["davibank"]; "Banco" no da nada.
    static func tokens(_ raw: String) -> [String] {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_CO")).lowercased()
        var words: [String] = []
        var current = ""
        for character in folded {
            if character == "." || character == "'" { continue }
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words.filter { !ignoredWords.contains($0) }
    }

    /// True si `needle` aparece completa y seguida dentro de `haystack`.
    static func contains(_ haystack: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) where Array(haystack[start..<(start + needle.count)]) == needle {
            return true
        }
        return false
    }
}
