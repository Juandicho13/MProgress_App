import Foundation
import Testing
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

struct GuideTests {
    private var vacio: GuideSnapshot { GuideSnapshot() }

    private var completo: GuideSnapshot {
        GuideSnapshot(hasIncome: true, hasFixedExpense: true, hasExpense: true, hasInstitution: true, autoCaptureConfigured: true,
                      hasBudget: true, hasGoal: true, notificationsAllowed: true, hasReminder: true, lockEnabled: true, signedIn: true)
    }

    @Test("Los ocho pasos salen siempre en el mismo orden y sin nada hecho al empezar")
    func ordenYVacio() {
        let steps = Guide.steps(vacio)
        #expect(steps.map(\.id) == [.primerosDatos, .bancos, .automatico, .limites, .ahorro, .avisos, .bloqueo, .cuenta])
        #expect(steps.count == 8)
        #expect(Guide.doneCount(steps) == 0)
        #expect(Guide.progressText(steps) == "0 de 8")
        #expect(steps.first?.title == "Anota tu ingreso, tus fijos y tu primer gasto")
    }

    @Test("El primer paso necesita ingreso, un gasto fijo y un gasto anotado")
    func primerPaso() {
        var s = GuideSnapshot(hasIncome: true, hasExpense: true)
        #expect(Guide.steps(s)[0].done == false)
        #expect(Guide.nextPart(s) == .fijo)
        #expect(Guide.firstStepSubtitle(s) == "Te falta: tus fijos")
        s.hasIncome = false
        #expect(Guide.nextPart(s) == .ingreso)
        #expect(Guide.firstStepSubtitle(s) == "Te falta: tu ingreso y tus fijos")
        #expect(Guide.firstStepSubtitle(vacio) == "Te falta: tu ingreso, tus fijos y tu primer gasto")
        s = GuideSnapshot(hasIncome: true, hasFixedExpense: true, hasExpense: true)
        #expect(Guide.steps(s)[0].done)
        #expect(Guide.nextPart(s) == nil)
        #expect(Guide.parts(s).allSatisfy { $0.done })
        #expect(Guide.firstStepSubtitle(s) == "Ingreso, fijos y primer gasto anotados")
    }

    @Test("Los avisos cuentan solo con permiso y al menos un pago que avisa")
    func avisos() {
        #expect(Guide.steps(GuideSnapshot(notificationsAllowed: true))[5].done == false)
        #expect(Guide.steps(GuideSnapshot(hasReminder: true))[5].done == false)
        #expect(Guide.steps(GuideSnapshot(notificationsAllowed: true, hasReminder: true))[5].done)
    }

    @Test("Un pago fijo avisa con el general prendido o con su aviso propio, nunca con Sin aviso")
    func pagoQueAvisa() {
        #expect(Guide.hasReminder(modes: [], generalEnabled: true) == false)
        #expect(Guide.hasReminder(modes: [nil], generalEnabled: true))
        #expect(Guide.hasReminder(modes: [nil, .general], generalEnabled: false) == false)
        #expect(Guide.hasReminder(modes: [.ninguno, .personalizado], generalEnabled: false))
        #expect(Guide.hasReminder(modes: [.ninguno], generalEnabled: true) == false)
    }

    @Test("Cada paso se marca con su dato")
    func cadaPaso() {
        let s = GuideSnapshot(hasInstitution: true, autoCaptureConfigured: true, hasBudget: true, hasGoal: true, lockEnabled: true, signedIn: true)
        let done = Guide.steps(s).filter(\.done).map(\.id)
        #expect(done == [.bancos, .automatico, .limites, .ahorro, .bloqueo, .cuenta])
        #expect(Guide.progressText(Guide.steps(s)) == "6 de 8")
        #expect(Guide.progress(Guide.steps(s)) == 0.75)
    }

    @Test("Se ven los 3 primeros pendientes y el resto va en una línea")
    func pendientesYResto() {
        let s = GuideSnapshot(hasIncome: true, hasFixedExpense: true, hasExpense: true, hasInstitution: true, hasBudget: true)
        let steps = Guide.steps(s)
        #expect(Guide.progressText(steps) == "3 de 8")
        #expect(Guide.visiblePendingSteps(steps).map(\.id) == [.automatico, .ahorro, .avisos])
        #expect(Guide.moreText(steps) == "Y 2 más: bloqueo y cuenta en la nube")
        let todos = Guide.steps(vacio)
        #expect(Guide.moreText(todos) == "Y 5 más: límites, meta de ahorro, avisos, bloqueo y cuenta en la nube")
        let casi = GuideSnapshot(hasIncome: true, hasFixedExpense: true, hasExpense: true, hasInstitution: true, autoCaptureConfigured: true,
                                 hasBudget: true, hasGoal: true, notificationsAllowed: true, hasReminder: true)
        #expect(Guide.visiblePendingSteps(Guide.steps(casi)).map(\.id) == [.bloqueo, .cuenta])
        #expect(Guide.moreText(Guide.steps(casi)) == nil)
    }

    @Test("Oculta, lista o celebración una sola vez")
    func visibilidad() {
        let parcial = Guide.steps(GuideSnapshot(hasBudget: true))
        let listo = Guide.steps(completo)
        #expect(Guide.visibility(parcial, dismissed: false, celebrated: false) == .checklist)
        #expect(Guide.visibility(parcial, dismissed: true, celebrated: false) == .hidden)
        #expect(Guide.visibility(listo, dismissed: false, celebrated: false) == .celebration)
        #expect(Guide.visibility(listo, dismissed: false, celebrated: true) == .hidden)
        #expect(Guide.visibility(listo, dismissed: true, celebrated: false) == .hidden)
        #expect(Guide.progressText(listo) == "8 de 8")
        #expect(Guide.visiblePendingSteps(listo).isEmpty)
    }

    @Test("Listas en español con comas y la y final")
    func unir() {
        #expect(Guide.joined([]) == "")
        #expect(Guide.joined(["a"]) == "a")
        #expect(Guide.joined(["a", "b"]) == "a y b")
        #expect(Guide.joined(["a", "b", "c"]) == "a, b y c")
    }

    @Test("Ningún texto de los primeros pasos usa la raya")
    func sinRaya() {
        let textos = Guide.steps(vacio).flatMap { [$0.title, $0.shortTitle] }
            + [Guide.title, Guide.celebrationTitle, Guide.celebrationText, Guide.hideQuestion, Guide.hideMessage, Guide.firstStepSubtitle(vacio)]
        #expect(textos.allSatisfy { !$0.contains("\u{2014}") && !$0.contains("\u{2013}") })
    }
}
