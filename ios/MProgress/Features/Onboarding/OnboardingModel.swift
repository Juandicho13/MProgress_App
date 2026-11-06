import Foundation
import SwiftData
import Observation

/// Producto que se va a crear al terminar el onboarding.
struct PlannedProduct: Identifiable, Hashable {
    let id = UUID()
    var kind: ProductKind
    var name: String
    var last4: String?

    var label: String { last4.map { "\(name) ·· \($0)" } ?? name }
}

/// Banco o billetera que se va a crear al terminar el onboarding.
struct PlannedBank: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var colorHex: String
    var products: [PlannedProduct]
}

/// Gasto fijo del onboarding: sugerido o agregado a mano. El día y con qué se paga se eligen en el paso de fechas.
struct PlannedFixed: Identifiable, Hashable {
    let id: String
    var name: String
    var symbol: String?
    var categoryName: String?
    var units: Int64
    var selected: Bool
    /// Nil: aún sin día. Si sigue nil al terminar, queda "sin fecha" en Pagos fijos.
    var day: Int?
    var productId: UUID?
    var later = false

    init(_ suggestion: FixedSuggestion) {
        id = suggestion.id
        name = suggestion.name
        symbol = suggestion.symbol
        categoryName = suggestion.categoryName
        units = suggestion.units
        selected = suggestion.selectedByDefault
    }

    init(customName: String, units: Int64) {
        id = "propio-\(UUID().uuidString)"
        name = customName
        self.units = units
        selected = true
    }
}

