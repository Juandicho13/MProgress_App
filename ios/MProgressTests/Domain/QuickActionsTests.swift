import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct QuickActionsTests {
    @Test("Por defecto: Gasto, Ingreso y Fijo en Inicio")
    func porDefecto() {
        let layout = QuickActionLayout(stored: "")
        #expect(layout.pinned == [.gasto, .ingreso, .fijo])
        #expect(layout.order.count == QuickActionKind.allCases.count)
    }

    @Test("Guardar y leer da lo mismo")
    func idaYVuelta() {
        var layout = QuickActionLayout.standard
        layout.togglePin(.ingreso)
        layout.togglePin(.ahorro)
        let read = QuickActionLayout(stored: layout.stored)
        #expect(read == layout)
        #expect(read.pinned == [.gasto, .fijo, .ahorro])
    }

    @Test("Nunca más de 3 fijadas: la nueva reemplaza la última")
    func limite() {
        var layout = QuickActionLayout.standard
        layout.togglePin(.historial)
        #expect(layout.pinned == [.gasto, .ingreso, .historial])
    }

    @Test("Ignora acciones desconocidas y agrega las nuevas al final")
    func tolerante() {
        let layout = QuickActionLayout(stored: "ahorro,vieja,gasto|ahorro,ahorro,vieja")
        #expect(layout.order.prefix(2) == [.ahorro, .gasto])
        #expect(layout.pinned == [.ahorro])
        #expect(Set(layout.order) == Set(QuickActionKind.allCases))
    }

    @Test("Reordenar fijadas y no fijadas")
    func mover() {
        var layout = QuickActionLayout.standard
        layout.movePinned(from: [2], to: 0)
        #expect(layout.pinned == [.fijo, .gasto, .ingreso])
        let first = layout.unpinned[0]
        layout.moveUnpinned(from: [0], to: 2)
        #expect(layout.unpinned[1] == first)
    }
}
