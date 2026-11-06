import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct MoneyTests {
    @Test("Pesos colombianos sin decimales y con puntos de miles")
    func formatoCOP() {
        #expect(Money(units: 1_901_100).formatted() == "$ 1.901.100")
        #expect(Money(units: 45_500).formatted() == "$ 45.500")
        #expect(Money(units: 0).formatted() == "$ 0")
        #expect(Money(units: 999).formatted() == "$ 999")
    }

    @Test("Negativos con signo menos y positivos con más cuando se pide")
    func signos() {
        #expect(Money(units: -84_300).formatted() == "− $ 84.300")
        #expect(Money(units: 2_200_000).formatted(sign: true) == "+ $ 2.200.000")
        #expect(Money(units: 0).formatted(sign: true) == "$ 0")
    }

    @Test("Los centavos de COP se redondean al peso")
    func redondeoCOP() {
        #expect(Money(minor: 4_550_049).formatted() == "$ 45.500")
        #expect(Money(minor: 4_550_050).formatted() == "$ 45.501")
        #expect(Money(minor: 99).formatted() == "$ 1")
    }

    @Test("Euros con dos decimales y coma")
    func formatoEUR() {
        #expect(Money(minor: 1250, currency: .eur).formatted() == "€ 12,50")
        #expect(Money(minor: 123_456_789, currency: .eur).formatted() == "€ 1.234.567,89")
        #expect(Money(minor: 5, currency: .eur).formatted() == "€ 0,05")
    }

    @Test("Peso chileno no tiene unidad menor")
    func formatoCLP() {
        #expect(Money(units: 15_990, currency: .clp).minor == 15_990)
        #expect(Money(units: 15_990, currency: .clp).formatted() == "$ 15.990")
    }

    @Test("Suma, resta y negación conservan la moneda")
    func aritmetica() {
        let a = Money(units: 100)
        let b = Money(units: 30)
        #expect((a + b).minor == pesos(130))
        #expect((a - b).minor == pesos(70))
        #expect((-a).minor == pesos(-100))
        #expect((b - a).isNegative)
        #expect((b - a).magnitude == Money(units: 70))
        #expect(Money.zero().isZero)
        #expect(b < a)
    }

    @Test("Moneda desconocida cae en COP")
    func monedaDesconocida() {
        #expect(Currency.from(code: "xyz") == .cop)
        #expect(Currency.from(code: "eur") == .eur)
    }

    @Test("El teclado arma pesos sin decimales")
    func tecladoCOP() {
        var input = AmountInput()
        for key in ["4", "5", "5", "0", "0"] { input.press(key) }
        #expect(input.display == "45.500")
        #expect(input.money == Money(units: 45_500))
        input.press(",")
        #expect(input.display == "45.500")
        input.deleteLast()
        #expect(input.money == Money(units: 4_550))
    }

    @Test("El teclado no deja ceros a la izquierda")
    func tecladoCeros() {
        var input = AmountInput()
        input.press("0")
        input.press("0")
        input.press("7")
        #expect(input.display == "7")
        input.deleteLast()
        #expect(input.display == "0")
        #expect(input.money.isZero)
    }

    @Test("El teclado en euros acepta coma y dos decimales")
    func tecladoEUR() {
        var input = AmountInput(currency: .eur)
        for key in ["1", "2", ",", "5", "0", "9"] { input.press(key) }
        #expect(input.display == "12,50")
        #expect(input.money.minor == 1250)
        var soloComa = AmountInput(currency: .eur)
        soloComa.press(",")
        soloComa.press("5")
        #expect(soloComa.money.minor == 50)
    }

    @Test("El teclado limita a 12 cifras")
    func tecladoLimite() {
        var input = AmountInput()
        for _ in 0..<20 { input.press("9") }
        #expect(input.text.count == 12)
    }
}

struct AmountInputEditTests {
    @Test("Editar arranca con el monto guardado")
    func desdeMonto() {
        #expect(AmountInput(minor: pesos(45_500), currency: .cop).display == "45.500")
        #expect(AmountInput(minor: pesos(45_500), currency: .cop).money.minor == pesos(45_500))
        #expect(AmountInput(minor: 1_250, currency: .eur).display == "12,5")
        #expect(AmountInput(minor: 1_205, currency: .eur).money.minor == 1_205)
        #expect(AmountInput(minor: 5, currency: .eur).display == "0,05")
        #expect(AmountInput(minor: 0, currency: .cop).display == "0")
    }
}
