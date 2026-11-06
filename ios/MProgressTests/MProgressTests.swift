import Testing
@testable import MProgress

struct DesignTests {
    @Test("La barra tiene cinco pestañas en orden")
    func pestanas() {
        #expect(AppTab.allCases.map(\.title) == ["Inicio", "Resumen", "Dinero", "Calendario", "Ajustes"])
    }

    @Test("El vidrio arranca como iOS y conserva los valores guardados")
    func vidrio() {
        #expect(GlassLevel.allCases.first == .normal)
        #expect(GlassLevel.normal.title == "Como iOS")
        #expect(GlassLevel(rawValue: "ninguna")?.title == "Sólida")
        #expect(GlassLevel(rawValue: "mucha") != nil)
    }

    @Test("Las cifras van más anchas que el texto")
    func tipografia() {
        #expect(TextStyle.cifraHeroe.width == 112.5)
        #expect(TextStyle.cuerpo.width == 100)
        #expect(TextStyle.allCases.allSatisfy { $0.lineHeight >= $0.size })
    }
}
