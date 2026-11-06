import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct QuickAddMathTests {
    @Test("El monto dictado pasa a unidades mínimas y se rechaza lo inválido")
    func monto() {
        #expect(QuickAddMath.minor(fromUnits: 20_000, currency: .cop) == pesos(20_000))
        #expect(QuickAddMath.minor(fromUnits: 12.5, currency: .eur) == 1_250)
        #expect(QuickAddMath.minor(fromUnits: 0, currency: .cop) == nil)
        #expect(QuickAddMath.minor(fromUnits: -5, currency: .cop) == nil)
        #expect(QuickAddMath.minor(fromUnits: .infinity, currency: .cop) == nil)
        #expect(QuickAddMath.minor(fromUnits: 1e15, currency: .cop) == nil)
    }

    @Test("Línea de la isla: − $ 84.300 · te quedan $ 1.901.100")
    func textos() {
        let amount = QuickAddMath.amountText(kind: .gasto, amountMinor: pesos(84_300), currency: .cop)
        let remaining = QuickAddMath.remainingText(pesos(1_901_100), currency: .cop)
        #expect(QuickAddMath.liveLine(amountText: amount, remainingText: remaining) == "− $ 84.300 · te quedan $ 1.901.100")
        #expect(QuickAddMath.amountText(kind: .ingreso, amountMinor: pesos(50_000), currency: .cop) == "+ $ 50.000")
        #expect(QuickAddMath.remainingText(-pesos(20_000), currency: .cop) == "te pasaste $ 20.000")
    }

    @Test("Nombre y productos que se ofrecen")
    func nombreYProductos() {
        #expect(QuickAddMath.name(kind: .gasto, concept: "  almuerzo ") == "Almuerzo")
        #expect(QuickAddMath.name(kind: .gasto, concept: nil) == "Gasto rápido")
        #expect(QuickAddMath.name(kind: .ingreso, concept: "") == "Ingreso rápido")
        #expect(QuickAddMath.offers(.credito, for: .gasto))
        #expect(!QuickAddMath.offers(.bolsillo, for: .gasto))
        #expect(QuickAddMath.offers(.bolsillo, for: .ingreso))
        #expect(!QuickAddMath.offers(.debito, for: .ingreso))
        #expect(QuickAddMath.offers(.efectivo, for: .ingreso))
    }
}
