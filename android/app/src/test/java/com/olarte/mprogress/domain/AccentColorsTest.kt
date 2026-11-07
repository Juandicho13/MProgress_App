package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Colores de Diseño: los mismos casos de AccentColorsTests de iOS. */
class AccentColorsTest {
    @Test fun contraste() {
        assertEquals(21.0, ColorMath.contrast(0xFFFFFF, 0x000000), 0.01)
        assertEquals(1.0, ColorMath.contrast(0xF55F1F, 0xF55F1F), 0.0001)
    }

    @Test fun texto_sobre_acento() {
        listOf(0xF55F1F, 0xE5384F, 0x2F7FE0, 0x8B5CF6, 0x14A88A).forEach { assertEquals(ColorMath.WHITE, ColorMath.onAccent(it)) }
        listOf(0xF2A516, 0x7CB518, 0xFFFFFF).forEach { assertEquals(ColorMath.INK, ColorMath.onAccent(it)) }
    }

    @Test fun mezcla() {
        assertEquals(0xF55F1F, ColorMath.mix(0xF55F1F, 0x000000, 1.0))
        assertEquals(0x000000, ColorMath.mix(0xF55F1F, 0x000000, 0.0))
        assertEquals(0x808080, ColorMath.mix(0xFFFFFF, 0x000000, 0.5))
    }

    @Test fun reglas_de_la_brasa() {
        val d = AccentTokens.accent(0xF55F1F)
        val o = AccentTokens.BRASA_ORIGINAL
        listOf(d.pressedLight to o.pressedLight, d.inkLight to o.inkLight, d.inkDark to o.inkDark, d.veilLight to o.veilLight, d.veilDark to o.veilDark)
            .forEach { (a, b) -> assertTrue("${a.toString(16)} lejos de ${b.toString(16)}", ColorMath.contrast(a, b) < 1.25) }
        assertEquals(o.onFill, d.onFill)
    }

    @Test fun todos_se_leen() {
        (AccentPresets.accents + AccentPresets.incomes).forEach { p ->
            val t = p.tokens
            assertTrue("${p.name} claro", ColorMath.contrast(t.inkLight, ColorMath.LIGHT_BACKGROUND) >= 4.5)
            assertTrue("${p.name} oscuro", ColorMath.contrast(t.inkDark, ColorMath.DARK_BACKGROUND) >= 4.5)
            assertTrue("${p.name} relleno", ColorMath.contrast(t.onFill, t.fill) >= 3)
        }
    }

    @Test fun presets() {
        assertEquals(8, AccentPresets.accents.size)
        assertEquals(8, AccentPresets.incomes.size)
        assertEquals(8, AccentPresets.accents.map { it.id }.toSet().size)
        assertEquals(8, AccentPresets.incomes.map { it.id }.toSet().size)
        assertTrue(AccentPresets.accents[0].isOriginal && AccentPresets.incomes[0].isOriginal)
        assertEquals(AccentTokens.BRASA_ORIGINAL, AccentPresets.accent(null).tokens)
        assertEquals(AccentTokens.HIELO_ORIGINAL, AccentPresets.income("no-existe").tokens)
        assertEquals("Rubí", AccentPresets.accent("rubi").name)
    }

    @Test fun resumen() {
        assertEquals("Oscuro · vidrio normal · Trazo", AccentPresets.summary("Oscuro", "Normal", "Trazo", null, null))
        assertEquals("Claro · vidrio poca · Anillo · Rubí", AccentPresets.summary("Claro", "Poca", "Anillo", "rubi", "original"))
        assertEquals("Oscuro · vidrio normal · Trazo · Rubí y Verde", AccentPresets.summary("Oscuro", "Normal", "Trazo", "rubi", "verde"))
    }
}
