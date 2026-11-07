package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Mismos casos que QuickNamesTests y CategoryFormTests de iOS. */
class QuickNamesTest {
    private val mercado = "0a000000-0000-4000-8000-000000000006"
    private val salidas = "0a000000-0000-4000-8000-000000000008"
    private fun gasto(name: String, day: Int, category: String? = null, recurring: String? = null) =
        EntryRecord(kind = EntryKind.GASTO, amountMinor = 10_000_00, occurredAt = LocalDate.of(2026, 11, day), name = name, categoryId = category, recurringId = recurring)

    @Test fun losMasUsadosPrimero() {
        val entries = listOf(gasto("Taxi", 1), gasto("almuerzo", 2, salidas), gasto("Almuerzo", 3), gasto("Mercado", 4, mercado),
            gasto("Taxi", 5), gasto("Almuerzo", 6), gasto("Café", 7))
        val names = QuickNames.recent(entries, EntryKind.GASTO)
        assertEquals(listOf("Almuerzo", "Taxi", "Café", "Mercado"), names.map { it.name })
        assertEquals(salidas, names[0].categoryId)
        assertEquals(mercado, names[3].categoryId)
    }

    @Test fun filtros() {
        val entries = listOf(gasto("Gasto rápido", 1), gasto("gasto", 1), gasto("  ", 1), gasto("Netflix", 2, recurring = "r"),
            EntryRecord(kind = EntryKind.INGRESO, amountMinor = 5, occurredAt = LocalDate.of(2026, 11, 3), name = "Venta"))
        assertTrue(QuickNames.recent(entries, EntryKind.GASTO).isEmpty())
        assertEquals(listOf("Venta"), QuickNames.recent(entries, EntryKind.INGRESO).map { it.name })
        val many = (1..9).map { gasto("Cosa $it", it) }
        assertEquals(QuickNames.LIMIT, QuickNames.recent(many, EntryKind.GASTO).size)
        assertEquals("Cosa 9", QuickNames.recent(many, EntryKind.GASTO).first().name)
        // Mismo día: el que se anotó después va primero.
        assertEquals("B", QuickNames.recent(listOf(gasto("A", 1), gasto("B", 1)), EntryKind.GASTO).first().name)
    }

    @Test fun mientrasEscribes() {
        val names = listOf(QuickName("Almuerzo", salidas), QuickName("Arriendo"), QuickName("Taxi"))
        assertEquals(3, QuickNames.matching(names, "").size)
        assertEquals(listOf("Almuerzo", "Arriendo"), QuickNames.matching(names, "a").map { it.name })
        assertEquals(listOf("Almuerzo"), QuickNames.matching(names, "ALMUÉR").map { it.name })
        assertTrue(QuickNames.matching(names, "almuerzo").isEmpty())
        assertEquals(salidas, QuickNames.categoryId("almuerzo ", names))
        assertNull(QuickNames.categoryId("Otro", names))
    }

    @Test fun nombrePorDefecto() {
        assertEquals("Gasto rápido", QuickAddMath.name(EntryKind.GASTO, ""))
        assertEquals("Ingreso rápido", QuickAddMath.name(EntryKind.INGRESO, null))
        assertEquals("Almuerzo", QuickAddMath.name(EntryKind.GASTO, " almuerzo "))
    }
}

class CategoryFormTest {
    @Test fun iconos() {
        assertEquals(30, CategoryForm.icons.size)
        assertEquals(30, CategoryForm.icons.map { it.first }.toSet().size)
        assertTrue(CategoryForm.icons.any { it.first == CategoryForm.DEFAULT_ICON })
    }

    @Test fun validar() {
        val mascotas = CategoryRecord("m", "Mascotas", "pawprint", 15)
        val existing = listOf(CategoryRecord("x", "Mercado", "cart", 6), mascotas)
        assertEquals("Viajes de pareja", CategoryForm.cleanName("  Viajes   de  pareja "))
        assertEquals(CategoryForm.MAX_LENGTH, CategoryForm.cleanName("a".repeat(40)).length)
        assertEquals(CategoryForm.Problem.EMPTY, CategoryForm.problem("   ", existing))
        assertEquals(CategoryForm.Problem.DUPLICATE, CategoryForm.problem("MASCOTÁS", existing))
        assertNull(CategoryForm.problem("Mascotas", existing, editing = "m"))
        assertNull(CategoryForm.problem("Viajes", existing))
    }

    @Test fun sugerirYOrden() {
        assertEquals("pawprint", CategoryForm.suggestedIcon("Mascotas"))
        assertEquals("airplane", CategoryForm.suggestedIcon("Viajes con Mari"))
        assertNull(CategoryForm.suggestedIcon("Xyz"))
        assertEquals(15, CategoryForm.nextSort(listOf(1, 2, 14, 99)))
        assertEquals(21, CategoryForm.nextSort(listOf(1, 14, 20, 99)))
        assertEquals(98, CategoryForm.nextSort(listOf(98, 99)))
        assertEquals(15, CategoryForm.nextSort(emptyList()))
    }
}
