import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

/// Ejemplos con la forma de SMS reales de bancos colombianos. Se cambian por SMS reales en F08-03.
struct SmsParserTests {
    @Test("Compra con tarjeta de crédito, monto con decimales y comercio")
    func compraCredito() throws {
        let sms = "Bancolombia le informa Compra por $84.300,00 en EXITO CALLE 80 con T.Cred *4417. 05/11/2026 13:22. Inquietudes al 018000931987"
        let parsed = try #require(SmsParser.parse(sms))
        #expect(parsed.kind == .gasto)
        #expect(parsed.amountMinor == pesos(84_300))
        #expect(parsed.merchant == "Exito Calle 80")
        #expect(parsed.last4 == "4417")
        #expect(parsed.bank == "Bancolombia")
        #expect(!parsed.needsReview)
    }

    @Test("Compra con tarjeta terminada en")
    func terminadaEn() throws {
        let parsed = try #require(SmsParser.parse("Nu: Compra aprobada por $45.500 en NETFLIX con tu tarjeta terminada en 2210."))
        #expect(parsed.amountMinor == pesos(45_500))
        #expect(parsed.merchant == "Netflix")
        #expect(parsed.last4 == "2210")
        #expect(parsed.bank == "Nu")
    }

    @Test("Pago a una persona por Nequi queda para revisar sin tarjeta")
    func pagoNequi() throws {
        let parsed = try #require(SmsParser.parse("Nequi: Pagaste $18.000 a TAXI LIBRE el 05/11 a las 20:10."))
        #expect(parsed.kind == .gasto)
        #expect(parsed.merchant == "Taxi Libre")
        #expect(parsed.last4 == nil)
        #expect(parsed.needsReview)
    }

    @Test("Plata que llega es ingreso")
    func ingreso() throws {
        let parsed = try #require(SmsParser.parse("Davivienda: Recibiste una transferencia por $1.200.000 en tu cuenta terminada en 1032."))
        #expect(parsed.kind == .ingreso)
        #expect(parsed.amountMinor == pesos(1_200_000))
        #expect(parsed.last4 == "1032")
        #expect(parsed.merchant == nil)
    }

    @Test("Mensajes sin monto o sin compra no se registran")
    func descarta() {
        #expect(SmsParser.parse("Tu código de verificación es 123456") == nil)
        #expect(SmsParser.parse("Bancolombia: Bienvenido a la app") == nil)
    }

    @Test("Números con miles y decimales en los dos formatos")
    func numeros() {
        #expect(SmsParser.parseNumber("84.300,00", currency: .cop) == pesos(84_300))
        #expect(SmsParser.parseNumber("1.234.567", currency: .cop) == pesos(1_234_567))
        #expect(SmsParser.parseNumber("1,250.50", currency: .usd) == 125_050)
        #expect(SmsParser.parseNumber("12,5", currency: .eur) == 1_250)
        #expect(SmsParser.parseNumber("45.500", currency: .cop) == pesos(45_500))
    }
}

struct ReceiptParserTests {
    @Test("Toma el total y no el subtotal ni el IVA")
    func total() {
        let lineas = ["SUPERMERCADO LA 14", "NIT 890.123.456-7", "Arroz 1kg 4.500", "Leche 3.900", "SUBTOTAL 8.400", "IVA 1.596", "TOTAL $ 9.996", "EFECTIVO RECIBIDO 20.000", "CAMBIO 10.004"]
        #expect(ReceiptParser.total(lines: lineas) == pesos(9_996))
        #expect(ReceiptParser.merchant(lines: lineas) == "Supermercado La 14")
    }

    @Test("Total en la línea de abajo y respaldo con el monto más grande")
    func respaldo() {
        #expect(ReceiptParser.total(lines: ["Café", "TOTAL A PAGAR", "12.500"]) == pesos(12_500))
        #expect(ReceiptParser.total(lines: ["Panadería", "Pan 2.000", "Café 3.500"]) == pesos(3_500))
        #expect(ReceiptParser.total(lines: ["sin números"]) == nil)
    }
}
