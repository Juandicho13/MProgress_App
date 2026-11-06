import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct RewardsTests {
    @Test("Valor aproximado solo si se sabe cuánto vale cada punto")
    func valor() {
        let puntos = RewardRecord(name: "Puntos Colombia", kind: .puntos, balance: 12_450, valuePerPoint: Decimal(7))
        #expect(RewardMath.estimatedValueMinor(puntos, currency: .cop) == pesos(87_150))
        let millas = RewardRecord(name: "LifeMiles", kind: .millas, balance: 30_000)
        #expect(RewardMath.estimatedValueMinor(millas, currency: .cop) == nil)
        let decimal = RewardRecord(name: "X", kind: .puntos, balance: 1_000, valuePerPoint: Decimal(string: "2.5"))
        #expect(RewardMath.estimatedValueMinor(decimal, currency: .cop) == pesos(2_500))
        #expect(RewardMath.totalValueMinor([puntos, millas, decimal], currency: .cop) == pesos(89_650))
        #expect(RewardMath.balanceText(puntos) == "12.450 puntos")
    }

    @Test("Aviso de vencimiento en los próximos 60 días")
    func vencimiento() {
        let hoy = fecha(2026, 11, 6)
        var r = RewardRecord(name: "LifeMiles", kind: .millas, balance: 1, expiresAt: fecha(2026, 11, 18))
        #expect(RewardMath.expiryText(r, now: hoy, calendar: bogota) == "Vencen en 12 días")
        r.expiresAt = fecha(2026, 11, 6, 20)
        #expect(RewardMath.expiryText(r, now: hoy, calendar: bogota) == "Vencen hoy")
        r.expiresAt = fecha(2026, 11, 1)
        #expect(RewardMath.expiryText(r, now: hoy, calendar: bogota) == "Vencieron")
        r.expiresAt = fecha(2027, 6, 1)
        #expect(RewardMath.expiryText(r, now: hoy, calendar: bogota) == nil)
    }
}
