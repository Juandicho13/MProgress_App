import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct CategoryFormTests {
    @Test("30 íconos sin repetir y el de por defecto está entre ellos")
    func iconos() {
        #expect(CategoryForm.icons.count == 30)
        #expect(Set(CategoryForm.icons.map(\.symbol)).count == 30)
        #expect(CategoryForm.icons.contains { $0.symbol == CategoryForm.defaultIcon })
    }

    @Test("Nombre limpio, vacío y repetido sin tildes ni mayúsculas")
    func validar() {
        let mascotas = UUID()
        let existing: [(id: UUID, name: String)] = [(UUID(), "Mercado"), (mascotas, "Mascotas")]
        #expect(CategoryForm.cleanName("  Viajes   de  pareja ") == "Viajes de pareja")
        #expect(CategoryForm.cleanName(String(repeating: "a", count: 40)).count == CategoryForm.maxLength)
        #expect(CategoryForm.problem(name: "   ", existing: existing) == .empty)
        #expect(CategoryForm.problem(name: "MASCOTÁS", existing: existing) == .duplicate)
        #expect(CategoryForm.problem(name: "Mascotas", existing: existing, editing: mascotas) == nil)
        #expect(CategoryForm.problem(name: "Viajes", existing: existing) == nil)
    }

    @Test("Sugiere un ícono por el nombre y ordena antes de Otros")
    func sugerirYOrden() {
        #expect(CategoryForm.suggestedIcon(for: "Mascotas") == "pawprint")
        #expect(CategoryForm.suggestedIcon(for: "Viajes con Mari") == "airplane")
        #expect(CategoryForm.suggestedIcon(for: "Xyz") == nil)
        #expect(CategoryForm.nextSort(existing: [1, 2, 14, 99]) == 15)
        #expect(CategoryForm.nextSort(existing: [1, 14, 20, 99]) == 21)
        #expect(CategoryForm.nextSort(existing: [98, 99]) == 98)
        #expect(CategoryForm.nextSort(existing: []) == 15)
    }
}
