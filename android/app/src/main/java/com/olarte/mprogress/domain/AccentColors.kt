package com.olarte.mprogress.domain

import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/** Cuentas de color en hexadecimal (0xRRGGBB), sin Compose, igual que ColorMath de iOS. */
object ColorMath {
    const val WHITE = 0xFFFFFF
    const val BLACK = 0x000000
    /** Texto oscuro de la app (texto1 del tema claro), el que va sobre acentos claros. */
    const val INK = 0x0E1014
    const val LIGHT_BACKGROUND = 0xFFFFFF
    const val DARK_BACKGROUND = 0x0A0B0D
    const val DARK_SURFACE = 0x15171B

    private fun ch(hex: Int, shift: Int) = ((hex shr shift) and 0xFF).toDouble()

    /** Mezcla [a] sobre [b]: [amount] es cuánto de [a] queda (1 es solo a, 0 es solo b). */
    fun mix(a: Int, over: Int, amount: Double): Int {
        val t = min(max(amount, 0.0), 1.0)
        fun c(shift: Int) = (ch(a, shift) * t + ch(over, shift) * (1 - t)).roundToInt()
        return (c(16) shl 16) or (c(8) shl 8) or c(0)
    }

    /** Luminancia relativa de WCAG 2. */
    fun luminance(hex: Int): Double {
        fun lin(v: Double): Double { val s = v / 255; return if (s <= 0.03928) s / 12.92 else ((s + 0.055) / 1.055).pow(2.4) }
        return 0.2126 * lin(ch(hex, 16)) + 0.7152 * lin(ch(hex, 8)) + 0.0722 * lin(ch(hex, 0))
    }

    /** Contraste de WCAG 2 entre dos colores, de 1 a 21. */
    fun contrast(a: Int, b: Int): Double {
        val la = luminance(a); val lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /** Texto sobre el acento: blanco mientras tenga contraste de 3 (texto en negrilla de 17 o más); si no, el oscuro. */
    fun onAccent(fill: Int): Int = if (contrast(WHITE, fill) >= 3) WHITE else INK

    /** Mezcla [color] con [toward] de a 5 % hasta tener al menos [minimum] de contraste con [background]. */
    fun ensureContrast(color: Int, toward: Int, background: Int, minimum: Double = 4.5): Int {
        var amount = 1.0
        var result = color
        while (contrast(result, background) < minimum && amount > 0) {
            amount -= 0.05
            result = mix(color, toward, amount)
        }
        return result
    }
}

/** Los tonos que salen de un color: relleno, presionado, tinta (texto) y velo, en claro y en oscuro. */
data class AccentTokens(
    val fill: Int, val onFill: Int, val pressedLight: Int, val pressedDark: Int,
    val inkLight: Int, val inkDark: Int, val veilLight: Int, val veilDark: Int,
) {
    companion object {
        /** Los de la app hasta hoy (HANDOFF 10): con "Original" todo se ve exactamente igual. */
        val BRASA_ORIGINAL = AccentTokens(0xF55F1F, 0xFFFFFF, 0xDE5014, 0xE04F12, 0xB83D0B, 0xFF6B2C, 0xFFEAE1, 0x3A241E)
        val HIELO_ORIGINAL = AccentTokens(0x6CC4F2, ColorMath.INK, 0x166AA0, 0x6CC4F2, 0x166AA0, 0x6CC4F2, 0xE6F2F9, 0x23333D)

        /** Reglas sacadas de la brasa original, iguales a iOS: presionado 10 % hacia negro; tinta 25 % hacia negro en
         *  claro y 8 % hacia blanco en oscuro, asegurada a 4,5 sobre su fondo; velo 13 % sobre blanco y 16 % sobre la superficie oscura. */
        fun accent(fill: Int) = AccentTokens(
            fill = fill,
            onFill = ColorMath.onAccent(fill),
            pressedLight = ColorMath.mix(fill, ColorMath.BLACK, 0.9),
            pressedDark = ColorMath.mix(fill, ColorMath.BLACK, 0.9),
            inkLight = ColorMath.ensureContrast(ColorMath.mix(fill, ColorMath.BLACK, 0.75), ColorMath.BLACK, ColorMath.LIGHT_BACKGROUND),
            inkDark = ColorMath.ensureContrast(ColorMath.mix(fill, ColorMath.WHITE, 0.92), ColorMath.WHITE, ColorMath.DARK_BACKGROUND),
            veilLight = ColorMath.mix(fill, ColorMath.WHITE, 0.13),
            veilDark = ColorMath.mix(fill, ColorMath.DARK_SURFACE, 0.16),
        )

        /** Azul de ingresos: texto con el color de cada tema asegurado a 4,5; velo 10 % sobre blanco y 16 % sobre la superficie oscura. */
        fun income(light: Int, dark: Int): AccentTokens {
            val inkLight = ColorMath.ensureContrast(light, ColorMath.BLACK, ColorMath.LIGHT_BACKGROUND)
            val inkDark = ColorMath.ensureContrast(dark, ColorMath.WHITE, ColorMath.DARK_BACKGROUND)
            return AccentTokens(dark, ColorMath.onAccent(dark), inkLight, inkDark, inkLight, inkDark,
                ColorMath.mix(light, ColorMath.WHITE, 0.1), ColorMath.mix(dark, ColorMath.DARK_SURFACE, 0.16))
        }
    }
}

/** Un color para elegir en Ajustes › Diseño › Colores. */
data class ColorPreset(val id: String, val name: String, val swatch: Int, val tokens: AccentTokens) {
    val isOriginal get() = id == "original"
}

object AccentPresets {
    const val ACCENT_KEY = "diseno.acento"
    const val INCOME_KEY = "diseno.ingreso"

