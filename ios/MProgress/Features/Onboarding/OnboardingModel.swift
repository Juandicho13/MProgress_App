import Foundation
import SwiftData
import Observation

/// Estado del onboarding (F02). Al terminar guarda sueldo, pagos fijos e intereses.
@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case bienvenida, ingreso, fijos, intereses, funciones
    }

    static let doneKey = "onboarding.terminado"
    static let interestsKey = "onboarding.intereses"

    var step: Step = .bienvenida
    var income = AmountInput()
    var payday = 1
    var fixedSelected: Set<String> = Set(FixedSuggestion.defaults.filter(\.selectedByDefault).map(\.id))
    var fixedUnits: [String: Int64] = Dictionary(uniqueKeysWithValues: FixedSuggestion.defaults.map { ($0.id, $0.units) })
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

    func next() {
        if step == .funciones {
            if slideIndex + 1 < slides.count { slideIndex += 1 }
            return
        }
        if let following = Step(rawValue: step.rawValue + 1) {
            if following == .funciones { slideIndex = 0 }
            step = following
        }
    }

    func back() {
        if step == .funciones, slideIndex > 0 {
            slideIndex -= 1
            return
        }
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    var isLastSlide: Bool { step == .funciones && slideIndex >= slides.count - 1 }

    func toggleFixed(_ id: String) {
        if fixedSelected.contains(id) { fixedSelected.remove(id) } else { fixedSelected.insert(id) }
    }

    func toggleInterest(_ interest: Interest) {
        if interests.contains(interest) { interests.remove(interest) } else { interests.insert(interest) }
    }

    /// Guarda todo en la base local y marca el onboarding como terminado.
    func finish(context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now, calendar: Calendar = .current) throws {
        let user = LocalIdentity.userId
        let space = try Seed.runIfNeeded(context: context, localUser: user)
        let ledger = LedgerStore(context: context, calendar: calendar)
        let categories = try ledger.categories(spaceId: space.id)
        func categoryId(_ name: String) -> UUID? { categories.first { $0.name == name }?.id }

        let salary = income.money
        if salary.minor > 0 {
            let plan = OnboardingPlan.salaryPlan(payday: payday, now: now, calendar: calendar)
            if let registerOn = plan.registerOn {
                try ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: salary.minor, name: "Sueldo",
                                    occurredAt: registerOn, categoryId: categoryId("Finanzas"), createdBy: user)
            }
            let item = try ledger.addRecurring(spaceId: space.id, kind: .ingreso, name: "Sueldo", amountMinor: salary.minor,
                                               cycle: .mensual, nextDate: plan.nextDate, categoryId: categoryId("Finanzas"), createdBy: user)
            item.icon = "banknote"
        }

        for suggestion in FixedSuggestion.defaults where fixedSelected.contains(suggestion.id) {
            let units = fixedUnits[suggestion.id] ?? suggestion.units
            guard units > 0 else { continue }
            let item = try ledger.addRecurring(
                spaceId: space.id, kind: .gasto, name: suggestion.name,
                amountMinor: Money(units: units, currency: space.currency).minor, cycle: .mensual,
                nextDate: OnboardingPlan.nextDate(day: suggestion.day, from: now, calendar: calendar),
                categoryId: categoryId(suggestion.categoryName), createdBy: user
            )
            item.icon = suggestion.symbol
        }
        try context.save()

        defaults.set(interests.map(\.rawValue).sorted(), forKey: Self.interestsKey)
        defaults.set(true, forKey: Self.doneKey)
    }
}
