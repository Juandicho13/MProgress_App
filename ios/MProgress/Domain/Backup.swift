import Foundation

/// Copia completa de la base, en valores simples (F09-06). Es lo que va dentro de un archivo `.mprogress`.
/// Cada tipo guarda todos sus campos con los mismos ids, así restaurar deja todo igual.
struct BackupSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = BackupSnapshot.currentVersion
    var createdAt: Date
    var app = "MProgress"
    var spaces: [SpaceRow] = []
    var categories: [CategoryRow] = []
    var institutions: [InstitutionRow] = []
    var products: [ProductRow] = []
    var recurring: [RecurringRow] = []
    var entries: [EntryRow] = []
    var transfers: [TransferRow] = []
    var reminders: [ReminderRow] = []
    var budgets: [BudgetRow] = []
    var goals: [GoalRow] = []
    var contributions: [ContributionRow] = []
    /// Opcional: los respaldos de antes no lo traen.
    var rewards: [RewardRow]? = nil
    /// Nombres de comercios aprendidos. Opcional: los respaldos de antes no lo traen.
    var merchantAliases: [MerchantAliasRow]? = nil

    struct SpaceRow: Codable, Equatable, Sendable {
        var id: UUID; var ownerId: UUID; var name: String; var kindRaw: String; var currencyCode: String
        var colorHex: String; var icon: String?; var shareTotalsOnly: Bool; var defaultSplit: Int; var endsOn: Date?
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct CategoryRow: Codable, Equatable, Sendable {
        var id: UUID; var ownerSpaceId: UUID?; var name: String; var icon: String; var colorHex: String?
        var sort: Int; var lastUsedAt: Date?; var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct InstitutionRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var name: String; var colorHex: String?; var icon: String?
        var hidden: Bool; var sort: Int; var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct ProductRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var institutionId: UUID; var parentProductId: UUID?; var kindRaw: String
        var name: String; var last4: String?; var balanceMinor: Int64; var balanceAt: Date; var creditLimitMinor: Int64?
        var cutDay: Int?; var dueDay: Int?; var rateEA: Decimal?; var lockedUntil: Date?; var inWallet: Bool; var hidden: Bool
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
        /// Opcionales para abrir respaldos hechos antes de que existieran (puntos por tarjeta).
        var rewardProgramId: UUID? = nil
        var pointsPerThousand: Decimal? = nil
    }

    struct RecurringRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var kindRaw: String; var name: String; var icon: String?; var amountMinor: Int64
        var cycleRaw: String; var intervalDays: Int?; var nextDate: Date; var anchorDay: Int; var anchorMonth: Int
        var categoryId: UUID?; var productId: UUID?; var responsibleId: UUID?; var active: Bool; var createdBy: UUID?
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
        /// Opcional para abrir respaldos hechos antes de que existiera.
        var dateUnset: Bool? = nil
        /// Pagos con fin (cuotas o fecha final). Opcionales por los respaldos viejos.
        var endDate: Date? = nil
        var totalCount: Int? = nil
        var paidCount: Int? = nil
        /// Meses entre cobros de un pago mensual (1 a 24). Opcional: los respaldos de antes son mensuales (1).
        var intervalMonths: Int? = nil
    }

    struct EntryRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var kindRaw: String; var amountMinor: Int64; var occurredAt: Date; var name: String
        var merchant: String?; var icon: String?; var categoryId: UUID?; var productId: UUID?; var recurringId: UUID?
        var paidBy: UUID?; var methodRaw: String?; var sourceRaw: String; var needsReview: Bool; var notes: String?
        var createdBy: UUID?; var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct TransferRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var fromProductId: UUID; var toProductId: UUID; var amountMinor: Int64
        var occurredAt: Date; var notes: String?; var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct ReminderRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var recurringId: UUID; var daysBefore: Int; var targetRaw: String; var userId: UUID?
        var atMinutes: Int; var notifyPartnerOnPaid: Bool; var sameDay: Bool; var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
        /// "general", "personalizado" o "ninguno". Opcional: los respaldos viejos solo tenían personalizados.
        var modeRaw: String? = nil
    }

    struct BudgetRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var categoryId: UUID?; var monthlyLimitMinor: Int64
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct GoalRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var name: String; var targetAmountMinor: Int64; var targetDate: Date?; var productId: UUID?
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct ContributionRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var goalId: UUID; var userId: UUID?; var amountMinor: Int64; var occurredAt: Date
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    struct RewardRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var name: String; var kindRaw: String; var balance: Int64; var valuePerPoint: Decimal?
        var expiresAt: Date?; var productId: UUID?; var colorHex: String?; var balanceAt: Date
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    /// Comercio del banco ya normalizado con el nombre y la categoría que le dio la persona.
    struct MerchantAliasRow: Codable, Equatable, Sendable {
        var id: UUID; var spaceId: UUID; var key: String; var name: String; var categoryId: UUID?
        var createdAt: Date; var updatedAt: Date; var deletedAt: Date?
    }

    /// Cuántas cosas trae, para mostrar antes de restaurar.
    var summary: String {
        let alive = entries.filter { $0.deletedAt == nil }.count
        let fixed = recurring.filter { $0.deletedAt == nil }.count
        let banks = institutions.filter { $0.deletedAt == nil }.count
        return "\(alive) movimientos, \(fixed) pagos fijos y \(banks) bancos"
    }
}

