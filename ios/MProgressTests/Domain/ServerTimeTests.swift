import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct ServerTimeTests {
    @Test("Lee las fechas de Postgres con microsegundos y zona")
    func leer() throws {
        let base = try #require(ServerTime.parse("2026-11-08T10:00:00Z"))
        #expect(base.timeIntervalSince1970 == 1_794_132_000)
        let micro = try #require(ServerTime.parse("2026-11-08T10:00:00.123456+00:00"))
        #expect(abs(micro.timeIntervalSince(base) - 0.123456) < 0.000001)
        let bogota = try #require(ServerTime.parse("2026-11-08 05:00:00-05:00"))
        #expect(bogota == base)
        #expect(ServerTime.parse("2026-11-08T10:00:00.5") == base.addingTimeInterval(0.5))
        #expect(ServerTime.parse("ayer") == nil)
    }

    @Test("Escribe con 6 decimales en UTC y lo que escribe lo vuelve a leer igual")
    func escribir() throws {
        let date = try #require(ServerTime.parse("2026-11-08T10:00:00.654321Z"))
        let text = ServerTime.format(date)
        #expect(text.hasPrefix("2026-11-08T10:00:00.65432"))
        #expect(text.hasSuffix("Z"))
        let again = try #require(ServerTime.parse(text))
        #expect(abs(again.timeIntervalSince(date)) < 0.000002)
    }

    @Test("Un sobre viaja en JSON con las fechas de Supabase")
    func sobre() throws {
        let json = #"{"id":"0a000000-0000-4000-8000-000000000001","space_id":"0a000000-0000-4000-8000-000000000002","entity":"entries","payload":"abc","changed_at":"2026-11-08T10:00:00.1+00:00","updated_at":"2026-11-08T10:00:01.123456+00:00","deleted_at":null}"#
        let row = try ServerTime.decoder().decode(SyncEnvelope.self, from: Data(json.utf8))
        #expect(row.entity == "entries")
        #expect(row.deletedAt == nil)
        #expect(row.updatedAt.map(ServerTime.format)?.hasPrefix("2026-11-08T10:00:01.12345") == true)
    }
}
