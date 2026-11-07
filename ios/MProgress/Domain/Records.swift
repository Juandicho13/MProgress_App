import Foundation

// Valores simples que usa el dominio. Los modelos de SwiftData se convierten a
// estos tipos (Data/Models), así los cálculos se prueban sin base de datos.

enum EntryKind: String, Codable, Sendable, CaseIterable {
    case gasto, ingreso

    /// +1 para ingreso, -1 para gasto.
    var sign: Int64 { self == .ingreso ? 1 : -1 }
}

enum ProductKind: String, Codable, Sendable, CaseIterable {
    /// Bolsillo: plata apartada dentro de una cuenta (Nequi, Bancolombia). Cajita: ahorro aparte que suele rendir (Nu).
    case cuenta, debito, credito, bolsillo, efectivo, cajita

    var title: String {
        switch self {
        case .cuenta: "Cuenta"
        case .debito: "Tarjeta débito"
        case .credito: "Tarjeta crédito"
        case .bolsillo: "Bolsillo"
        case .efectivo: "Efectivo"
        case .cajita: "Cajita"
        }
    }

    /// Las tarjetas de crédito guardan deuda; lo demás, dinero disponible.
    var isDebt: Bool { self == .credito }

    /// Bolsillos y cajitas pueden tener tasa E.A. y rendimiento del mes.
    var earnsYield: Bool { self == .bolsillo || self == .cajita }
}

struct EntryRecord: Hashable, Sendable {
    var id: UUID = UUID()
    var kind: EntryKind
    var amountMinor: Int64
    var occurredAt: Date
    var name: String = ""
    var categoryId: UUID?
    var productId: UUID?
    var recurringId: UUID?
    var paidBy: UUID?

    /// Monto con signo: positivo si entra, negativo si sale.
    var signedMinor: Int64 { kind.sign * amountMinor }
}

struct RecurringRecord: Hashable, Sendable {
    var id: UUID = UUID()
    var kind: EntryKind
    var name: String
    var amountMinor: Int64
    var cycle: Cycle
    var nextDate: Date
    var anchor: CycleAnchor
    var active: Bool = true
    var categoryId: UUID?
    var productId: UUID?
    /// Último día con cobro (incluido). Nil: no termina por fecha.
    var endDate: Date? = nil
    /// Número de cuotas. Nil: no termina por cuotas.
    var totalCount: Int? = nil
    /// Cuotas ya pagadas (cada "marcar pagado" suma 1).
    var paidCount: Int = 0
}

struct ProductRecord: Hashable, Sendable {
    var id: UUID = UUID()
    var kind: ProductKind
    var name: String
    /// Saldo de referencia en `balanceAt`. Crédito: deuda positiva.
    var balanceMinor: Int64
    var balanceAt: Date
    var rateEA: Decimal?
    var hidden: Bool = false
    /// Débito: la cuenta que paga. Los gastos con débito salen de ella.
    var parentProductId: UUID?
    /// Crédito: día del mes en que se paga, si se pidió recordarlo.
    var dueDay: Int?
    /// Programa de puntos o millas donde acumula esta tarjeta.
    var rewardProgramId: UUID? = nil
    /// Puntos por cada 1.000 de la moneda gastados con esta tarjeta.
    var pointsPerThousand: Decimal? = nil
}

struct TransferRecord: Hashable, Sendable {
    var id: UUID = UUID()
    var fromProductId: UUID
    var toProductId: UUID
    var amountMinor: Int64
    var occurredAt: Date
}

struct UpcomingCharge: Hashable, Sendable {
    var recurringId: UUID
    var name: String
    var kind: EntryKind
    var amountMinor: Int64
    var date: Date
    var urgency: Urgency
    var daysLeft: Int
}

struct MonthSummary: Hashable, Sendable {
    /// Lo que entra en el mes: registrado más pagos fijos de ingreso pendientes.
    var expectedIncomeMinor: Int64
    /// Lo que ya salió en el mes.
    var spentMinor: Int64
    /// Pagos fijos de gasto que todavía faltan en el mes.
    var pendingFixedMinor: Int64
    /// Te quedan = ingresos esperados menos gastado menos lo que falta por pagar.
    var remainingMinor: Int64
    /// 0 a 1, para la barra del mes.
    var spentRatio: Double
    var daysLeft: Int
}