/// Estado del onboarding (F02). Orden: ingreso, bancos y tarjetas, gastos fijos, fecha y con qué se paga cada uno,
/// intereses y funciones. Al terminar guarda todo de una vez.
@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case bienvenida, ingreso, bancos, fijos, fechas, intereses, funciones
    }

    static let doneKey = "onboarding.terminado"
    static let interestsKey = "onboarding.intereses"

    var step: Step = .bienvenida
    var income = AmountInput()
    var payday = 1
    /// A dónde llega el sueldo (un producto planeado).
    var incomeProductId: UUID?
    var banks: [PlannedBank] = []
    var fixed: [PlannedFixed] = FixedSuggestion.defaults.map(PlannedFixed.init)
    var interests: Set<Interest> = Interest.defaultSelection
    var slideIndex = 0

    /// Avance de la barra superior, de 0 a 1.
    var progress: Double {
        let total = Double(Step.allCases.count)
        if step == .funciones, !slides.isEmpty {
            let inner = Double(slideIndex + 1) / Double(slides.count)
            return (Double(step.rawValue) + inner) / total
        }
        return Double(step.rawValue + 1) / total
    }

    var slides: [Interest] { Interest.allCases.filter { interests.contains($0) } }
    var selectedFixed: [PlannedFixed] { fixed.filter { $0.selected && $0.units > 0 } }
    var plannedProducts: [PlannedProduct] { banks.flatMap(\.products) }

    func next() {
        if step == .funciones {
            if slideIndex + 1 < slides.count { slideIndex += 1 }
            return
        }
        if var following = Step(rawValue: step.rawValue + 1) {
            // Sin fijos elegidos no hay fechas que poner.
            if following == .fechas, selectedFixed.isEmpty, income.money.isZero { following = .intereses }
            if following == .funciones { slideIndex = 0 }
            step = following
        }
    }

    func back() {
        if step == .funciones, slideIndex > 0 {
            slideIndex -= 1
            return
        }
        if var previous = Step(rawValue: step.rawValue - 1) {
            if previous == .fechas, selectedFixed.isEmpty, income.money.isZero { previous = .fijos }
            step = previous
        }
    }

    var isLastSlide: Bool { step == .funciones && slideIndex >= slides.count - 1 }

    // MARK: Bancos

    /// Agrega un banco con su cuenta; Efectivo agrega la billetera física.
    func addBank(name: String, colorHex: String) {
        if name == "Efectivo" {
            guard !banks.contains(where: { $0.name == "Efectivo" }) else { return }
            banks.append(PlannedBank(name: name, colorHex: colorHex, products: [PlannedProduct(kind: .efectivo, name: "Efectivo")]))
            return
        }
        banks.append(PlannedBank(name: name, colorHex: colorHex, products: [PlannedProduct(kind: .cuenta, name: "Cuenta de ahorros")]))
    }

    func addProduct(_ product: PlannedProduct, to bankId: UUID) {
        guard let index = banks.firstIndex(where: { $0.id == bankId }) else { return }
        var clean = product
        clean.last4 = MoneyStore.cleanLast4(product.last4)
        banks[index].products.append(clean)
    }

    func removeProduct(_ productId: UUID) {
        for index in banks.indices { banks[index].products.removeAll { $0.id == productId } }
        clearReferences(to: [productId])
    }

    func removeBank(_ bankId: UUID) {
        let ids = banks.first { $0.id == bankId }?.products.map(\.id) ?? []
        banks.removeAll { $0.id == bankId }
        clearReferences(to: Set(ids))
    }

    private func clearReferences(to ids: Set<UUID>) {
        if let income = incomeProductId, ids.contains(income) { incomeProductId = nil }
        for index in fixed.indices where fixed[index].productId.map(ids.contains) == true { fixed[index].productId = nil }
    }

    // MARK: Fijos

    func toggleFixed(_ id: String) {
        guard let index = fixed.firstIndex(where: { $0.id == id }) else { return }
        fixed[index].selected.toggle()
    }

    func setUnits(_ units: Int64, for id: String) {
        guard let index = fixed.firstIndex(where: { $0.id == id }) else { return }
        fixed[index].units = units
        fixed[index].selected = true
    }

    func addCustomFixed(name: String, units: Int64) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, units > 0 else { return }
        fixed.append(PlannedFixed(customName: clean, units: units))
    }

    func setDay(_ day: Int?, for id: String) {
        guard let index = fixed.firstIndex(where: { $0.id == id }) else { return }
        fixed[index].day = day
        if day != nil { fixed[index].later = false }
    }

    func setProduct(_ productId: UUID?, for id: String) {
        guard let index = fixed.firstIndex(where: { $0.id == id }) else { return }
        fixed[index].productId = productId
    }

    func setLater(_ later: Bool, for id: String) {
        guard let index = fixed.firstIndex(where: { $0.id == id }) else { return }
        fixed[index].later = later
        if later { fixed[index].day = nil }
    }

    /// "Todo más tarde": deja todos los fijos sin fecha y sigue.
    func allLater() {
        for index in fixed.indices where fixed[index].selected {
            fixed[index].later = true
            fixed[index].day = nil
        }
        next()
    }

    func toggleInterest(_ interest: Interest) {
        if interests.contains(interest) { interests.remove(interest) } else { interests.insert(interest) }
    }

    // MARK: Terminar

    /// Guarda todo en la base local y marca el onboarding como terminado.
    func finish(context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now, calendar: Calendar = .current) throws {
        let user = LocalIdentity.userId
        let space = try Seed.runIfNeeded(context: context, localUser: user)
        let ledger = LedgerStore(context: context, calendar: calendar)
        let money = MoneyStore(context: context)
        let categories = try ledger.categories(spaceId: space.id)
        func categoryId(_ name: String?) -> UUID? { name.flatMap { n in categories.first { $0.name == n }?.id } }

        // 1. Bancos y tarjetas, para poder decir con qué se paga cada fijo.
        var realIds: [UUID: UUID] = [:]
        for bank in banks {
            if bank.products.contains(where: { $0.kind == .efectivo }) {
                let cash = try money.cash(spaceId: space.id)
                for product in bank.products { realIds[product.id] = cash.id }
                continue
            }
            let institution = try money.addInstitution(spaceId: space.id, name: bank.name, colorHex: bank.colorHex)
            var accountId: UUID?
            for product in bank.products.sorted(by: { ($0.kind == .cuenta ? 0 : 1) < ($1.kind == .cuenta ? 0 : 1) }) {
                var draft = MoneyStore.ProductDraft(kind: product.kind, name: product.name, last4: product.last4)
                draft.inWallet = product.kind == .credito || product.kind == .debito
                draft.parentProductId = product.kind == .debito ? accountId : nil
                let created = try money.addProduct(spaceId: space.id, institutionId: institution.id, draft: draft, now: now)
                if product.kind == .cuenta, accountId == nil { accountId = created.id }
                realIds[product.id] = created.id
            }
        }

        // 2. Sueldo.
        let salary = income.money
        if salary.minor > 0 {
            let plan = OnboardingPlan.salaryPlan(payday: payday, now: now, calendar: calendar)
            let target = incomeProductId.flatMap { realIds[$0] }
            if let registerOn = plan.registerOn {
                try ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: salary.minor, name: "Sueldo",
                                    occurredAt: registerOn, categoryId: categoryId("Finanzas"), productId: target, createdBy: user)
            }
            let item = try ledger.addRecurring(spaceId: space.id, kind: .ingreso, name: "Sueldo", amountMinor: salary.minor,
                                               cycle: .mensual, nextDate: plan.nextDate, categoryId: categoryId("Finanzas"),
                                               productId: target, createdBy: user)
            item.icon = "banknote"
        }

        // 3. Fijos: con día, o sin fecha para ponerla después en Pagos fijos.
        for plan in selectedFixed {
            let day = plan.later ? nil : plan.day
            let nextDate = OnboardingPlan.nextDate(day: day ?? 1, from: now, calendar: calendar)
            let item = try ledger.addRecurring(
                spaceId: space.id, kind: .gasto, name: plan.name,
                amountMinor: Money(units: plan.units, currency: space.currency).minor, cycle: .mensual,
                nextDate: nextDate, categoryId: categoryId(plan.categoryName),
                productId: plan.productId.flatMap { realIds[$0] }, createdBy: user
            )
            item.icon = plan.symbol
            item.dateUnset = day == nil
        }
        try context.save()

        defaults.set(interests.map(\.rawValue).sorted(), forKey: Self.interestsKey)
        defaults.set(true, forKey: Self.doneKey)
    }
}
