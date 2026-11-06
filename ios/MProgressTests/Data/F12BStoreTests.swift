import Foundation
import SwiftData
import Testing
@testable import MProgress

/// PLAN_F12B Paso 2 en la base: cuotas, puntos por tarjeta, varios efectivos, avisos en dos niveles y respaldo.
@MainActor
struct F12BStoreTests {
    let container: ModelContainer
    let space: Space
    let ledger: LedgerStore
    let money: MoneyStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        space = try Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
        ledger = LedgerStore(context: container.mainContext, calendar: bogota)
        money = MoneyStore(context: container.mainContext)
    }

    @Test("Tres cuotas: cada pago suma una y la última lo deja terminado; deshacer la devuelve")
    func cuotas() throws {
        let celular = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Celular", amountMinor: pesos(150_000),
                                              cycle: .mensual, nextDate: fecha(2026, 11, 10), totalCount: 3)
        try ledger.markPaid(celular, on: fecha(2026, 11, 10))
        #expect(celular.paidCount == 1)
        #expect(celular.endText(calendar: bogota) == "Cuota 2 de 3")
        try ledger.markPaid(celular, on: fecha(2026, 12, 10))
        #expect(celular.active)
        let previous = celular.nextDate
        let last = try ledger.markPaid(celular, on: fecha(2027, 1, 10))
        #expect(celular.paidCount == 3)
        #expect(!celular.active)
        #expect(ledger.finishedByEnd(celular))
        #expect(celular.endText(calendar: bogota) == "Terminado")
        try ledger.undoPaid(celular, entry: last, previousNext: previous, wasActive: true)
        #expect(celular.paidCount == 2)
        #expect(celular.active)
        #expect(!ledger.finishedByEnd(celular))
    }

    @Test("Con fecha final, el pago que deja la siguiente fecha afuera lo termina")
    func fechaFinal() throws {
        let curso = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Curso", amountMinor: pesos(80_000),
                                            cycle: .mensual, nextDate: fecha(2026, 12, 15), endDate: fecha(2026, 12, 31))
        try ledger.markPaid(curso, on: fecha(2026, 12, 15))
        #expect(!curso.active)
        #expect(ledger.finishedByEnd(curso))
    }

    @Test("Editar el fin: más cuotas a uno terminado lo vuelve a activar")
    func extender() throws {
        let item = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Moto", amountMinor: pesos(400_000),
                                           cycle: .mensual, nextDate: fecha(2027, 1, 5), totalCount: 2, paidCount: 2)
        #expect(!item.active)
        try ledger.updateRecurring(item, kind: .gasto, name: "Moto", amountMinor: pesos(400_000), cycle: .mensual,
                                   nextDate: item.nextDate, productId: nil, categoryId: nil, active: false, totalCount: 6)
        #expect(item.active)
        #expect(item.endText(calendar: bogota) == "Cuota 3 de 6")
    }

    @Test("Puntos: el gasto con la tarjeta suma, editar recalcula y borrar resta")
    func puntos() throws {
        let banco = try money.addInstitution(spaceId: space.id, name: "Bancolombia")
        let programa = try money.saveReward(nil, spaceId: space.id, name: "Puntos Colombia", kind: .puntos, balance: 1_000,
                                            valuePerPoint: nil, expiresAt: nil, productId: nil, colorHex: nil)
        var draft = MoneyStore.ProductDraft(kind: .credito, name: "Oro", last4: "4417")
        draft.rewardProgramId = programa.id
        draft.pointsPerThousand = 2
        let tarjeta = try money.addProduct(spaceId: space.id, institutionId: banco.id, draft: draft)
        #expect(programa.productId == tarjeta.id)

        let gasto = try ledger.addEntry(spaceId: space.id, kind: .gasto, amountMinor: pesos(84_300), name: "Mercado", productId: tarjeta.id)
        #expect(programa.balance == 1_168)
        try ledger.update(gasto, kind: .gasto, amountMinor: pesos(10_000), name: "Mercado", occurredAt: gasto.occurredAt,
                          categoryId: nil, icon: nil, notes: nil, productId: tarjeta.id)
        #expect(programa.balance == 1_020)
        try ledger.softDelete(gasto)
        #expect(programa.balance == 1_000)
        try ledger.restore(gasto)
        #expect(programa.balance == 1_020)

        let ingreso = try ledger.addEntry(spaceId: space.id, kind: .ingreso, amountMinor: pesos(50_000), name: "Reembolso", productId: tarjeta.id)
        #expect(programa.balance == 1_020)
        _ = ingreso
    }

    @Test("Día del mes: pagado este mes anota hoy y sigue el mes que viene; sin pagar empieza el mes que viene")
    func diaDelMes() throws {
        let ahora = fecha(2026, 11, 6, 15)
        let pagado = AddEntryModel(kind: .gasto, cycle: .mensual)
        pagado.name = "Internet"
        pagado.amount.press("9")
        pagado.pickDay(2, now: ahora, calendar: bogota)
        #expect(dia(pagado.date) == "2026-11-02")
        let entry = try pagado.save(context: container.mainContext, spaceId: space.id, now: ahora, calendar: bogota)
        #expect(entry.map { dia($0.occurredAt) } == "2026-11-02")
        #expect(entry?.recurringId != nil)

        let sinPagar = AddEntryModel(kind: .gasto, cycle: .mensual)
        sinPagar.pickDay(2, now: ahora, calendar: bogota)
        sinPagar.setPaidThisMonth(false, now: ahora, calendar: bogota)
        #expect(dia(sinPagar.date) == "2026-12-02")

        let delTreintaYUno = AddEntryModel(kind: .gasto, cycle: .mensual)
        delTreintaYUno.name = "Arriendo"
        delTreintaYUno.amount.press("5")
        delTreintaYUno.pickDay(31, now: ahora, calendar: bogota)
        #expect(dia(delTreintaYUno.date) == "2026-11-30")
        try delTreintaYUno.save(context: container.mainContext, spaceId: space.id, now: ahora, calendar: bogota)
        let arriendo = try container.mainContext.fetch(FetchDescriptor<Recurring>()).first { $0.name == "Arriendo" }
        #expect(arriendo?.anchorDay == 31)
        #expect(arriendo.map { dia($0.nextDate) } == "2026-11-30")
    }

    @Test("Varios efectivos con nombre propio quedan en el mismo grupo Efectivo")
    func efectivos() throws {
        let billetera = try money.cash(spaceId: space.id)
        let casa = try money.addCash(spaceId: space.id, name: "Casa", balanceMinor: pesos(200_000))
        let alcancia = try money.addCash(spaceId: space.id, name: "Alcancía")
        #expect(casa.institutionId == billetera.institutionId)
        #expect(alcancia.institutionId == billetera.institutionId)
        #expect(try money.institutions(spaceId: space.id).count == 1)
        try money.transfer(spaceId: space.id, from: casa, to: alcancia, amountMinor: pesos(50_000), on: .now.addingTimeInterval(5))
        let products = try money.products(spaceId: space.id).map(\.record)
        let transfers = try money.transfers(spaceId: space.id).map(\.record)
        #expect(MoneyCalculator.currentBalance(of: alcancia.record, products: products, entries: [], transfers: transfers) == pesos(50_000))
    }

    @Test("Aviso por pago fijo: guarda el modo y viaja en el respaldo con cuotas y puntos")
    func respaldo() throws {
        let planning = PlanningStore(context: container.mainContext)
        let renta = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Renta", amountMinor: pesos(2_275_000),
                                            cycle: .mensual, nextDate: fecha(2026, 12, 1), endDate: fecha(2027, 6, 30))
        let moto = try ledger.addRecurring(spaceId: space.id, kind: .gasto, name: "Moto", amountMinor: pesos(400_000),
                                           cycle: .mensual, nextDate: fecha(2026, 12, 5), totalCount: 12, paidCount: 4)
        try planning.setReminder(spaceId: space.id, recurringId: renta.id, daysBefore: 3, atMinutes: 540, sameDay: false, mode: .ninguno)
        let banco = try money.addInstitution(spaceId: space.id, name: "Nu")
        let programa = try money.saveReward(nil, spaceId: space.id, name: "LifeMiles", kind: .millas, balance: 0,
                                            valuePerPoint: nil, expiresAt: nil, productId: nil, colorHex: nil)
        var draft = MoneyStore.ProductDraft(kind: .credito, name: "Nu", last4: "2210")
        draft.rewardProgramId = programa.id
        draft.pointsPerThousand = Decimal(string: "1.5")
        _ = try money.addProduct(spaceId: space.id, institutionId: banco.id, draft: draft)

        let data = try BackupCodec.encode(BackupService.snapshot(context: container.mainContext))
        let target = try Persistence.makeContainer(inMemory: true)
        try BackupService.restore(BackupService.read(data), context: target.mainContext)
        let restored = target.mainContext

        let fijos = try LedgerStore(context: restored, calendar: bogota).recurring(spaceId: space.id)
        #expect(fijos.first { $0.id == renta.id }.map { dia($0.endDate ?? .distantPast) } == "2027-06-30")
        #expect(fijos.first { $0.id == moto.id }?.totalCount == 12)
        #expect(fijos.first { $0.id == moto.id }?.paidCount == 4)
        #expect(try PlanningStore(context: restored).reminder(for: renta.id)?.mode == .ninguno)
        let tarjeta = try MoneyStore(context: restored).products(spaceId: space.id).first { $0.kind == .credito }
        #expect(tarjeta?.rewardProgramId == programa.id)
        #expect(tarjeta?.pointsPerThousand == Decimal(string: "1.5"))
    }
}
