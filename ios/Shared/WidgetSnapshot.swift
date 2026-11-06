import Foundation

/// Lo que ven los widgets (F12). La app lo escribe ya calculado y con los textos listos;
/// los widgets solo lo leen. Vive en el contenedor del App Group.
struct WidgetSnapshot: Codable, Sendable, Equatable {
    struct Charge: Codable, Sendable, Hashable {
        var name: String
        var amountText: String
        /// Días que faltan: 0 hoy, negativo vencido.
        var daysLeft: Int
        var isIncome: Bool

        var dueText: String {
            switch daysLeft {
            case ..<0: "Vencido"
            case 0: "Hoy"
            case 1: "Mañana"
            default: "\(daysLeft) d"
            }
        }
    }

    var updatedAt: Date
    var remainingText: String
    var remainingIsNegative: Bool
    var monthName: String
    /// 0 a 1: cuánto del mes ya se gastó.
    var spentRatio: Double
    var charges: [Charge]
    var monthTitle: String
    var weekdaySymbols: [String]
    var leadingBlanks: Int
    var daysInMonth: Int
    var today: Int
    /// Día del mes con cobro → 0 hoy o vencido, 1 pronto, 2 más adelante.
    var chargeDays: [String: Int]
    var chargesThisMonth: Int
    var isEmpty: Bool

    static let groupId = "group.com.olarte.mprogress"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)?.appending(path: "widget.json")
    }

    /// False si la app no tiene App Group (cuenta gratuita de Apple): los widgets muestran el modo sin datos.
    static var canShare: Bool { fileURL != nil }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() throws {
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// Para la galería de widgets y las vistas previas.
    static let sample = WidgetSnapshot(
        updatedAt: .now, remainingText: "$ 1.901.100", remainingIsNegative: false, monthName: "noviembre", spentRatio: 0.42,
        charges: [
            Charge(name: "Gimnasio", amountText: "$ 119.900", daysLeft: 1, isIncome: false),
            Charge(name: "Suscripción IA", amountText: "$ 85.000", daysLeft: 7, isIncome: false),
            Charge(name: "Música", amountText: "$ 16.900", daysLeft: 7, isIncome: false),
            Charge(name: "Renta", amountText: "$ 2.275.000", daysLeft: 27, isIncome: false),
        ],
        monthTitle: "Noviembre", weekdaySymbols: ["D", "L", "M", "M", "J", "V", "S"], leadingBlanks: 0, daysInMonth: 30, today: 4,
        chargeDays: ["5": 1, "11": 2, "12": 2, "1": 2], chargesThisMonth: 4, isEmpty: false
    )

    /// Enlaces que abren la app desde un widget.
    enum Link {
        static let quickAdd = URL(string: "mprogress://rapido")!
        static let fixed = URL(string: "mprogress://fijos")!
        static let calendar = URL(string: "mprogress://calendario")!
        static let home = URL(string: "mprogress://inicio")!
    }
}
