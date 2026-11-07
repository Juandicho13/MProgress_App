import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

/// Lee el catálogo real: ios/MProgress/Resources/CardCatalog.json, al lado de esta carpeta de pruebas.
private func catalogo() throws -> CardCatalog {
    #if canImport(MProgress)
    // En Xcode se lee del paquete de la app: leer la carpeta del proyecto desde el simulador pide permiso
    // de disco externo y deja la prueba esperando.
    if let bundled = CardCatalog.bundled() { return bundled }
    #endif
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Domain
        .deletingLastPathComponent()  // MProgressTests
        .deletingLastPathComponent()  // ios
        .appendingPathComponent("MProgress/Resources/CardCatalog.json")
    return try CardCatalog.decode(Data(contentsOf: url))
}

struct CardCatalogTests {
    @Test("El catálogo se lee y trae la usura del mes")
    func lee() throws {
        let c = try catalogo()
        #expect(c.version == 1)
        #expect(c.usuraMonth == "2026-11")
        #expect(c.usuraRateEA == Decimal(string: "28.34")!)
        #expect(c.usuraNote == "Tope legal de este mes, revisa tu extracto")
        #expect(c.banks.count == 19)
        #expect(c.banks.reduce(0) { $0 + $1.cards.count } == 133)
    }

    @Test("Ids únicos, fuente por banco y sin raya larga")
    func integridad() throws {
        let c = try catalogo()
        let ids = c.banks.flatMap { $0.cards.map(\.id) }
        #expect(Set(ids).count == ids.count)
        #expect(Set(c.banks.map(\.id)).count == c.banks.count)
        for bank in c.banks {
            #expect(bank.source.hasPrefix("https://"))
            #expect(bank.sources.contains(bank.source))
            #expect(bank.checkedAt == "2026-11-07")
            for card in bank.cards {
                #expect(card.id.hasPrefix(bank.id + "-"))
                #expect((card.handlingFeeCOP ?? 0) >= 0)
            }
        }
        #if !canImport(MProgress)
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("MProgress/Resources/CardCatalog.json")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("\u{2014}"))
        #endif
    }

    @Test("Busca el banco sin tildes, mayúsculas ni 'Banco de'")
    func buscaBanco() throws {
        let c = try catalogo()
        let casos: [(String, String)] = [
            ("Bancolombia", "bancolombia"), ("BANCOLOMBIA", "bancolombia"), ("Banco de Bogota", "banco-de-bogota"),
            ("Banco de Bogotá", "banco-de-bogota"), ("Bogotá", "banco-de-bogota"), ("Itaú", "banco-de-bogota"),
            ("Colpatria", "davibank"), ("Scotiabank Colpatria", "davibank"), ("Davibank", "davibank"),
            ("Nu", "nu"), ("Nubank", "nu"), ("nu colombia", "nu"), ("Davivienda", "davivienda"), ("BBVA", "bbva"),
            ("bbva colombia", "bbva"), ("AV Villas", "av-villas"), ("Banco Popular", "popular"), ("Caja Social", "caja-social"),
            ("Falabella", "falabella"), ("CMR Falabella", "falabella"), ("Rappi", "rappicard"), ("RappiPay", "rappicard"),
            ("Tarjeta Éxito", "tuya"), ("Carulla", "tuya"), ("Lulo Bank", "lulo"), ("Banco Agrario", "agrario"),
            ("GNB Sudameris", "gnb-sudameris"), ("Pichincha", "pichincha"), ("Olímpica", "serfinanza"),
            ("Serfinanza", "serfinanza"), ("Finandina", "finandina"), ("Banco de Occidente", "occidente"),
        ]
        for (texto, id) in casos {
            #expect(c.bank(matching: texto)?.id == id, "\(texto)")
        }
        #expect(c.bank(matching: "Nequi") == nil)
        #expect(c.bank(matching: "Banco") == nil)
        #expect(c.bank(matching: "") == nil)
        #expect(c.bank(matching: "Nueva") == nil)
        #expect(c.cards(forBank: "Nequi").isEmpty)
    }

    @Test("Tarjetas de Bancolombia con franquicia, puntos y cuota")
    func bancolombia() throws {
        let c = try catalogo()
        let cards = c.cards(forBank: "bancolombia")
        #expect(cards.count == 21)
        let clasica = try #require(cards.first { $0.id == "bancolombia-visa-clasica" })
        #expect(clasica.name == "Visa Clásica")
        #expect(clasica.franchise == .visa)
        #expect(clasica.tier == "clasica")
        #expect(clasica.rewards == "Puntos Colombia")
        #expect(clasica.handlingFeeMinor == 3_290_000)
        #expect(clasica.subtitle == "Visa · Puntos Colombia")
        let libre = try #require(cards.first { $0.name == "Amex Libre" })
        #expect(libre.franchise == .amex)
        #expect(libre.handlingFeeMinor == 0)
        #expect(cards.contains { $0.rewards == "LifeMiles" })
        #expect(CardFranchise.amex.title == "American Express")
    }

    @Test("Bancos sin verificar y tarjeta por id")
    func otros() throws {
        let c = try catalogo()
        #expect(c.bank(matching: "GNB")?.cards.isEmpty == true)
        #expect(c.bank(matching: "GNB")?.verified == false)
        #expect(c.bank(matching: "Nu")?.cards.first?.franchise == .mastercard)
        let found = try #require(c.card(id: "davibank-lifemiles-visa-infinite"))
        #expect(found.bank.id == "davibank")
        #expect(found.card.rewards == "LifeMiles")
        #expect(c.card(id: "no-existe") == nil)
        #expect(CardCatalog.tokens("Banco de Bogotá S.A.") == ["bogota"])
        #expect(CardCatalog.tokens("Banco de Colombia").isEmpty)
    }
}
