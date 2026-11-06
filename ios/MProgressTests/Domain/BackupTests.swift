import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct BackupTests {
    let space = UUID()
    let comida = UUID()
    let tarjeta = UUID()

    var snapshot: BackupSnapshot {
        let now = fecha(2026, 11, 6)
        var s = BackupSnapshot(createdAt: now)
        s.categories = [.init(id: comida, ownerSpaceId: nil, name: "Comida", icon: "fork.knife", colorHex: "FF6B2C", sort: 0, lastUsedAt: nil, createdAt: now, updatedAt: now, deletedAt: nil)]
        s.products = [.init(id: tarjeta, spaceId: space, institutionId: UUID(), parentProductId: nil, kindRaw: "credito", name: "Oro", last4: "4417",
                            balanceMinor: 0, balanceAt: now, creditLimitMinor: nil, cutDay: nil, dueDay: 20, rateEA: Decimal(string: "8.25"),
                            lockedUntil: nil, inWallet: true, hidden: false, createdAt: now, updatedAt: now, deletedAt: nil)]
        s.entries = [
            .init(id: UUID(), spaceId: space, kindRaw: "gasto", amountMinor: pesos(84_300), occurredAt: fecha(2026, 11, 3), name: "Mercado, Éxito",
                  merchant: nil, icon: nil, categoryId: comida, productId: tarjeta, recurringId: nil, paidBy: nil, methodRaw: "applePay",
                  sourceRaw: "manual", needsReview: false, notes: "Dijo \"gracias\"", createdBy: nil, createdAt: now, updatedAt: now, deletedAt: nil),
            .init(id: UUID(), spaceId: space, kindRaw: "ingreso", amountMinor: pesos(2_200_000), occurredAt: fecha(2026, 11, 1), name: "Sueldo",
                  merchant: nil, icon: nil, categoryId: nil, productId: nil, recurringId: nil, paidBy: nil, methodRaw: nil,
                  sourceRaw: "manual", needsReview: false, notes: nil, createdBy: nil, createdAt: now, updatedAt: now, deletedAt: nil),
            .init(id: UUID(), spaceId: space, kindRaw: "gasto", amountMinor: 1, occurredAt: fecha(2026, 11, 2), name: "Borrado",
                  merchant: nil, icon: nil, categoryId: nil, productId: nil, recurringId: nil, paidBy: nil, methodRaw: nil,
                  sourceRaw: "manual", needsReview: false, notes: nil, createdBy: nil, createdAt: now, updatedAt: now, deletedAt: now),
        ]
        return s
    }

    @Test("Ida y vuelta: codificar y decodificar deja todo igual, decimales incluidos")
    func idaYVuelta() throws {
        let original = snapshot
        let data = try BackupCodec.encode(original)
        let back = try BackupCodec.decode(data)
        #expect(back == original)
        #expect(back.products.first?.rateEA == Decimal(string: "8.25"))
        #expect(back.summary == "2 movimientos, 0 pagos fijos y 0 bancos")
    }

    @Test("Rechaza archivos que no son de MProgress o de una versión más nueva")
    func rechaza() throws {
        #expect(throws: BackupCodec.DecodeError.self) { try BackupCodec.decode(Data("{\"hola\":1}".utf8)) }
        var nuevo = snapshot
        nuevo.version = 99
        let data = try BackupCodec.encode(nuevo)
        #expect(throws: BackupCodec.DecodeError.self) { try BackupCodec.decode(data) }
    }

    @Test("CSV con signo, sin borrados y con comas y comillas escapadas")
    func csv() {
        let text = BackupCodec.csv(snapshot, currency: .cop, calendar: bogota)
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0] == "Fecha,Tipo,Nombre,Categoría,Monto,Moneda,Pagado con,Notas")
        #expect(lines[1] == "2026-11-03,Gasto,\"Mercado, Éxito\",Comida,-84300,COP,Oro 4417,\"Dijo \"\"gracias\"\"\"")
        #expect(lines[2] == "2026-11-01,Ingreso,Sueldo,,2200000,COP,,")
        #expect(BackupCodec.plainAmount(-1_250, currency: .eur) == "-12.50")
        #expect(BackupCodec.fileName(date: fecha(2026, 11, 6), calendar: bogota) == "MProgress 2026-11-06.mprogress")
    }
}
