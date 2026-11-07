package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)
private fun pesos(v: Long) = v * 100

/** Quincenal, Otra y "Una vez", con las mismas pruebas de RepeatTests de iOS. */
class RepeatTest {
    private val quincena = Cycle.Quincenal(QuincenaDays.STANDARD)
    private val ancla = CycleAnchor(1, 1)
    private fun next(after: LocalDate, cycle: Cycle) = CycleMath.next(after, cycle, ancla)
    private fun otra(unit: RepeatUnit, count: String) = RepeatDraft(RepeatChoice.OTRA, unit = unit, countText = count)

    @Test fun quincenaNoviembre() {
        assertEquals(d(2026, 11, 15), next(d(2026, 11, 7), quincena))
        assertEquals(d(2026, 11, 30), next(d(2026, 11, 15), quincena))
        assertEquals(d(2026, 12, 15), next(d(2026, 11, 30), quincena))
        assertEquals(d(2026, 12, 31), next(d(2026, 12, 15), quincena))
    }

    @Test fun quincenaFebrero() {
        assertEquals(d(2027, 2, 28), next(d(2027, 2, 15), quincena))
        assertEquals(d(2027, 3, 15), next(d(2027, 2, 28), quincena))
        assertEquals(d(2028, 2, 29), next(d(2028, 2, 15), quincena))
        val treinta = Cycle.Quincenal(QuincenaDays(15, 30))
        assertEquals(d(2027, 2, 28), next(d(2027, 2, 15), treinta))
        assertEquals(d(2027, 1, 30), next(d(2027, 1, 15), treinta))
        assertEquals(d(2027, 2, 15), next(d(2027, 1, 30), treinta))
    }

    @Test fun quincenaOtrosDias() {
        val cinco = Cycle.Quincenal(QuincenaDays(5, 20))
        assertEquals(d(2026, 11, 5), next(d(2026, 11, 1), cinco))
        assertEquals(d(2026, 11, 20), next(d(2026, 11, 12), cinco))
        assertEquals(d(2026, 12, 5), next(d(2026, 11, 25), cinco))
        val desorden = Cycle.Quincenal(QuincenaDays(28, 10))
        assertEquals(d(2026, 11, 28), next(d(2026, 11, 12), desorden))
        assertEquals(d(2026, 12, 10), next(d(2026, 11, 28), desorden))
    }

    @Test fun quincenaDosVecesAlMes() {
        val dates = CycleMath.occurrences(d(2026, 11, 15), d(2027, 1, 31), quincena, ancla)
        assertEquals(listOf(d(2026, 11, 15), d(2026, 11, 30), d(2026, 12, 15), d(2026, 12, 31), d(2027, 1, 15), d(2027, 1, 31)), dates)
        assertEquals(pesos(4_000_000), FixedMath.monthlyEquivalent(pesos(2_000_000), quincena))
    }

    @Test fun quincenaConFin() {
        val item = RecurringRecord(kind = EntryKind.INGRESO, name = "Sueldo", amountMinor = pesos(1_500_000), cycle = quincena, nextDate = d(2026, 11, 15),
            totalCount = 3, paidCount = 0)
        assertEquals(listOf(d(2026, 11, 15), d(2026, 11, 30), d(2026, 12, 15)), RecurringMath.occurrences(item, d(2027, 6, 1)))
        val conFecha = item.copy(totalCount = null, endDate = d(2026, 12, 20))
        assertEquals(listOf(d(2026, 11, 15), d(2026, 11, 30), d(2026, 12, 15)), RecurringMath.occurrences(conFecha, d(2027, 6, 1)))
    }

