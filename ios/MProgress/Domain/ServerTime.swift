import Foundation

/// Fechas como las manda y las espera Postgres (PostgREST): ISO 8601 con hasta 6 decimales de segundo.
/// El decodificador `.iso8601` de Foundation no lee decimales, y perderlos haría bajar la última fila
/// otra vez en cada sincronización.
enum ServerTime {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// "2026-11-08T10:00:00.123456+00:00", "2026-11-08T10:00:00Z", "2026-11-08 10:00:00.5-05:00".
    static func parse(_ text: String) -> Date? {
        let chars = Array(text.trimmingCharacters(in: .whitespaces))
        guard chars.count >= 19 else { return nil }
        func number(_ range: Range<Int>) -> Int? { Int(String(chars[range])) }
        guard let year = number(0..<4), let month = number(5..<7), let day = number(8..<10),
              let hour = number(11..<13), let minute = number(14..<16), let second = number(17..<19),
              chars[4] == "-", chars[7] == "-", chars[10] == "T" || chars[10] == " ", chars[13] == ":", chars[16] == ":"
        else { return nil }
        var index = 19
        var fraction = 0.0
        if index < chars.count, chars[index] == "." {
            index += 1
            var digits = ""
            while index < chars.count, chars[index].isNumber {
                digits.append(chars[index])
                index += 1
            }
            fraction = Double("0." + digits) ?? 0
        }
        var offset = 0
        if index < chars.count {
            let sign = chars[index]
            if sign == "Z" || sign == "z" {
                offset = 0
            } else if sign == "+" || sign == "-" {
                let rest = String(chars[(index + 1)...]).replacingOccurrences(of: ":", with: "")
                guard rest.count >= 2, let hours = Int(rest.prefix(2)) else { return nil }
                let minutes = rest.count >= 4 ? Int(rest.dropFirst(2).prefix(2)) ?? 0 : 0
                offset = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
            } else {
                return nil
            }
        }
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        parts.second = second
        guard let base = utc.date(from: parts) else { return nil }
        return base.addingTimeInterval(fraction - Double(offset))
    }

    /// "2026-11-08T10:00:00.123456Z", siempre en UTC y con 6 decimales (redondea hacia abajo).
    static func format(_ date: Date) -> String {
        let seconds = date.timeIntervalSince1970.rounded(.down)
        var micros = Int(((date.timeIntervalSince1970 - seconds) * 1_000_000).rounded(.down))
        micros = min(999_999, max(0, micros))
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date(timeIntervalSince1970: seconds))
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, micros)
    }

    /// Decodificador JSON para respuestas de Supabase.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha inválida: \(text)")
            }
            return date
        }
        return decoder
    }

    /// Codificador JSON para enviar a Supabase.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(format(date))
        }
        return encoder
    }
}
