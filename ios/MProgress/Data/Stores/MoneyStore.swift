import Foundation
import SwiftData

/// Bancos, tarjetas, bolsillos y transferencias de un espacio (F06).
@MainActor
final class MoneyStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func addInstitution(spaceId: UUID, name: String, colorHex: String? = nil) throws -> Institution {
        let institution = Institution(spaceId: spaceId, name: name, colorHex: colorHex)
        institution.touch()
        context.insert(institution)
        try context.save()
        return institution
    }

    /// `last4` solo acepta 4 dígitos; cualquier otra cosa se descarta (nunca el número completo).
    @discardableResult
    func addProduct(spaceId: UUID, institutionId: UUID, kind: ProductKind, name: String, balanceMinor: Int64 = 0,
                    last4: String? = nil, parentProductId: UUID? = nil, rateEA: Decimal? = nil) throws -> Product {
        let product = Product(spaceId: spaceId, institutionId: institutionId, kind: kind, name: name)
        product.balanceMinor = balanceMinor
        product.balanceAt = .now
        product.last4 = MoneyStore.cleanLast4(last4)
        product.parentProductId = parentProductId
        product.rateEA = rateEA
        product.touch()
        context.insert(product)
        try context.save()
        return product
    }

    @discardableResult
    func transfer(spaceId: UUID, from: Product, to: Product, amountMinor: Int64, on date: Date = .now) throws -> Transfer {
        precondition(amountMinor > 0, "La transferencia va siempre positiva")
        precondition(from.id != to.id, "No se transfiere a sí mismo")
        let transfer = Transfer(spaceId: spaceId, fromProductId: from.id, toProductId: to.id, amountMinor: amountMinor, occurredAt: date)
        transfer.touch()
        context.insert(transfer)
        try context.save()
        return transfer
    }

    /// Datos de un producto que se piden en Agregar a un banco (pantalla 33).
    struct ProductDraft: Equatable {
        var kind: ProductKind = .cuenta
        var name: String = ""
        var balanceMinor: Int64 = 0
        var last4: String?
        var creditLimitMinor: Int64?
        var cutDay: Int?
        var dueDay: Int?
        var rateEA: Decimal?
        var parentProductId: UUID?
        var inWallet: Bool = false
        var remindPayment: Bool = true
        var hidden: Bool = false
        /// Tarjetas: programa de puntos donde acumula y cuántos puntos da por cada 1.000.
        var rewardProgramId: UUID?
        var pointsPerThousand: Decimal?
    }

    /// Crea un producto con todos sus datos. El saldo queda como saldo de hoy.
    @discardableResult
    func addProduct(spaceId: UUID, institutionId: UUID, draft: ProductDraft, now: Date = .now) throws -> Product {
        let product = Product(spaceId: spaceId, institutionId: institutionId, kind: draft.kind, name: draft.name)
        apply(draft, to: product, now: now)
        context.insert(product)
        try context.save()
        return product
    }

    /// Cambia un producto. Si el saldo cambió, se toma como el saldo de hoy (ajuste) y los movimientos
    /// anteriores dejan de moverlo.
    func update(_ product: Product, draft: ProductDraft, currentBalanceMinor: Int64, now: Date = .now) throws {
        let balanceChanged = draft.balanceMinor != currentBalanceMinor
        let previousBalance = product.balanceMinor
        let previousAt = product.balanceAt
        apply(draft, to: product, now: now)
        if !balanceChanged {
            product.balanceMinor = previousBalance
            product.balanceAt = previousAt
        }
        try context.save()
    }

    private func apply(_ draft: ProductDraft, to product: Product, now: Date) {
        product.kind = draft.kind
        product.name = draft.name.trimmingCharacters(in: .whitespaces)
        product.balanceMinor = draft.balanceMinor
        product.balanceAt = now
        let isCard = draft.kind == .credito || draft.kind == .debito
        product.last4 = isCard ? MoneyStore.cleanLast4(draft.last4) : nil
        product.creditLimitMinor = draft.kind == .credito ? draft.creditLimitMinor : nil
        product.cutDay = draft.kind == .credito ? draft.cutDay.map { min(31, max(1, $0)) } : nil
        product.dueDay = draft.kind == .credito && draft.remindPayment ? draft.dueDay.map { min(31, max(1, $0)) } : nil
        product.rateEA = draft.kind.earnsYield ? draft.rateEA : nil
        product.parentProductId = draft.kind == .debito ? draft.parentProductId : nil
        product.inWallet = isCard && draft.inWallet
        product.hidden = draft.hidden
        let earns = isCard && draft.rewardProgramId != nil
        product.rewardProgramId = earns ? draft.rewardProgramId : nil
        product.pointsPerThousand = earns ? draft.pointsPerThousand.flatMap { $0 > 0 ? $0 : nil } : nil
        if earns, let programId = draft.rewardProgramId { linkReward(programId, to: product, now: now) }
        product.touch(now)
    }

    /// El programa queda mostrando con qué tarjeta se acumula, si aún no tenía una.
    private func linkReward(_ programId: UUID, to product: Product, now: Date) {
        let query = FetchDescriptor<RewardProgram>(predicate: #Predicate<RewardProgram> { $0.id == programId })
        guard let reward = try? context.fetch(query).first, reward.productId == nil else { return }
        reward.productId = product.id
        reward.touch(now)
    }

    func institutions(spaceId: UUID) throws -> [Institution] {
        try context.fetch(FetchDescriptor<Institution>(
            predicate: #Predicate<Institution> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sort), SortDescriptor(\.createdAt)]
        ))
    }

    /// La billetera de efectivo del espacio; la crea la primera vez.
    @discardableResult
    func cash(spaceId: UUID) throws -> Product {
        if let existing = try products(spaceId: spaceId).first(where: { $0.kind == .efectivo }) { return existing }
        let wallet = try cashInstitution(spaceId: spaceId)
        return try addProduct(spaceId: spaceId, institutionId: wallet.id, kind: .efectivo, name: "Efectivo")
    }

    /// El grupo "Efectivo" de Dinero, donde viven todos los efectivos. Lo crea si no existe.
    @discardableResult
    func cashInstitution(spaceId: UUID) throws -> Institution {
        let all = try institutions(spaceId: spaceId)
        let cashOwners = Set(try products(spaceId: spaceId).filter { $0.kind == .efectivo }.map(\.institutionId))
        if let existing = all.first(where: { cashOwners.contains($0.id) }) ?? all.first(where: { $0.name == "Efectivo" }) {
            return existing
        }
        return try addInstitution(spaceId: spaceId, name: "Efectivo", colorHex: "3A3F47")
    }

    /// Otro efectivo con nombre propio ("Billetera", "Casa", "Alcancía"), con su saldo, dentro del grupo Efectivo.
    @discardableResult
    func addCash(spaceId: UUID, name: String, balanceMinor: Int64 = 0, now: Date = .now) throws -> Product {
        let group = try cashInstitution(spaceId: spaceId)
        let clean = name.trimmingCharacters(in: .whitespaces)
        var draft = ProductDraft(kind: .efectivo, name: clean.isEmpty ? "Efectivo" : clean)
        draft.balanceMinor = balanceMinor
        return try addProduct(spaceId: spaceId, institutionId: group.id, draft: draft, now: now)
    }

    /// Borra un producto. Los movimientos que lo usaban quedan sin producto, no se borran.
    func softDelete(_ product: Product, now: Date = .now) throws {
        product.deletedAt = now
        product.touch(now)
        try context.save()
    }

    /// Borra un banco con todos sus productos.
    func softDelete(_ institution: Institution, now: Date = .now) throws {
        let id = institution.id
        let owned = try context.fetch(FetchDescriptor<Product>(predicate: #Predicate<Product> { $0.institutionId == id && $0.deletedAt == nil }))
        for product in owned {
            product.deletedAt = now
            product.touch(now)
        }
        institution.deletedAt = now
        institution.touch(now)
        try context.save()
    }

    func products(spaceId: UUID) throws -> [Product] {
        try context.fetch(FetchDescriptor<Product>(
            predicate: #Predicate<Product> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        ))
    }

    func transfers(spaceId: UUID) throws -> [Transfer] {
        try context.fetch(FetchDescriptor<Transfer>(
            predicate: #Predicate<Transfer> { $0.spaceId == spaceId && $0.deletedAt == nil }
        ))
    }

    nonisolated static func cleanLast4(_ text: String?) -> String? {
        guard let text else { return nil }
        let digits = text.filter(\.isNumber)
        return digits.count == 4 ? digits : nil
    }

    // MARK: Puntos y millas

    func rewards(spaceId: UUID) throws -> [RewardProgram] {
        try context.fetch(FetchDescriptor<RewardProgram>(
            predicate: #Predicate<RewardProgram> { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        ))
    }

    /// Crea o cambia un programa de puntos o millas.
    @discardableResult
    func saveReward(_ existing: RewardProgram?, spaceId: UUID, name: String, kind: RewardKind, balance: Int64,
                    valuePerPoint: Decimal?, expiresAt: Date?, productId: UUID?, colorHex: String?, now: Date = .now) throws -> RewardProgram {
        let reward = existing ?? {
            let created = RewardProgram(spaceId: spaceId, name: name, kind: kind, balance: balance)
            context.insert(created)
            return created
        }()
        if reward.balance != max(0, balance) { reward.balanceAt = now }
        reward.name = name.trimmingCharacters(in: .whitespaces)
        reward.kind = kind
        reward.balance = max(0, balance)
        reward.valuePerPoint = valuePerPoint.flatMap { $0 > 0 ? $0 : nil }
        reward.expiresAt = expiresAt
        reward.productId = productId
        reward.colorHex = colorHex
        reward.touch(now)
        try context.save()
        return reward
    }

    func softDelete(_ reward: RewardProgram, now: Date = .now) throws {
        reward.deletedAt = now
        reward.touch(now)
        try context.save()
    }
}
