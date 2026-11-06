import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct OnboardingTests {
    @Test("Avanza paso a paso y en funciones recorre solo lo elegido")
    func pasos() {
        let model = OnboardingModel()
        #expect(model.step == .bienvenida)
        model.next()
        model.next()
        model.next()
        model.interests = [.pareja, .avisos]
        model.next()
        #expect(model.step == .funciones)
        #expect(model.slides == [.pareja, .avisos])
        #expect(!model.isLastSlide)
        model.next()
        #expect(model.isLastSlide)
        model.back()
        #expect(model.slideIndex == 0)
        model.back()
        #expect(model.step == .intereses)
    }

    @Test("Al terminar guarda sueldo, fijos elegidos e intereses")
    func terminar() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let defaults = UserDefaults(suiteName: "pruebas-onboarding")!
        defaults.removePersistentDomain(forName: "pruebas-onboarding")

        let model = OnboardingModel()
        for key in ["2", "2", "0", "0", "0", "0", "0"] { model.income.press(key) }
        model.payday = 1
        model.fixedSelected = ["gimnasio", "musica"]
        model.fixedUnits["gimnasio"] = 120_000
        model.interests = [.avisos]
        try model.finish(context: container.mainContext, defaults: defaults, now: fecha(2026, 11, 5, 22), calendar: bogota)

        let recurring = try container.mainContext.fetch(FetchDescriptor<Recurring>())
        let entries = try container.mainContext.fetch(FetchDescriptor<Entry>())
        #expect(recurring.count == 3)
        #expect(entries.count == 1)
        #expect(entries.first?.kind == .ingreso)
        #expect(entries.first?.amountMinor == pesos(2_200_000))
        let gym = recurring.first { $0.name == "Gimnasio" }
        #expect(gym?.amountMinor == pesos(120_000))
        #expect(gym.map { dia($0.nextDate) } == "2026-11-06")
        #expect(gym?.categoryId != nil)
        let sueldo = recurring.first { $0.name == "Sueldo" }
        #expect(sueldo.map { dia($0.nextDate) } == "2026-12-01")
        #expect(defaults.bool(forKey: OnboardingModel.doneKey))
        #expect(defaults.stringArray(forKey: OnboardingModel.interestsKey) == ["avisos"])
    }

    @Test("Sin sueldo no se crea ingreso")
    func sinSueldo() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = OnboardingModel()
        model.fixedSelected = []
        try model.finish(context: container.mainContext, defaults: UserDefaults(suiteName: "pruebas-sin-sueldo")!, now: fecha(2026, 11, 5), calendar: bogota)
        #expect(try container.mainContext.fetch(FetchDescriptor<Recurring>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<Entry>()).isEmpty)
    }
}
