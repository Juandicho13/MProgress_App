import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct SyncStatusTextTests {
    @Test("Pastilla: nada sin cuenta y cada estado con su texto")
    func pastilla() {
        #expect(SyncPill.state(signedIn: false, online: false, running: true, pending: 3, failed: 1, hasError: true) == nil)
        #expect(SyncPill.state(signedIn: true, online: true, running: false, pending: 0, failed: 0, hasError: false) == .alDia)
        #expect(SyncPill.state(signedIn: true, online: true, running: true, pending: 0, failed: 0, hasError: false) == .sincronizando)
        #expect(SyncPill.state(signedIn: true, online: true, running: false, pending: 2, failed: 0, hasError: false) == .sincronizando)
        #expect(SyncPill.state(signedIn: true, online: false, running: true, pending: 3, failed: 1, hasError: true) == .sinConexion(pending: 3))
        #expect(SyncPill.state(signedIn: true, online: true, running: false, pending: 3, failed: 1, hasError: false) == .error)
        #expect(SyncPill.state(signedIn: true, online: true, running: false, pending: 0, failed: 0, hasError: true) == .error)
        #expect(SyncPill.state(signedIn: true, online: true, running: true, pending: 0, failed: 2, hasError: true) == .sincronizando)

        #expect(SyncPill.alDia.text == "Al día")
        #expect(SyncPill.sincronizando.text == "Sincronizando…")
        #expect(SyncPill.sinConexion(pending: 3).text == "Sin conexión · 3 pendientes")
        #expect(SyncPill.sinConexion(pending: 1).text == "Sin conexión · 1 pendiente")
        #expect(SyncPill.sinConexion(pending: 0).text == "Sin conexión")
        #expect(SyncPill.error.text == "Error al sincronizar")
        #expect(SyncPill.sinConexion(pending: 2).symbol == "icloud.slash")
    }

    @Test("Hace cuánto: momento, minutos, horas, ayer y días")
    func relativo() {
        let now = fecha(2026, 11, 8, 10)
        #expect(SyncText.relative(nil, now: now) == "Todavía no")
        #expect(SyncText.relative(now.addingTimeInterval(-20), now: now) == "Hace un momento")
        #expect(SyncText.relative(now.addingTimeInterval(5), now: now) == "Hace un momento")
        #expect(SyncText.relative(now.addingTimeInterval(-120), now: now) == "Hace 2 min")
        #expect(SyncText.relative(now.addingTimeInterval(-59 * 60), now: now) == "Hace 59 min")
        #expect(SyncText.relative(now.addingTimeInterval(-3 * 3600), now: now) == "Hace 3 h")
        #expect(SyncText.relative(now.addingTimeInterval(-30 * 3600), now: now) == "Ayer")
        #expect(SyncText.relative(now.addingTimeInterval(-4 * 86400), now: now) == "Hace 4 días")
    }

    @Test("Pendientes agrupados por tipo, en singular o plural")
    func pendientes() {
        #expect(SyncText.pendingSummary([:]) == "Nada pendiente")
        #expect(SyncText.pendingSummary(["entries": 0]) == "Nada pendiente")
        #expect(SyncText.pendingSummary(["recurring": 1, "entries": 3]) == "3 movimientos, 1 pago fijo")
        #expect(SyncText.pendingSummary(["entries": 1, "products": 2, "merchant_alias": 1, "otra": 2])
                == "1 movimiento, 2 cuentas o tarjetas, 1 nombre de comercio, 2 cambios")
        #expect(SyncText.connection(online: true) == "Conectado")
        #expect(SyncText.connection(online: false) == "Sin conexión")
        #expect(SyncText.failedText(0) == nil)
        #expect(SyncText.failedText(1) == "1 cambio no subió después de 3 intentos.")
        #expect(SyncText.failedText(4) == "4 cambios no subieron después de 3 intentos.")
    }

    @Test("Reintentos: crecen y se quedan en 5 minutos")
    func espera() {
        #expect(SyncBackoff.delay(failures: 0) == 5)
        #expect(SyncBackoff.delay(failures: 1) == 5)
        #expect(SyncBackoff.delay(failures: 2) == 15)
        #expect(SyncBackoff.delay(failures: 4) == 60)
        #expect(SyncBackoff.delay(failures: 6) == 300)
        #expect(SyncBackoff.delay(failures: 50) == 300)
    }
}