    @Test fun quincenaAddPlan() {
        val plan = AddPlan.decide(quincena, d(2026, 11, 15), d(2026, 11, 15))
        assertEquals(d(2026, 11, 15), plan.entryDate)
        assertEquals(d(2026, 11, 30), plan.recurringNext)
        assertEquals(d(2026, 11, 15), QuincenaMath.onOrAfter(d(2026, 11, 7), QuincenaDays.STANDARD))
        assertEquals(d(2026, 11, 30), QuincenaMath.onOrAfter(d(2026, 11, 30), QuincenaDays.STANDARD))
        assertEquals(d(2027, 2, 28), QuincenaMath.onOrAfter(d(2027, 2, 28), QuincenaDays.STANDARD))
    }

    @Test fun quincenaGuardado() {
        val cycle = Cycle.Quincenal(QuincenaDays(5, 20))
        assertEquals("quincenal", cycle.raw)
        assertEquals(5, cycle.firstDay)
        assertEquals(20, cycle.secondDay)
        assertEquals(cycle, Cycle.from("quincenal", firstDay = 5, secondDay = 20))
        assertEquals(quincena, Cycle.from("quincenal"))
        assertNull(Cycle.Mensual.firstDay)
        assertEquals(Cycle.Mensual, Cycle.from("mensual", intervalMonths = 1))
    }

    @Test fun quincenaDias() {
        assertEquals("15 y último día", QuincenaDays.STANDARD.title)
        assertEquals("15 y 30", QuincenaDays(15, 30).title)
        assertEquals("10 y 28", QuincenaDays(28, 10).title)
        assertEquals(listOf(1, 2, 28, 29, 30, 31), QuincenaDays.secondChoices(15))
        assertFalse(31 in QuincenaDays.secondChoices(20))
        assertEquals(20, QuincenaDays.suggestedSecond(5))
        assertEquals(31, QuincenaDays.suggestedSecond(16))
        assertEquals(10, QuincenaDays.suggestedSecond(25))
        assertEquals(QuincenaDays(5, 31), QuincenaDays.STANDARD.withFirst(5))
        assertEquals(QuincenaDays(20, 5), QuincenaDays.STANDARD.withFirst(20))
        assertEquals(28, QuincenaDays.STANDARD.withFirst(40).first)
        assertEquals(QuincenaDays.STANDARD, QuincenaDays.STANDARD.withSecond(20))
        assertEquals(QuincenaDays(15, 30), QuincenaDays.STANDARD.withSecond(30))
        assertTrue(QuincenaDays.STANDARD.isValid)
        assertFalse(QuincenaDays(15, 20).isValid)
    }

    @Test fun unaVez() {
        assertEquals("Una vez", Cycle.Puntual.title)
        assertEquals(listOf("Una vez", "Semanal", "Quincenal", "Mensual", "Otra"), RepeatChoice.entries.map { it.title })
        assertEquals("Quincenal", quincena.title)
        assertEquals("Cada 2 semanas", Cycle.CadaDias(14).title)
        assertEquals("Cada 2 años", Cycle.CadaMeses(24).title)
        assertEquals("Quincenal · 15 y último día", FixedMath.scheduleText(quincena, d(2026, 11, 15), false, d(2026, 11, 7)))
    }

    @Test fun otraMapeo() {
        assertEquals(Cycle.CadaDias(10), otra(RepeatUnit.DIAS, "10").cycle)
        assertEquals(Cycle.Semanal, otra(RepeatUnit.DIAS, "7").cycle)
        assertEquals(Cycle.CadaDias(15), otra(RepeatUnit.DIAS, "15").cycle)
        assertEquals(Cycle.Semanal, otra(RepeatUnit.SEMANAS, "1").cycle)
        assertEquals(Cycle.CadaDias(14), otra(RepeatUnit.SEMANAS, "2").cycle)
        assertEquals(Cycle.Mensual, otra(RepeatUnit.MESES, "1").cycle)
        assertEquals(Cycle.CadaMeses(3), otra(RepeatUnit.MESES, "3").cycle)
        assertEquals(Cycle.Anual, otra(RepeatUnit.MESES, "12").cycle)
        assertEquals(Cycle.Anual, otra(RepeatUnit.ANIOS, "1").cycle)
        assertEquals(Cycle.CadaMeses(24), otra(RepeatUnit.ANIOS, "2").cycle)
        assertEquals(Cycle.Puntual, RepeatDraft(RepeatChoice.UNA_VEZ).cycle)
        assertEquals(Cycle.Semanal, RepeatDraft(RepeatChoice.SEMANAL).cycle)
        assertEquals(quincena, RepeatDraft(RepeatChoice.QUINCENAL).cycle)
        assertEquals(Cycle.Mensual, RepeatDraft(RepeatChoice.MENSUAL).cycle)
    }

