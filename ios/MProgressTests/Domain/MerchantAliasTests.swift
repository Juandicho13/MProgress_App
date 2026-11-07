import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct MerchantAliasTests {
    private let salidas = UUID(uuidString: "0A000000-0000-4000-8000-000000000008")!

    @Test("Normalizar: mayúsculas, sin tildes, sin números, signos ni SAS")
    func normalizar() {
        #expect(MerchantAliasMath.normalize("PEPEPOLLO SAS 123") == "PEPEPOLLO")
        #expect(MerchantAliasMath.normalize("Pepepollo S.A.S.") == "PEPEPOLLO")
        #expect(MerchantAliasMath.normalize("  Crepes & Waffles   Ltda ") == "CREPES WAFFLES")
        #expect(MerchantAliasMath.normalize("Almacén Éxito Bogotá D.C. #45") == "ALMACEN EXITO")
        #expect(MerchantAliasMath.normalize("PANADERÍA LA ESPAÑOLA CO") == "PANADERIA LA ESPANOLA")
        #expect(MerchantAliasMath.normalize("MC'DONALDS COL") == "MCDONALDS")
        #expect(MerchantAliasMath.normalize("RAPPI*RESTAURANTE-12") == "RAPPI RESTAURANTE")
    }

    @Test("Si todo es ruido no queda vacío; sin letras sí")
    func soloRuido() {
        #expect(MerchantAliasMath.normalize("SAS") == "SAS")
        #expect(MerchantAliasMath.normalize("1234 *") == "")
    }

    @Test("Busca por la misma clave o por la regla más larga con la que empieza")
    func buscar() {
        let reglas = [
            MerchantAliasRule(key: "PEPEPOLLO", name: "El Corral", categoryId: salidas),
            MerchantAliasRule(key: "EXITO", name: "Éxito", categoryId: nil),
            MerchantAliasRule(key: "EXITO EXPRESS", name: "Éxito Express", categoryId: nil),
        ]
        #expect(MerchantAliasMath.match("PEPEPOLLO SAS 123", rules: reglas)?.name == "El Corral")
        #expect(MerchantAliasMath.match("Exito Calle 80", rules: reglas)?.name == "Éxito")
        #expect(MerchantAliasMath.match("EXITO EXPRESS CRA 7", rules: reglas)?.name == "Éxito Express")
        #expect(MerchantAliasMath.match("EXITOSO", rules: reglas) == nil)
        #expect(MerchantAliasMath.match("Otro", rules: reglas) == nil)
        #expect(MerchantAliasMath.match(nil, rules: reglas) == nil)
    }

    @Test("Llenar nombre y categoría con la regla o dejar el comercio")
    func llenar() {
        let reglas = [MerchantAliasRule(key: "PEPEPOLLO", name: "El Corral", categoryId: salidas)]
        let con = MerchantAliasMath.prefill(raw: "Pepepollo Sas 99", rules: reglas)
        #expect(con.name == "El Corral")
        #expect(con.categoryId == salidas)
        let sin = MerchantAliasMath.prefill(raw: "Farmatodo", rules: reglas)
        #expect(sin.name == "Farmatodo")
        #expect(sin.categoryId == nil)
    }

    @Test("Aprende solo de lo automático con otro nombre o una categoría")
    func aprender() {
        let regla = MerchantAliasMath.learn(raw: "PEPEPOLLO SAS 123", automatic: true, name: " El Corral ", categoryId: salidas)
        #expect(regla?.key == "PEPEPOLLO")
        #expect(regla?.name == "El Corral")
        #expect(regla?.categoryId == salidas)
        #expect(MerchantAliasMath.learn(raw: "PEPEPOLLO SAS", automatic: false, name: "El Corral", categoryId: nil) == nil)
        #expect(MerchantAliasMath.learn(raw: nil, automatic: true, name: "El Corral", categoryId: nil) == nil)
        #expect(MerchantAliasMath.learn(raw: "Pepepollo Sas", automatic: true, name: "PEPEPOLLO", categoryId: nil) == nil)
        #expect(MerchantAliasMath.learn(raw: "Pepepollo Sas", automatic: true, name: "Pepepollo", categoryId: salidas)?.name == "Pepepollo")
        #expect(MerchantAliasMath.learn(raw: "Pepepollo", automatic: true, name: "  ", categoryId: salidas) == nil)
    }

    @Test("Un monto ya puesto se reemplaza con la primera tecla")
    func montoPuesto() {
        var input = AmountInput.prefilled(minor: pesos(1_250_000), currency: .cop)
        #expect(input.display == "1.250.000")
        input.press("9")
        #expect(input.display == "9")
        input.press("0")
        #expect(input.money.minor == pesos(90))
    }

    @Test("Borrar un monto ya puesto lo deja vacío; vacío no reemplaza nada")
    func borrarMontoPuesto() {
        var input = AmountInput.prefilled(minor: pesos(45_500), currency: .cop)
        input.deleteLast()
        #expect(input.text.isEmpty)
        input.press("5")
        #expect(input.display == "5")
        var vacio = AmountInput.prefilled(minor: 0, currency: .cop)
        #expect(!vacio.replacesOnNextKey)
        vacio.press("3")
        #expect(vacio.display == "3")
    }

    @Test("La coma sin decimales no borra el monto puesto")
    func comaSinDecimales() {
        var input = AmountInput.prefilled(minor: pesos(45_500), currency: .cop)
        input.press(",")
        #expect(input.display == "45.500")
        input.press("1")
        #expect(input.display == "1")
    }
}
