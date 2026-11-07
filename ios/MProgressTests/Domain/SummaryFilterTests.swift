import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct SummaryFilterTests {
    let mercado = UUID()
    let salidas = UUID()
    let propia = UUID()
    let hoy = fecha(2026, 11, 10)

    var movimientos: [EntryRecord] {
        [
            EntryRecord(kind: .ingreso, amountMinor: pesos(2_200_000), occurredAt: fecha(2026, 11, 1), name: "Sueldo"),
            EntryRecord(kind: .gasto, amountMinor: pesos(80_000), occurredAt: fecha(2026, 11, 2), name: "Éxito", categoryId: mercado),
            EntryRecord(kind: .gasto, amountMinor: pesos(120_000), occurredAt: fecha(2026, 11, 5), name: "Ara", categoryId: mercado),
            EntryRecord(kind: .gasto, amountMinor: pesos(150_000), occurredAt: fecha(2026, 11, 6), name: "El Corral", categoryId: salidas),
            // Categoría propia que creó la persona: sale igual que las de la app.
            EntryRecord(kind: .gasto, amountMinor: pesos(300_000), occurredAt: fecha(2026, 10, 6), name: "Veterinaria", categoryId: propia),
            EntryRecord(kind: .gasto, amountMinor: pesos(10_000), occurredAt: fecha(2026, 11, 7), name: "Sin nada"),
        ]
    }

    @Test("Las pastillas van de la categoría que más gasta a la que menos, con las propias y sin la vacía")
    func pastillas() {
        let doce = SummaryPeriod.meses(12).interval(now: hoy, calendar: bogota)
        #expect(SummaryMath.activeCategories(movimientos, in: doce) == [propia, mercado, salidas])
        let mes = SummaryPeriod.esteMes.interval(now: hoy, calendar: bogota)
        #expect(SummaryMath.activeCategories(movimientos, in: mes) == [mercado, salidas])
    }

    @Test("Tocar alterna y Todas es el conjunto vacío")
    func alternar() {
        var elegidas = Set<UUID>()
        elegidas = SummaryFilter.toggle(elegidas, mercado)
        elegidas = SummaryFilter.toggle(elegidas, salidas)
        #expect(elegidas == [mercado, salidas])
        elegidas = SummaryFilter.toggle(elegidas, mercado)
        #expect(elegidas == [salidas])
        #expect(SummaryFilter.effective([], chips: [mercado]) == nil)
    }

    @Test("Varias categorías filtran juntas y las que no tienen pastilla en el periodo no cuentan")
    func varias() {
        let mes = SummaryPeriod.esteMes.interval(now: hoy, calendar: bogota)
        let chips = SummaryMath.activeCategories(movimientos, in: mes)
        let filtro = SummaryFilter.effective([mercado, salidas, propia], chips: chips)
        #expect(filtro == [mercado, salidas])
        let visibles = SummaryMath.filter(movimientos, in: mes, categories: filtro)
        #expect(visibles.reduce(0) { $0 + $1.amountMinor } == pesos(350_000))
        #expect(visibles.allSatisfy { $0.kind == .gasto })
        #expect(SummaryFilter.effective([propia], chips: chips) == nil)
    }

    @Test("Título de la tarjeta según cuántas categorías hay elegidas")
    func titulo() {
        #expect(SummaryFilter.spendTitle([]) == "Ingresos y gastos")
        #expect(SummaryFilter.spendTitle(["Mercado"]) == "Gastos de Mercado")
        #expect(SummaryFilter.spendTitle(["Mercado", "Salidas"]) == "Gastos de Mercado y Salidas")
        #expect(SummaryFilter.spendTitle(["Mercado", "Salidas", "Mascotas"]) == "Gastos de 3 categorías")
    }
}