    private fun accent(id: String, name: String, hex: Int) = ColorPreset(id, name, hex, AccentTokens.accent(hex))
    private fun income(id: String, name: String, light: Int, dark: Int) = ColorPreset(id, name, dark, AccentTokens.income(light, dark))

    val accents = listOf(
        ColorPreset("original", "Brasa", 0xF55F1F, AccentTokens.BRASA_ORIGINAL),
        accent("rubi", "Rubí", 0xE5384F),
        accent("rosa", "Rosa", 0xE8457F),
        accent("violeta", "Violeta", 0x8B5CF6),
        accent("azul", "Azul", 0x2F7FE0),
        accent("menta", "Menta", 0x14A88A),
        accent("lima", "Lima", 0x7CB518),
        accent("ambar", "Ámbar", 0xF2A516),
    )

    val incomes = listOf(
        ColorPreset("original", "Hielo", 0x6CC4F2, AccentTokens.HIELO_ORIGINAL),
        income("azulRey", "Azul rey", 0x1D4ED8, 0x93B4FD),
        income("indigo", "Índigo", 0x4338CA, 0xA5B4FC),
        income("violeta", "Violeta", 0x7E3FBF, 0xC4A1F5),
        income("turquesa", "Turquesa", 0x0E7C86, 0x4FD1DB),
        income("verde", "Verde", 0x15803D, 0x4ADE80),
        income("oliva", "Oliva", 0x4D7C0F, 0xA3E635),
        income("pizarra", "Pizarra", 0x475569, 0xCBD5E1),
    )

    /** Lo guardado, o el original si no hay nada o el id ya no existe. */
    fun accent(id: String?) = accents.firstOrNull { it.id == id } ?: accents[0]
    fun income(id: String?) = incomes.firstOrNull { it.id == id } ?: incomes[0]

    /** Texto de la fila Diseño en Ajustes: "Oscuro · vidrio normal · Trazo", y los colores si no son los originales. */
    fun summary(theme: String, glass: String, icon: String, accentId: String?, incomeId: String?): String {
        val parts = mutableListOf(theme, "vidrio ${glass.lowercase()}", icon)
        val custom = listOf(accent(accentId), income(incomeId)).filter { !it.isOriginal }.map { it.name }
        if (custom.isNotEmpty()) parts += custom.joinToString(" y ")
        return parts.joinToString(" · ")
    }
}
