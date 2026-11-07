package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Primeros pasos de Inicio: los mismos casos de GuideTests de iOS. */
class GuideTest {
    private val vacio = GuideSnapshot()
    private val completo = GuideSnapshot(hasIncome = true, hasFixedExpense = true, hasExpense = true, hasInstitution = true, autoCaptureConfigured = true,
        hasBudget = true, hasGoal = true, notificationsAllowed = true, hasReminder = true, lockEnabled = true, signedIn = true)

    @Test fun orden_y_vacio() {
        val steps = Guide.steps(vacio)
        assertEquals(listOf(GuideStepId.PRIMEROS_DATOS, GuideStepId.BANCOS, GuideStepId.AUTOMATICO, GuideStepId.LIMITES, GuideStepId.AHORRO,
            GuideStepId.AVISOS, GuideStepId.BLOQUEO, GuideStepId.CUENTA), steps.map { it.id })
        assertEquals(0, Guide.doneCount(steps))
        assertEquals("0 de 8", Guide.progressText(steps))
        assertEquals("Anota tu ingreso, tus fijos y tu primer gasto", steps.first().title)
    }

    @Test fun primer_paso() {
        var s = GuideSnapshot(hasIncome = true, hasExpense = true)
        assertFalse(Guide.steps(s)[0].done)
        assertEquals(GuidePartKind.FIJO, Guide.nextPart(s))
        assertEquals("Te falta: tus fijos", Guide.firstStepSubtitle(s))
        s = s.copy(hasIncome = false)
        assertEquals(GuidePartKind.INGRESO, Guide.nextPart(s))
        assertEquals("Te falta: tu ingreso y tus fijos", Guide.firstStepSubtitle(s))
        assertEquals("Te falta: tu ingreso, tus fijos y tu primer gasto", Guide.firstStepSubtitle(vacio))
        s = GuideSnapshot(hasIncome = true, hasFixedExpense = true, hasExpense = true)
        assertTrue(Guide.steps(s)[0].done)
        assertNull(Guide.nextPart(s))
        assertTrue(Guide.parts(s).all { it.done })
        assertEquals("Ingreso, fijos y primer gasto anotados", Guide.firstStepSubtitle(s))
    }

    @Test fun avisos_necesitan_permiso_y_un_pago_que_avise() {
        assertFalse(Guide.steps(GuideSnapshot(notificationsAllowed = true))[5].done)
        assertFalse(Guide.steps(GuideSnapshot(hasReminder = true))[5].done)
        assertTrue(Guide.steps(GuideSnapshot(notificationsAllowed = true, hasReminder = true))[5].done)
    }

    @Test fun pago_que_avisa() {
        assertFalse(Guide.hasReminder(emptyList(), generalEnabled = true))
        assertTrue(Guide.hasReminder(listOf(AlertMode.GENERAL), generalEnabled = true))
        assertFalse(Guide.hasReminder(listOf(AlertMode.GENERAL), generalEnabled = false))
        assertTrue(Guide.hasReminder(listOf(AlertMode.NINGUNO, AlertMode.PERSONALIZADO), generalEnabled = false))
        assertFalse(Guide.hasReminder(listOf(AlertMode.NINGUNO), generalEnabled = true))
    }

    @Test fun cada_paso_con_su_dato() {
        val s = GuideSnapshot(hasInstitution = true, autoCaptureConfigured = true, hasBudget = true, hasGoal = true, lockEnabled = true, signedIn = true)
        assertEquals(listOf(GuideStepId.BANCOS, GuideStepId.AUTOMATICO, GuideStepId.LIMITES, GuideStepId.AHORRO, GuideStepId.BLOQUEO, GuideStepId.CUENTA),
            Guide.steps(s).filter { it.done }.map { it.id })
        assertEquals("6 de 8", Guide.progressText(Guide.steps(s)))
        assertEquals(0.75f, Guide.progress(Guide.steps(s)), 0.0001f)
    }

    @Test fun pendientes_y_resto() {
        val steps = Guide.steps(GuideSnapshot(hasIncome = true, hasFixedExpense = true, hasExpense = true, hasInstitution = true, hasBudget = true))
        assertEquals("3 de 8", Guide.progressText(steps))
        assertEquals(listOf(GuideStepId.AUTOMATICO, GuideStepId.AHORRO, GuideStepId.AVISOS), Guide.visiblePendingSteps(steps).map { it.id })
        assertEquals("Y 2 más: bloqueo y cuenta en la nube", Guide.moreText(steps))
        assertEquals("Y 5 más: límites, meta de ahorro, avisos, bloqueo y cuenta en la nube", Guide.moreText(Guide.steps(vacio)))
        val casi = completo.copy(lockEnabled = false, signedIn = false)
        assertEquals(listOf(GuideStepId.BLOQUEO, GuideStepId.CUENTA), Guide.visiblePendingSteps(Guide.steps(casi)).map { it.id })
        assertNull(Guide.moreText(Guide.steps(casi)))
    }

    @Test fun visibilidad() {
        val parcial = Guide.steps(GuideSnapshot(hasBudget = true))
        val listo = Guide.steps(completo)
        assertEquals(GuideVisibility.CHECKLIST, Guide.visibility(parcial, dismissed = false, celebrated = false))
        assertEquals(GuideVisibility.HIDDEN, Guide.visibility(parcial, dismissed = true, celebrated = false))
        assertEquals(GuideVisibility.CELEBRATION, Guide.visibility(listo, dismissed = false, celebrated = false))
        assertEquals(GuideVisibility.HIDDEN, Guide.visibility(listo, dismissed = false, celebrated = true))
        assertEquals(GuideVisibility.HIDDEN, Guide.visibility(listo, dismissed = true, celebrated = false))
        assertEquals("8 de 8", Guide.progressText(listo))
        assertTrue(Guide.visiblePendingSteps(listo).isEmpty())
    }

    @Test fun unir_en_espanol() {
        assertEquals("", Guide.joined(emptyList()))
        assertEquals("a", Guide.joined(listOf("a")))
        assertEquals("a y b", Guide.joined(listOf("a", "b")))
        assertEquals("a, b y c", Guide.joined(listOf("a", "b", "c")))
    }

    @Test fun sin_raya() {
        val textos = Guide.steps(vacio).flatMap { listOf(it.title, it.shortTitle) } +
            listOf(Guide.TITLE, Guide.CELEBRATION_TITLE, Guide.CELEBRATION_TEXT, Guide.HIDE_QUESTION, Guide.HIDE_MESSAGE, Guide.firstStepSubtitle(vacio))
        assertTrue(textos.none { it.contains('—') || it.contains('–') })
    }
}
