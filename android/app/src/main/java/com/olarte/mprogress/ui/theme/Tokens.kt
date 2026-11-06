package com.olarte.mprogress.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

// Tokens del sistema de diseño (HANDOFF sección 10), iguales a los de iOS, con tema claro y oscuro.
@Immutable
data class Colors(
    val fondo: Color, val superficie1: Color, val superficie2: Color, val superficie3: Color, val controlActivo: Color,
    val linea: Color, val texto1: Color, val texto2: Color, val brasaTinta: Color, val brasaVelo: Color,
    val hielo: Color, val hieloVelo: Color, val peligroVelo: Color, val oro: Color, val peligro: Color, val exito: Color, val vidrioTinte: Color, val vidrioBorde: Color,
    val isDark: Boolean,
)

val DarkColors = Colors(
    fondo = Color(0xFF0A0B0D), superficie1 = Color(0xFF15171B), superficie2 = Color(0xFF1D2025), superficie3 = Color(0xFF262A30),
    controlActivo = Color(0xFF3A3F47), linea = Color(0x14FFFFFF), texto1 = Color(0xFFF3F4F6), texto2 = Color(0xFFA5ABB4),
    brasaTinta = Color(0xFFFF6B2C), brasaVelo = Color(0xFF3A241E), hielo = Color(0xFF6CC4F2), hieloVelo = Color(0xFF23333D), peligroVelo = Color(0xFF3A1A20), oro = Color(0xFFF5C451),
    peligro = Color(0xFFFF5A6E), exito = Color(0xFF4ADE80), vidrioTinte = Color(0xFF1A1C21), vidrioBorde = Color(0x1FFFFFFF), isDark = true,
)

val LightColors = Colors(
    fondo = Color(0xFFF3F4F6), superficie1 = Color(0xFFFFFFFF), superficie2 = Color(0xFFFFFFFF), superficie3 = Color(0xFFE8EAEE),
    controlActivo = Color(0xFFFFFFFF), linea = Color(0x140E1014), texto1 = Color(0xFF0E1014), texto2 = Color(0xFF545B66),
    brasaTinta = Color(0xFFB83D0B), brasaVelo = Color(0xFFFFEAE1), hielo = Color(0xFF166AA0), hieloVelo = Color(0xFFE6F2F9), peligroVelo = Color(0xFFFDE7EA), oro = Color(0xFF7E5A00),
    peligro = Color(0xFFC8243E), exito = Color(0xFF15803D), vidrioTinte = Color(0xFFFFFFFF), vidrioBorde = Color(0x140E1014), isDark = false,
)

val LocalColors = staticCompositionLocalOf { DarkColors }

object Palette {
    // Fijos en los dos temas. Texto blanco sobre la brasa (pedido de Juan, contraste suficiente).
    val brasa = Color(0xFFF55F1F)
    val sobreBrasa = Color.White
    val oroRelleno = Color(0xFFF5C451)
    val sobreOro = Color(0xFF2A1F00)

    val fondo @Composable get() = LocalColors.current.fondo
    val superficie1 @Composable get() = LocalColors.current.superficie1
    val superficie2 @Composable get() = LocalColors.current.superficie2
    val superficie3 @Composable get() = LocalColors.current.superficie3
    val controlActivo @Composable get() = LocalColors.current.controlActivo
    val linea @Composable get() = LocalColors.current.linea
    val texto1 @Composable get() = LocalColors.current.texto1
    val texto2 @Composable get() = LocalColors.current.texto2
    val brasaTinta @Composable get() = LocalColors.current.brasaTinta
    val brasaVelo @Composable get() = LocalColors.current.brasaVelo
    val hielo @Composable get() = LocalColors.current.hielo
    val hieloVelo @Composable get() = LocalColors.current.hieloVelo
    val peligroVelo @Composable get() = LocalColors.current.peligroVelo
    val oro @Composable get() = LocalColors.current.oro
    val peligro @Composable get() = LocalColors.current.peligro
    val exito @Composable get() = LocalColors.current.exito
    val vidrioTinte @Composable get() = LocalColors.current.vidrioTinte
    val vidrioBorde @Composable get() = LocalColors.current.vidrioBorde
}

/** Transparencia del vidrio: cuánto tinte lleva la barra. Android no desenfoca detrás, así que solo cambia el tinte. */
enum class GlassLevel(val raw: String, val title: String, val tint: Float) {
    MUCHA("mucha", "Mucha", 0.55f), NORMAL("normal", "Normal", 0.78f), POCA("poca", "Poca", 0.92f), NINGUNA("ninguna", "Ninguna", 1f);
    companion object { fun from(raw: String) = entries.firstOrNull { it.raw == raw } ?: NORMAL }
}

enum class AppTheme(val raw: String, val title: String) {
    OSCURO("oscuro", "Oscuro"), CLARO("claro", "Claro"), SISTEMA("sistema", "Sistema");
    companion object { fun from(raw: String) = entries.firstOrNull { it.raw == raw } ?: OSCURO }
}

object Spacing {
    val s1 = 4.dp
    val s2 = 8.dp
    val s3 = 12.dp
    val s4 = 16.dp
    val s5 = 20.dp
    val s6 = 24.dp
    val s8 = 32.dp
    val margen = 20.dp
}

object Radius {
    val campo = 14.dp
    val boton = 20.dp
    val tarjeta = 28.dp
    val hoja = 36.dp
}

object Size {
    val toqueMinimo = 48.dp
    val botonPrincipal = 56.dp
    val barra = 64.dp
    val baldosa = 44.dp
}
