import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct CurrencyCatalogTests {
    @Test("Las monedas de siempre no cambian")
    func lasDeSiempre() {
        #expect(Currency.from(code: "COP").minorDigits == 2)
        #expect(Currency.from(code: "COP").shownDigits == 0)
        #expect(Currency.from(code: "clp").minorPerUnit == 1)
        #expect(Currency.from(code: "ARS").shownDigits == 0)
        #expect(Currency.from(code: "USD").symbol == "US$")
        #expect(Money(units: 1_901_100).formatted() == "$ 1.901.100")
        #expect(Money(minor: 123_456, currency: .usd).formatted() == "US$ 1.234,56")
        #expect(Money(minor: 4_550_050).formatted() == "$ 45.501")
    }

    @Test("Todas las activas, con decimales de ISO")
    func todas() {
        #expect(Currency.all.count == CurrencyCatalog.isoCodes.count)
        #expect(Currency.all.count > 150)
        #expect(Currency.from(code: "JPY").minorDigits == 0)
        #expect(Currency.from(code: "KWD").minorDigits == 3)
        #expect(Currency.from(code: "BRL").minorDigits == 2)
        #expect(Currency.known(code: "XYZ") == nil)
        #expect(Currency.from(code: "XYZ") == .cop)
        #expect(Currency.all.allSatisfy { !$0.name.isEmpty && !$0.symbol.isEmpty })
    }

    @Test("Formato de yen y dinar kuwaití")
    func formatoJPYyKWD() {
        let jpy = Currency.from(code: "JPY")
        #expect(Money(units: 1_500_000, currency: jpy).formatted() == "¥ 1.500.000")
        let kwd = Currency.from(code: "KWD")
        #expect(Money(minor: 1_234_567, currency: kwd).formatted() == "KD 1.234,567")
        #expect(Money(minor: -5, currency: kwd).formatted() == "− KD 0,005")
    }

    @Test("Escribir montos con 0 y 3 decimales")
    func teclado() {
        var yen = AmountInput(currency: .from(code: "JPY"))
        for key in ["1", "2", ",", "5"] { yen.press(key) }
        #expect(yen.money.minor == 125)
        var dinar = AmountInput(currency: .from(code: "KWD"))
        for key in ["7", ",", "1", "2", "3", "4"] { dinar.press(key) }
        #expect(dinar.money.minor == 7_123)
        #expect(AmountInput(minor: 7_120, currency: .from(code: "KWD")).display == "7,12")
    }

    @Test("Guardado: el código manda y lo viejo se sigue leyendo")
    func codable() throws {
        let old = #"{"code":"COP","symbol":"$","name":"Peso colombiano","minorDigits":2,"shownDigits":0}"#
        let decoded = try JSONDecoder().decode(Currency.self, from: Data(old.utf8))
        #expect(decoded == .cop)
        #expect(decoded.shownDigits == 0)
        let again = try JSONDecoder().decode(Currency.self, from: JSONEncoder().encode(Currency.from(code: "JPY")))
        #expect(again.minorDigits == 0)
    }

    @Test("Buscar por código o nombre sin tildes")
    func buscar() {
        #expect(Currency.search("usd").first?.code == "USD")
        #expect(Currency.search("dolar").contains { $0.code == "CAD" })
        #expect(Currency.search("peso colombiano").map(\.code) == ["COP"])
        #expect(Currency.search("").count == Currency.all.count)
        #expect(Currency.search("zzzz").isEmpty)
    }

    @Test("Más usadas y orden alfabético")
    func orden() {
        #expect(Currency.popular.map(\.code) == ["COP", "USD", "EUR", "MXN", "CLP", "PEN", "ARS", "BRL", "GBP", "CAD"])
        let names = Currency.all.map { HistoryMath.normalize($0.name) }
        #expect(names == names.sorted())
    }

    @Test("Banderas")
    func banderas() {
        #expect(Currency.cop.flag == "🇨🇴")
        #expect(Currency.eur.flag == "🇪🇺")
        #expect(Currency.from(code: "XOF").flag == nil)
    }
}
