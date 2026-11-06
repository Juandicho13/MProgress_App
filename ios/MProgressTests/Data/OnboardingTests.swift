import Foundation
import SwiftData
import Testing
@testable import MProgress

@MainActor
struct OnboardingTests {
    @Test("Orden: ingreso, bancos, fijos, fechas, intereses y funciones con solo lo elegido")
    func pasos() {
        let model = OnboardingModel()
        #expect(model.step == .bienvenida)
        model.next()
        #expect(model.step == .ingreso)
        model.next()
        #expect(model.step == .bancos)
        model.next()
        #expect(model.step == .fijos)
        model.next()
        #expect(model.step == .fechas)
        model.next()
        #expect(model.step == .intereses)
        model.interests = [.pareja, .avisos]
        model.next()
        #expect(model.step == .funciones)
        #expect(model.slides == [.pareja, .avisos])
        model.next()
        #expect(model.isLastSlide)
        model.back()
        model.back()
        #expect(model.step == .intereses)
    }

    @Test("Sin fijos ni sueldo se salta el paso de fechas")
    func saltaFechas() {
        let model = OnboardingModel()
        for index in model.fixed.indices { model.fixed[index].selected = false }
        model.step = .fijos
        model.next()
        #expect(model.step == .intereses)
        model.back()
        #expect(model.step == .fijos)
    }

    @Test("Agregar otro fijo y Todo más tarde")
    func agregarOtro() {
        let model = OnboardingModel()
        model.addCustomFixed(name: "  Internet ", units: 95_000)
        model.addCustomFixed(name: "", units: 1)
        #expect(model.selectedFixed.last?.name == "Internet")
        model.step = .fechas
        model.setDay(5, for: model.selectedFixed.last!.id)
        model.allLater()
        #expect(model.step == .intereses)
        #expect(model.selectedFixed.allSatisfy { $0.later && $0.day == nil })
    }

    @Test("Al terminar crea bancos, tarjetas, sueldo con su cuenta y fijos con fecha, tarjeta o sin fecha")
    func terminar() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "pruebas-onboarding")!
        defaults.removePersistentDomain(forName: "pruebas-onboarding")

        let model = OnboardingModel()
        for key in ["2", "2", "0", "0", "0", "0", "0"] { model.income.press(key) }
        model.payday = 1
        model.addBank(name: "Bancolombia", colorHex: "FDDA24")
        model.addBank(name: "Efectivo", colorHex: "3A3F47")
        let bank = model.banks[0]
        model.addProduct(PlannedProduct(kind: .credito, name: "Crédito Oro", last4: "4417"), to: bank.id)
        model.addProduct(PlannedProduct(kind: .debito, name: "Débito", last4: "12345678"), to: bank.id)
        let cuenta = model.banks[0].products[0]
        let oro = model.banks[0].products[1]
        model.incomeProductId = cuenta.id

        for index in model.fixed.indices { model.fixed[index].selected = ["gimnasio", "musica"].contains(model.fixed[index].id) }
        model.setUnits(120_000, for: "gimnasio")
        model.setDay(6, for: "gimnasio")
        model.setProduct(oro.id, for: "gimnasio")
        model.setLater(true, for: "musica")
        model.addCustomFixed(name: "Internet", units: 95_000)
        model.interests = [.avisos]
        try model.finish(context: context, defaults: defaults, now: fecha(2026, 11, 5, 22), calendar: bogota)

        let products = try context.fetch(FetchDescriptor<Product>())
        #expect(products.count == 4)
        let realOro = try #require(products.first { $0.name == "Crédito Oro" })
        #expect(realOro.last4 == "4417")
        let debito = try #require(products.first { $0.kind == .debito })
        #expect(debito.last4 == nil)
        let realCuenta = try #require(products.first { $0.kind == .cuenta })
        #expect(debito.parentProductId == realCuenta.id)
        #expect(products.contains { $0.kind == .efectivo })

        let recurring = try context.fetch(FetchDescriptor<Recurring>())
        #expect(recurring.count == 4)
        let sueldo = try #require(recurring.first { $0.name == "Sueldo" })
        #expect(sueldo.productId == realCuenta.id)
        #expect(dia(sueldo.nextDate) == "2026-12-01")
        let gym = try #require(recurring.first { $0.name == "Gimnasio" })
        #expect(gym.amountMinor == pesos(120_000))
        #expect(dia(gym.nextDate) == "2026-11-06")
        #expect(gym.productId == realOro.id)
        #expect(!gym.dateUnset)
        let musica = try #require(recurring.first { $0.name == "Música" })
        #expect(musica.dateUnset)
        #expect(musica.record.active == false)
        #expect(try #require(recurring.first { $0.name == "Internet" }).dateUnset)

        let entries = try context.fetch(FetchDescriptor<Entry>())
        #expect(entries.count == 1)
        #expect(entries.first?.productId == realCuenta.id)
        #expect(defaults.bool(forKey: OnboardingModel.doneKey))
        #expect(defaults.stringArray(forKey: OnboardingModel.interestsKey) == ["avisos"])
    }

    @Test("Quitar un banco borra sus referencias")
    func quitarBanco() {
        let model = OnboardingModel()
        model.addBank(name: "Nu", colorHex: "A68CFF")
        let cuenta = model.banks[0].products[0]
        model.incomeProductId = cuenta.id
        model.setProduct(cuenta.id, for: "gimnasio")
        model.removeBank(model.banks[0].id)
        #expect(model.incomeProductId == nil)
        #expect(model.fixed.first { $0.id == "gimnasio" }?.productId == nil)
    }

    @Test("Sin sueldo ni fijos no se crea nada")
    func sinSueldo() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = OnboardingModel()
        for index in model.fixed.indices { model.fixed[index].selected = false }
        try model.finish(context: container.mainContext, defaults: UserDefaults(suiteName: "pruebas-sin-sueldo")!, now: fecha(2026, 11, 5), calendar: bogota)
        #expect(try container.mainContext.fetch(FetchDescriptor<Recurring>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<Entry>()).isEmpty)
    }
}
