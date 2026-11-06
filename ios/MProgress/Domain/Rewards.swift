import Foundation

enum RewardKind: String, Codable, Sendable, CaseIterable {
    case puntos, millas

    var title: String { self == .puntos ? "Puntos" : "Millas" }
    var unit: String { self == .puntos ? "puntos" : "millas" }
}

struct RewardRecord: Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var kind: RewardKind
    var balance: Int64
    var valuePerPoint: Decimal?
    var expiresAt: Date?
}

enum RewardMath {
    /// Programas que más se usan en Colombia. El valor de cada punto no se pone: cambia y lo decide cada programa.
    static let suggestions: [(name: String, kind: RewardKind, hex: String)] = [
        ("Puntos Colombia", .puntos, "FF6B2C"), ("LifeMiles", .millas, "ED4C5C"), ("LATAM Pass", .millas, "4A90D9"),
        ("Puntos Davivienda", .puntos, "FF7A85"), ("Puntos BBVA", .puntos, "5B8DEF"), ("Otro", .puntos, "3A3F47"),
    ]

    /// Valor aproximado del saldo, si se sabe cuánto vale cada punto.
    static func estimatedValueMinor(_ reward: RewardRecord, currency: Currency) -> Int64? {
        guard let value = reward.valuePerPoint, value > 0 else { return nil }
        let total = Decimal(reward.balance) * value * Decimal(currency.minorPerUnit)
        return NSDecimalNumber(decimal: total).int64Value
    }

    /// Suma del valor aproximado de todos los programas que tienen valor.
    static func totalValueMinor(_ rewards: [RewardRecord], currency: Currency) -> Int64 {
        rewards.compactMap { estimatedValueMinor($0, currency: currency) }.reduce(0, +)
    }

    /// Avisa si vencen en los próximos 60 días: "Vencen en 12 días", "Vencen hoy", "Vencieron".
    static func expiryText(_ reward: RewardRecord, now: Date, calendar: Calendar) -> String? {
        guard let date = reward.expiresAt else { return nil }
        let days = Urgency.dayDifference(from: now, to: date, calendar: calendar)
        if days < 0 { return "Vencieron" }
        if days == 0 { return "Vencen hoy" }
        if days <= 60 { return "Vencen en \(days) \(days == 1 ? "día" : "días")" }
        return nil
    }

    /// "12.450 puntos".
    static func balanceText(_ reward: RewardRecord) -> String {
        "\(Money.groupThousands(reward.balance)) \(reward.kind.unit)"
    }
}
