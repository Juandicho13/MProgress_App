package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.math.BigDecimal

/** Lee el catálogo real de src/main/assets (las pruebas JVM corren desde android/app). Igual a CardCatalogTests.swift. */
class CardCatalogTest {
    private val file = File("src/main/assets/card_catalog.json")
    private val catalog by lazy { CardCatalog.decode(file.readText()) }

    @Test fun lee() {
        assertEquals(1, catalog.version)
        assertEquals("2026-11", catalog.usuraMonth)
        assertEquals(0, BigDecimal("28.34").compareTo(catalog.usuraRateEA))
        assertEquals("Tope legal de este mes, revisa tu extracto", catalog.usuraNote)
        assertEquals(19, catalog.banks.size)
        assertEquals(133, catalog.banks.sumOf { it.cards.size })
    }

    @Test fun mismoArchivoQueIos() {
        val ios = File("../../ios/MProgress/Resources/CardCatalog.json")
        if (ios.exists()) assertEquals(ios.readText(), file.readText())
    }

    @Test fun integridad() {
        val ids = catalog.banks.flatMap { b -> b.cards.map { it.id } }
        assertEquals(ids.size, ids.toSet().size)
        assertEquals(catalog.banks.size, catalog.banks.map { it.id }.toSet().size)
        for (b in catalog.banks) {
            assertTrue(b.source.startsWith("https://"))
            assertTrue(b.sources.contains(b.source))
            assertEquals("2026-11-07", b.checkedAt)
            for (c in b.cards) {
                assertTrue(c.id.startsWith(b.id + "-"))
                assertTrue((c.handlingFeeCOP ?: 0) >= 0)
            }
        }
        assertFalse(file.readText().contains('\u2014'))
    }

    @Test fun buscaBanco() {
        val casos = listOf(
            "Bancolombia" to "bancolombia", "BANCOLOMBIA" to "bancolombia", "Banco de Bogota" to "banco-de-bogota",
            "Banco de Bogotá" to "banco-de-bogota", "Bogotá" to "banco-de-bogota", "Itaú" to "banco-de-bogota",
            "Colpatria" to "davibank", "Scotiabank Colpatria" to "davibank", "Davibank" to "davibank",
            "Nu" to "nu", "Nubank" to "nu", "nu colombia" to "nu", "Davivienda" to "davivienda", "BBVA" to "bbva",
            "bbva colombia" to "bbva", "AV Villas" to "av-villas", "Banco Popular" to "popular", "Caja Social" to "caja-social",
            "Falabella" to "falabella", "CMR Falabella" to "falabella", "Rappi" to "rappicard", "RappiPay" to "rappicard",
            "Tarjeta Éxito" to "tuya", "Carulla" to "tuya", "Lulo Bank" to "lulo", "Banco Agrario" to "agrario",
            "GNB Sudameris" to "gnb-sudameris", "Pichincha" to "pichincha", "Olímpica" to "serfinanza",
            "Serfinanza" to "serfinanza", "Finandina" to "finandina", "Banco de Occidente" to "occidente",
        )
        for ((texto, id) in casos) assertEquals(texto, id, catalog.bank(texto)?.id)
        assertNull(catalog.bank("Nequi"))
        assertNull(catalog.bank("Banco"))
        assertNull(catalog.bank(""))
        assertNull(catalog.bank("Nueva"))
        assertTrue(catalog.cards("Nequi").isEmpty())
    }

    @Test fun bancolombia() {
        val cards = catalog.cards("bancolombia")
        assertEquals(21, cards.size)
        val clasica = cards.first { it.id == "bancolombia-visa-clasica" }
        assertEquals("Visa Clásica", clasica.name)
        assertEquals(CardFranchise.VISA, clasica.franchise)
        assertEquals("clasica", clasica.tier)
        assertEquals("Puntos Colombia", clasica.rewards)
        assertEquals(3_290_000L, clasica.handlingFeeMinor)
        assertEquals("Visa · Puntos Colombia", clasica.subtitle)
        val libre = cards.first { it.name == "Amex Libre" }
        assertEquals(CardFranchise.AMEX, libre.franchise)
        assertEquals(0L, libre.handlingFeeMinor)
        assertTrue(cards.any { it.rewards == "LifeMiles" })
        assertEquals("American Express", CardFranchise.AMEX.title)
    }

    @Test fun otros() {
        assertTrue(catalog.bank("GNB")!!.cards.isEmpty())
        assertFalse(catalog.bank("GNB")!!.verified)
        assertEquals(CardFranchise.MASTERCARD, catalog.bank("Nu")!!.cards.first().franchise)
        val found = catalog.card("davibank-lifemiles-visa-infinite")
        assertNotNull(found)
        assertEquals("davibank", found!!.first.id)
        assertEquals("LifeMiles", found.second.rewards)
        assertNull(catalog.card("no-existe"))
        assertEquals(listOf("bogota"), CardCatalog.tokens("Banco de Bogotá S.A."))
        assertTrue(CardCatalog.tokens("Banco de Colombia").isEmpty())
    }

    @Test fun lectorJson() {
        val v = MiniJson("""{"a": [1, -2.5e1, true, false, null, "x\"yé"], "b": {}}""").parse() as Map<*, *>
        val a = v["a"] as List<*>
        assertEquals(BigDecimal(1), a[0])
        assertEquals(0, BigDecimal(-25).compareTo(a[1] as BigDecimal))
        assertEquals(true, a[2])
        assertEquals(false, a[3])
        assertNull(a[4])
        assertEquals("x\"yé", a[5])
        assertEquals(emptyMap<String, Any?>(), v["b"])
    }
}
