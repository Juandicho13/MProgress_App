import Foundation

/// Regla aprendida de un comercio: el texto del banco ("PEPEPOLLO SAS 123") con el nombre y la categoría
/// que la persona le puso ("El Corral", Salidas).
struct MerchantAliasRule: Hashable, Sendable {
    var id: UUID = UUID()
    /// Comercio normalizado (`MerchantAliasMath.normalize`), por ejemplo "PEPEPOLLO".
    var key: String
    var name: String
    var categoryId: UUID?
}

/// Nombres de comercios: normalizar lo que manda el banco, aprender del nombre que le da la persona y
/// buscar la regla cuando llega otro pago del mismo comercio.
enum MerchantAliasMath {
    /// Palabras que no dicen qué comercio es: tipo de sociedad, país y ciudades.
    static let noise: Set<String> = [
        "SAS", "SA", "LTDA", "LTD", "CO", "COL", "COLOMBIA", "CIA", "INC", "LLC", "EU", "SUC", "SUCURSAL",
        "BOGOTA", "BOG", "DC", "MEDELLIN", "MED", "CALI", "BARRANQUILLA", "BQUILLA", "CARTAGENA", "BUCARAMANGA",
        "PEREIRA", "MANIZALES", "CHIA", "ENVIGADO", "SOACHA",
    ]

    /// "Pepepollo S.A.S. 123" pasa a "PEPEPOLLO": mayúsculas, sin tildes, sin números ni signos, sin
    /// SAS, LTDA, CO, BOGOTA y parecidos, y con un solo espacio entre palabras. Si todo es ruido, se dejan
    /// las palabras para no quedar vacío.
    static func normalize(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_CO")).uppercased()
        var cleaned = ""
        for character in folded {
            if character == "." || character == "'" || character == "’" {
                // "S.A.S" es "SAS" y "MC'DONALDS" es "MCDONALDS".
                continue
            }
            if character.isLetter && character.isASCII {
                cleaned.append(character)
            } else {
                cleaned.append(" ")
            }
        }
        let words = cleaned.split(separator: " ").map(String.init)
        let meaningful = words.filter { !noise.contains($0) }
        return (meaningful.isEmpty ? words : meaningful).joined(separator: " ")
    }

    /// La regla de un comercio: la de la misma clave o, si no hay, la más larga con la que empieza
    /// (palabra completa: "EXITO" sirve para "EXITO CALLE", no para "EXITOSO").
    static func match(_ raw: String?, rules: [MerchantAliasRule]) -> MerchantAliasRule? {
        guard let raw else { return nil }
        let key = normalize(raw)
        guard !key.isEmpty else { return nil }
        if let exact = rules.first(where: { $0.key == key }) { return exact }
        return rules
            .filter { !$0.key.isEmpty && key.hasPrefix($0.key + " ") }
            .max { $0.key.count < $1.key.count }
    }

    /// Qué aprender al guardar un movimiento que llegó solo (SMS, notificación, Apple Pay o recibo):
    /// el nombre que le dio la persona, si es otro, y la categoría, si eligió una. Nil si no hay nada que aprender.
    static func learn(raw: String?, automatic: Bool, name: String, categoryId: UUID?) -> MerchantAliasRule? {
        guard automatic, let raw else { return nil }
        let key = normalize(raw)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !cleanName.isEmpty else { return nil }
        let renamed = normalize(cleanName) != key
        guard renamed || categoryId != nil else { return nil }
        return MerchantAliasRule(key: key, name: cleanName, categoryId: categoryId)
    }

    /// Nombre y categoría para un pago que llega: los de la regla o, si no hay, el comercio tal como llegó.
    static func prefill(raw: String?, rules: [MerchantAliasRule]) -> (name: String?, categoryId: UUID?) {
        guard let rule = match(raw, rules: rules) else { return (raw, nil) }
        return (rule.name, rule.categoryId)
    }
}
