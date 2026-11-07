package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Barra de filtros del Resumen: los mismos casos de SummaryFilterTests de iOS. */
class SummaryFilterTest {
    private fun pesos(v: Long) = v * 100
    private val mercado = "mercado"; private val salidas = "salidas"; private val propia = "propia"
    private val hoy = LocalDate.of(2026, 11, 10)
    private val movimientos = listOf(
        EntryRecord(kind = EntryKind.INGRESO, amountMinor = pesos(2_200_000), occurredAt = LocalDate.of(2026, 11, 1), name = "Sueldo"),
        EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(80_000), occurredAt = LocalDate.of(2026, 11, 2), name = "Éxito", categoryId = mercado),
        EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(120_000), occurredAt = LocalDate.of(2026, 11, 5), name = "Ara", categoryId = mercado),
        EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(150_000), occurredAt = LocalDate.of(2026, 11, 6), name = "El Corral", categoryId = salidas),
        // Categoría propia que creó la persona: sale igual que las de la app.
        EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(300_000), occurredAt = LocalDate.of(2026, 10, 6), name = "Veterinaria", categoryId = propia),
        EntryRecord(kind = EntryKind.GASTO, amountMinor = pesos(10_000), occurredAt = LocalDate.of(2026, 11, 7), name = "Sin nada"),
    )

    @Test fun pastillas_de_mayor_a_menor() {
        assertEquals(listOf(propia, mercado, salidas), SummaryFilter.chips(SummaryFilter.inPeriod(movimientos, hoy, 12)))
        assertEquals(listOf(mercado, salidas), SummaryFilter.chips(SummaryFilter.inPeriod(movimientos, hoy, 1)))
    }

    @Test fun alternar_y_todas() {
        var elegidas = emptySet<String>()
        elegidas = SummaryFilter.toggle(elegidas, mercado)
        elegidas = SummaryFilter.toggle(elegidas, salidas)
        assertEquals(setOf(mercado, salidas), elegidas)
        elegidas = SummaryFilter.toggle(elegidas, mercado)
        assertEquals(setOf(salidas), elegidas)
        assertNull(SummaryFilter.effective(emptySet(), listOf(mercado)))
    }

    @Test fun varias_categorias_juntas() {
        val mes = SummaryFilter.inPeriod(movimientos, hoy, 1)
        val chips = SummaryFilter.chips(mes)
        val filtro = SummaryFilter.effective(setOf(mercado, salidas, propia), chips)
        assertEquals(setOf(mercado, salidas), filtro)
        val visibles = SummaryFilter.apply(mes, filtro)
        assertEquals(pesos(350_000), visibles.sumOf { it.amountMinor })
        assertTrue(visibles.all { it.kind == EntryKind.GASTO })
        assertNull(SummaryFilter.effective(setOf(propia), chips))
        assertEquals(mes, SummaryFilter.apply(mes, null))
    }

    @Test fun titulo() {
        assertEquals("Ingresos y gastos", SummaryFilter.spendTitle(emptyList()))
        assertEquals("Gastos de Mercado", SummaryFilter.spendTitle(listOf("Mercado")))
        assertEquals("Gastos de Mercado y Salidas", SummaryFilter.spendTitle(listOf("Mercado", "Salidas")))
        assertEquals("Gastos de 3 categorías", SummaryFilter.spendTitle(listOf("Mercado", "Salidas", "Mascotas")))
    }
}
