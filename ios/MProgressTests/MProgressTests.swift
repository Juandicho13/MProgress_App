import Testing
@testable import MProgress

struct DesignTests {
    @Test("La barra tiene cinco pestañas en orden")
    func pestanas() {
        #expect(AppTab.allCases.map(\.title) == ["Inicio", "Resumen", "Dinero", "Calendario", "Ajustes"])
    }

    @Test("Sin transparencia el vidrio es sólido y con mucha es el más transparente")
    func vidrio() {
        #expect(GlassLevel.ninguna.tintOpacity == 1.0)
        #expect(GlassLevel.ninguna.blurRadius == 0)
        #expect(GlassLevel.mucha.tintOpacity < GlassLevel.normal.tintOpacity)
    }

    @Test("Las cifras van más anchas que el texto")
    func tipografia() {
        #expect(TextStyle.cifraHeroe.width == 112.5)
        #expect(TextStyle.cuerpo.width == 100)
        #expect(TextStyle.allCases.allSatisfy { $0.lineHeight >= $0.size })
    }
}