    @Test fun otraValidacion() {
        assertTrue(otra(RepeatUnit.MESES, "24").isValid)
        assertFalse(otra(RepeatUnit.MESES, "25").isValid)
        assertEquals("Escribe de 1 a 24 meses", otra(RepeatUnit.MESES, "25").hint)
        assertEquals("Escribe de 1 a 365 días", otra(RepeatUnit.DIAS, "0").hint)
        assertEquals("Escribe de 1 a 52 semanas", otra(RepeatUnit.SEMANAS, "53").hint)
        assertEquals("Escribe de 1 a 2 años", otra(RepeatUnit.ANIOS, "3").hint)
        assertFalse(otra(RepeatUnit.DIAS, "").isValid)
        assertEquals(Cycle.CadaDias(365), otra(RepeatUnit.DIAS, "366").cycle)
        assertEquals("¿Quincenal? Usa Quincenal para 15 y 30", otra(RepeatUnit.DIAS, "15").tip)
        assertNull(otra(RepeatUnit.DIAS, "16").tip)
        assertTrue(RepeatDraft(RepeatChoice.MENSUAL).isValid)
    }

    @Test fun otraAtajos() {
        var draft = RepeatDraft(RepeatChoice.OTRA)
        assertEquals(RepeatPreset.BIMESTRAL, draft.preset)
        draft = draft.apply(RepeatPreset.TRIMESTRAL)
        assertEquals(Cycle.CadaMeses(3), draft.cycle)
        assertEquals(RepeatPreset.TRIMESTRAL, draft.preset)
        assertEquals("Trimestral", draft.title)
        assertEquals(Cycle.Anual, draft.apply(RepeatPreset.ANUAL).cycle)
        assertEquals(listOf("Cada 2 meses", "Trimestral", "Semestral", "Anual"), RepeatPreset.entries.map { it.title })
        assertEquals("Se repite cada 3 meses, el próximo es el 7 feb 2027", otra(RepeatUnit.MESES, "3").summary(d(2027, 2, 7), d(2026, 11, 7)))
        assertEquals("Se repite cada semana, el próximo es el 14 nov", otra(RepeatUnit.SEMANAS, "1").summary(d(2026, 11, 14), d(2026, 11, 7)))
        assertNull(otra(RepeatUnit.MESES, "30").summary(null, d(2026, 11, 7)))
        assertEquals("Cada 10 días", otra(RepeatUnit.DIAS, "10").title)
        assertEquals("Cada 2 años", otra(RepeatUnit.ANIOS, "2").title)
    }

    @Test fun desdeCiclo() {
        listOf(Cycle.Puntual, Cycle.Semanal, Cycle.Mensual, Cycle.Anual, Cycle.CadaDias(10), Cycle.CadaDias(14), Cycle.CadaMeses(3), Cycle.CadaMeses(24),
            Cycle.Quincenal(QuincenaDays(5, 20))).forEach { assertEquals(it, RepeatDraft.of(it).cycle) }
        assertEquals(RepeatChoice.OTRA, RepeatDraft.of(Cycle.Anual).choice)
        assertEquals(RepeatUnit.SEMANAS, RepeatDraft.of(Cycle.CadaDias(14)).unit)
        assertEquals(RepeatUnit.ANIOS, RepeatDraft.of(Cycle.CadaMeses(24)).unit)
    }
}
