import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct LockTimeoutTests {
    @Test("Inmediatamente pide desbloquear siempre al volver")
    func inmediatamente() {
        #expect(LockTimeout.requiresAuth(backgroundedAt: 100, now: 100, delay: .inmediatamente))
        #expect(LockTimeout.requiresAuth(backgroundedAt: 100, now: 101, delay: .inmediatamente))
    }

    @Test("Con 30 segundos o 1 minuto solo pide desbloquear si pasó ese tiempo")
    func conEspera() {
        #expect(!LockTimeout.requiresAuth(backgroundedAt: 100, now: 129.9, delay: .treintaSegundos))
        #expect(LockTimeout.requiresAuth(backgroundedAt: 100, now: 130, delay: .treintaSegundos))
        #expect(!LockTimeout.requiresAuth(backgroundedAt: 100, now: 159, delay: .unMinuto))
        #expect(LockTimeout.requiresAuth(backgroundedAt: 100, now: 160, delay: .unMinuto))
    }

    @Test("Arranque en frío y reloj que retrocede siempre bloquean")
    func frio() {
        #expect(LockTimeout.requiresAuth(backgroundedAt: nil, now: 5, delay: .unMinuto))
        #expect(LockTimeout.requiresAuth(backgroundedAt: 500, now: 10, delay: .unMinuto))
    }

    @Test("Con el tiempo fuera ya medido")
    func medido() {
        #expect(LockTimeout.requiresAuth(elapsedSeconds: nil, delay: .treintaSegundos))
        #expect(!LockTimeout.requiresAuth(elapsedSeconds: 12, delay: .treintaSegundos))
        #expect(LockTimeout.requiresAuth(elapsedSeconds: 61, delay: .unMinuto))
        #expect(LockTimeout.requiresAuth(elapsedSeconds: -1, delay: .unMinuto))
        #expect(LockTimeout.requiresAuth(elapsedSeconds: 0, delay: .inmediatamente))
    }

    @Test("Opciones, textos y lo guardado")
    func opciones() {
        #expect(LockDelay.allCases.map(\.title) == ["Inmediatamente", "Después de 30 segundos", "Después de 1 minuto"])
        #expect(LockDelay.from(seconds: nil) == .inmediatamente)
        #expect(LockDelay.from(seconds: 30) == .treintaSegundos)
        #expect(LockDelay.from(seconds: 60) == .unMinuto)
        #expect(LockDelay.from(seconds: 45) == .inmediatamente)
        #expect(LockDelay.storageKey == "seguridad.bloquearTras")
    }
}
