import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct QuickActionsTests {
    @Test("Por defecto: Gasto, Ingreso y Pagos fijos en Inicio")
    func porDefecto() {
        let layout = QuickActionLayout(stored: "")
        #expect(layout.pinned == [.gasto, .ingreso, .fijos])
        #expect(layout.order.count == QuickActionKind.allCases.count)
    }

    @Test("Guardar y leer da lo mismo")
    func idaYVuelta() {
        var layout = QuickActionLayout.standard
        layout.togglePin(.ingreso)
        layout.togglePin(.ahorro)
        let read = QuickActionLayout(stored: layout.stored)
        #expect(read == layout)
        #expect(read.pinned == [.gasto, .fijos, .ahorro])
    }

    @Test("Nunca más de 3 fijadas: la nueva reemplaza la última")
    func limite() {
        var layout = QuickActionLayout.standard
        layout.togglePin(.limites)
        #expect(layout.pinned == [.gasto, .ingreso, .limites])
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
        #expect(layout.pinned == [.fijos, .gasto, .ingreso])
        let first = layout.unpinned[0]
        layout.moveUnpinned(from: [0], to: 2)
        #expect(layout.unpinned[1] == first)
    }

    @Test("Ya no están Gasto fijo, Sueldo o fijo, Pago anual ni Historial")
    func sinRepetidas() {
        let raws = Set(QuickActionKind.allCases.map(\.rawValue))
        #expect(raws.isDisjoint(with: ["fijo", "sueldo", "anual", "historial"]))
        #expect(QuickActionKind.allCases.map(\.title).contains("Pagos fijos"))
    }

    @Test("Quien tenía fijadas las que se quitaron sigue viendo 3 en Inicio")
    func migraFijadas() {
        let viejo = QuickActionLayout(stored: "gasto,ingreso,fijo,sueldo,anual,fijos,rapido|gasto,ingreso,fijo")
        #expect(viejo.pinned == [.gasto, .ingreso, .fijos])
        let todas = QuickActionLayout(stored: "fijo,sueldo,anual|sueldo,anual,fijo")
        #expect(todas.pinned == QuickActionLayout.standard.pinned)
        let mezcla = QuickActionLayout(stored: "ahorro,fijos,historial|historial,ahorro,fijos")
        #expect(mezcla.pinned == [.ahorro, .fijos, .gasto])
        #expect(Set(mezcla.order) == Set(QuickActionKind.allCases))
    }

    @Test("Si la persona dejó menos de 3 a propósito, se respeta")
    func respetaMenos() {
        let layout = QuickActionLayout(stored: "gasto,ahorro|ahorro")
        #expect(layout.pinned == [.ahorro])
    }
}