enum BackupCodec {
    static let fileExtension = "mprogress"

    static func encode(_ snapshot: BackupSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    enum DecodeError: Error, LocalizedError {
        case notMProgress
        case newerVersion(Int)

        var errorDescription: String? {
            switch self {
            case .notMProgress: "Este archivo no es un respaldo de MProgress."
            case .newerVersion(let version): "Este respaldo es de una versión más nueva de la app (\(version)). Actualiza MProgress para abrirlo."
            }
        }
    }

    static func decode(_ data: Data) throws -> BackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(BackupSnapshot.self, from: data), snapshot.app == "MProgress" else {
            throw DecodeError.notMProgress
        }
        guard snapshot.version <= BackupSnapshot.currentVersion else { throw DecodeError.newerVersion(snapshot.version) }
        return snapshot
    }

    /// Movimientos en CSV para Excel o Numbers: fecha, tipo, nombre, categoría, monto con signo, cuenta, notas.
    static func csv(_ snapshot: BackupSnapshot, currency: Currency, calendar: Calendar) -> String {
        let categories = Dictionary(snapshot.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let products = Dictionary(snapshot.products.map { ($0.id, $0.last4.map { "\($0) ·· " } ?? "") }, uniquingKeysWith: { a, _ in a })
        let productNames = Dictionary(snapshot.products.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var lines = ["Fecha,Tipo,Nombre,Categoría,Monto,Moneda,Pagado con,Notas"]
        let rows = snapshot.entries.filter { $0.deletedAt == nil }.sorted { $0.occurredAt > $1.occurredAt }
        for row in rows {
            let parts = calendar.dateComponents([.year, .month, .day], from: row.occurredAt)
            let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            let kind = row.kindRaw == EntryKind.ingreso.rawValue ? "Ingreso" : "Gasto"
            let signed = (row.kindRaw == EntryKind.ingreso.rawValue ? 1 : -1) * row.amountMinor
            let amount = plainAmount(signed, currency: currency)
            let paidWith = row.productId.map { (productNames[$0] ?? "") + (products[$0].map { $0.isEmpty ? "" : " " + $0.replacingOccurrences(of: " ·· ", with: "") } ?? "") } ?? ""
            lines.append([date, kind, row.name, row.categoryId.flatMap { categories[$0] } ?? "", amount, currency.code, paidWith, row.notes ?? ""]
                .map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// "-84300" o "-12.50": sin puntos de miles para que Excel lo lea como número.
    static func plainAmount(_ minor: Int64, currency: Currency) -> String {
        let sign = minor < 0 ? "-" : ""
        let value = abs(minor)
        let units = value / currency.minorPerUnit
        guard currency.shownDigits > 0 else { return "\(sign)\(units)" }
        let fraction = value % currency.minorPerUnit
        return String(format: "%@%lld.%0*lld", sign, units, currency.minorDigits, fraction)
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Nombre del archivo: "MProgress 2026-11-06.mprogress".
    static func fileName(date: Date, calendar: Calendar, ext: String = fileExtension) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "MProgress %04d-%02d-%02d.%@", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, ext)
    }
}
