package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Revisión del sueldo y próximos cargos plegables: los mismos casos de HomeChecksTests de iOS. */
class HomeChecksTest {
    private fun pesos(v: Long) = v * 100
    private fun ingreso(name: String, minor: Long, active: Boolean = true) =
        RecurringRecord(kind = EntryKind.INGRESO, name = name, amountMinor = minor, cycle = Cycle.Mensual, nextDate = LocalDate.of(2026, 11, 30), active = active)

    @Test fun sueldo_sospechoso() {
        val raro = ingreso("Sueldo", pesos(2))
        val lista = listOf(raro, ingreso("Arriendo cobrado", pesos(1_500_000)), ingreso("Intereses", pesos(1_000)),
            ingreso("Bono", pesos(5), active = false), ingreso("Café", pesos(3)).copy(kind = EntryKind.GASTO))
        assertEquals(listOf(raro.id), IncomeCheck.suspicious(lista, Currency.COP, emptySet()).map { it.id })
        assertTrue(IncomeCheck.suspicious(lista, Currency.COP, setOf(raro.id)).isEmpty())
        // En pesos chilenos no hay centavos: 999 es sospechoso.
        assertEquals(1, IncomeCheck.suspicious(listOf(ingreso("Sueldo", 999)), Currency.CLP, emptySet()).size)
    }

    @Test fun textos() {
        assertEquals("¿Tu sueldo es $ 2?", IncomeCheck.question("Sueldo", pesos(2), Currency.COP))
        assertEquals("¿Tu SENA apoyo es $ 2?", IncomeCheck.question("SENA apoyo", pesos(2), Currency.COP))
        assertEquals("Es $ 2.000", IncomeCheck.fixTitle(pesos(2), 1_000, Currency.COP))
        assertEquals("Es $ 2.000.000", IncomeCheck.fixTitle(pesos(2), 1_000_000, Currency.COP))
    }

    @Test fun plegar() {
        val items = (1..25).toList()
        assertEquals(listOf(1, 2, 3), UpcomingFold.visible(items, expanded = false))
        assertEquals(20, UpcomingFold.visible(items, expanded = true).size)
        assertNull(UpcomingFold.toggleTitle(3, expanded = false))
        assertEquals("Ver todos (5)", UpcomingFold.toggleTitle(5, expanded = false))
        assertEquals("Ver menos", UpcomingFold.toggleTitle(5, expanded = true))
    }

    @Test fun arregla_movimientos_con_el_sueldo() {
        val sueldo = ingreso("Sueldo", pesos(2))
        val d = LocalDate.of(2026, 11, 1)
        val enlazado = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2), occurredAt = d, name = "Pago", recurringId = sueldo.id)
        val mismoNombre = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2), occurredAt = d, name = " sueldo")
        val otroMonto = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(3), occurredAt = d, name = "Sueldo")
        val deOtroFijo = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2), occurredAt = d, name = "Sueldo", recurringId = "otro")
        val gasto = EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(2), occurredAt = d, name = "Sueldo")
        assertEquals(listOf(enlazado.id, mismoNombre.id),
            IncomeCheck.entriesToFix(listOf(enlazado, mismoNombre, otroMonto, deOtroFijo, gasto), sueldo, pesos(2)))
    }

    @Test fun movimiento_viejo_se_pregunta() {
        val sueldo = ingreso("Sueldo", pesos(2_000_000))
        val d = LocalDate.of(2026, 11, 1)
        val viejo = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2), occurredAt = d, name = "Sueldo")
        val rapido = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2_000), occurredAt = d, name = "Ingreso rápido")
        val raro = EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(7), occurredAt = d, name = "Sueldo")
        val lista = IncomeCheck.staleEntries(listOf(viejo, rapido, raro), listOf(sueldo), Currency.COP, emptySet())
        assertEquals(listOf(viejo.id), lista.map { it.entryId })
        assertEquals(pesos(2_000_000), lista.first().fixedAmountMinor)
        assertTrue(IncomeCheck.staleEntries(listOf(viejo), listOf(sueldo), Currency.COP, setOf(viejo.id)).isEmpty())
    }
}
