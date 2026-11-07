package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CurrencyCatalogTest {
    @Test fun lasDeSiempreNoCambian() {
        assertEquals(2, Currency.from("COP").minorDigits)
        assertEquals(0, Currency.from("COP").shownDigits)
        assertEquals(1L, Currency.from("clp").minorPerUnit)
        assertEquals(0, Currency.from("ARS").shownDigits)
        assertEquals("$ 1.901.100", Money.units(1_901_100).formatted())
        assertEquals("US$ 1.234,56", Money(123_456, Currency.USD).formatted())
        assertEquals("$ 45.501", Money(4_550_050, Currency.COP).formatted())
    }

    @Test fun todasConDecimalesDeIso() {
        assertEquals(CurrencyCatalog.ISO_CODES.size, Currency.all.size)
        assertTrue(Currency.all.size > 150)
        assertEquals(0, Currency.from("JPY").minorDigits)
        assertEquals(3, Currency.from("KWD").minorDigits)
        assertNull(Currency.known("XYZ"))
        assertEquals(Currency.COP, Currency.from("XYZ"))
        assertTrue(Currency.all.all { it.name.isNotBlank() && it.symbol.isNotBlank() })
    }

    @Test fun formatoJpyYKwd() {
        assertEquals("¥ 1.500.000", Money.units(1_500_000, Currency.from("JPY")).formatted())
        assertEquals("KD 1.234,567", Money(1_234_567, Currency.from("KWD")).formatted())
        assertEquals("− KD 0,005", Money(-5, Currency.from("KWD")).formatted())
    }

    @Test fun tecladoCon0y3Decimales() {
        var yen = AmountInput(Currency.from("JPY"))
        "12,5".forEach { yen = yen.press(it) }
        assertEquals(125L, yen.money.minor)
        var dinar = AmountInput(Currency.from("KWD"))
        "7,1234".forEach { dinar = dinar.press(it) }
        assertEquals(7_123L, dinar.money.minor)
        assertEquals("7,12", AmountInput.fromMinor(7_120, Currency.from("KWD")).display)
    }

    @Test fun buscar() {
        assertEquals("USD", Currency.search("usd").first().code)
        assertTrue(Currency.search("dolar").any { it.code == "CAD" })
        assertEquals(listOf("COP"), Currency.search("peso colombiano").map { it.code })
        assertEquals(Currency.all.size, Currency.search("").size)
        assertTrue(Currency.search("zzzz").isEmpty())
    }

    @Test fun masUsadasYOrden() {
        assertEquals(listOf("COP", "USD", "EUR", "MXN", "CLP", "PEN", "ARS", "BRL", "GBP", "CAD"), Currency.popular.map { it.code })
        val names = Currency.all.map { HistoryMath.normalize(it.name) }
        assertEquals(names.sorted(), names)
    }

    @Test fun banderas() {
        assertEquals("🇨🇴", Currency.COP.flag)
        assertEquals("🇪🇺", Currency.EUR.flag)
        assertNull(Currency.from("XOF").flag)
    }
}
