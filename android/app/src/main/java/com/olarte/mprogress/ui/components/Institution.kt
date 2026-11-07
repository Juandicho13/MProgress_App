package com.olarte.mprogress.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.TrendingUp
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.theme.Size

/** Colores e íconos de bancos, igual que InstitutionStyle de iOS. */
object InstitutionStyle {
    val suggestions: List<Pair<String, Long>> = listOf(
        "Bancolombia" to 0xFDDA24, "Nu" to 0xA68CFF, "Nequi" to 0xF7B6E8, "Davivienda" to 0xED4C5C,
        "Daviplata" to 0xFF7A85, "BBVA" to 0x4A90D9, "Banco de Bogotá" to 0x5B8DEF, "Lulo" to 0xD7FF3C,
        "Efectivo" to 0x3A3F47,
    )
    val palette = listOf(0xFDDA24L, 0xA68CFFL, 0xF7B6E8L, 0xFF7A85L, 0x4A90D9L, 0x6CC4F2L, 0x4ADE80L, 0xFF6B2CL, 0x3A3F47L)

    /** Color por nombre: el sugerido, o uno fijo de la paleta según el nombre. */
    fun hexFor(name: String): Long = suggestions.firstOrNull { it.first.equals(name, true) }?.second
        ?: palette[Math.floorMod(name.lowercase().hashCode(), palette.size)]

    fun color(hex: Long): Color = Color(0xFF000000 or hex)

    /** Texto oscuro sobre colores claros y claro sobre oscuros. */
    fun foreground(hex: Long): Color {
        val r = ((hex shr 16) and 0xFF) / 255.0; val g = ((hex shr 8) and 0xFF) / 255.0; val b = (hex and 0xFF) / 255.0
        return if (0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5) Color(0xFF14161A) else Color(0xFFF3F4F6)
    }

    @Composable
    fun Tile(name: String, hex: Long = hexFor(name), size: Dp = Size.baldosa) = Tile(name, color(hex), foreground(hex), size)

    fun symbol(kind: ProductKind): ImageVector = when (kind) {
        ProductKind.CUENTA -> Icons.Outlined.AccountBalance
        ProductKind.DEBITO, ProductKind.CREDITO -> Icons.Rounded.CreditCard
        ProductKind.BOLSILLO -> Icons.Outlined.Inventory2
        ProductKind.CAJITA -> Icons.AutoMirrored.Outlined.TrendingUp
        ProductKind.EFECTIVO -> Icons.Outlined.Payments
    }
}
