package com.olarte.mprogress.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing

object Type {
    val titulo1 = TextStyle(fontSize = 30.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp)
    val titulo2 = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold)
    val titulo3 = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    val cuerpo = TextStyle(fontSize = 16.sp)
    val cuerpo2 = TextStyle(fontSize = 14.sp)
    val etiqueta = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    val leyenda = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.6.sp)
    val cifra = TextStyle(fontSize = 44.sp, fontWeight = FontWeight.Bold, letterSpacing = (-1).sp)
}

@Composable
fun T(text: String, style: TextStyle, color: Color = Palette.texto1, modifier: Modifier = Modifier, align: TextAlign? = null, maxLines: Int = Int.MAX_VALUE) =
    Text(text, modifier = modifier, style = style, color = color, textAlign = align, maxLines = maxLines)

@Composable
fun Card(modifier: Modifier = Modifier, padding: androidx.compose.ui.unit.Dp = Spacing.s4, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.tarjeta)).background(Palette.superficie1).padding(padding),
        content = content,
    )
}

@Composable
fun SectionLabel(text: String) = T(text.uppercase(), Type.leyenda, Palette.texto2, Modifier.fillMaxWidth())

@Composable
fun PrimaryButton(title: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(Size.botonPrincipal).clip(CircleShape)
            .background(if (enabled) Palette.brasa else Palette.superficie3)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { T(title, Type.titulo3, if (enabled) Palette.sobreBrasa else Palette.texto2) }
}

@Composable
fun SecondaryButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(Size.botonPrincipal).clip(CircleShape).background(Palette.superficie3).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { T(title, Type.titulo3) }
}

/** Píldora elegible: naranja con texto blanco si está elegida. */
@Composable
fun Chip(title: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (selected) Palette.brasa else Palette.superficie3)
            .clickable(onClick = onClick).padding(horizontal = Spacing.s4, vertical = Spacing.s2),
        contentAlignment = Alignment.Center,
    ) { T(title, Type.etiqueta, if (selected) Palette.sobreBrasa else Palette.texto1, maxLines = 1) }
}

@Composable
fun Tile(glyph: String, tint: Color = Palette.superficie3, fg: Color = Palette.texto1, size: androidx.compose.ui.unit.Dp = Size.baldosa) {
    Box(Modifier.size(size).clip(RoundedCornerShape(size * 0.32f)).background(tint), contentAlignment = Alignment.Center) {
        T(glyph, TextStyle(fontSize = (size.value * 0.42f).sp, fontWeight = FontWeight.SemiBold), fg)
    }
}

@Composable
fun Segmented(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(CircleShape).background(Palette.superficie3).padding(Spacing.s1)) {
        options.forEach { (value, title) ->
            val on = value == selected
            Box(
                Modifier.weight(1f).height(44.dp).clip(CircleShape).background(if (on) Palette.controlActivo else Color.Transparent).clickable { onSelect(value) },
                contentAlignment = Alignment.Center,
            ) { T(title, Type.etiqueta, if (on) Palette.texto1 else Palette.texto2) }
        }
    }
}

/** Monto grande que se resalta con borde brasa y cursor cuando está activo (igual que iOS). */
@Composable
fun AmountDisplay(prefix: String, text: String, active: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit = {}) {
    val blink by rememberInfiniteTransition(label = "cursor").animateFloat(1f, 0f, infiniteRepeatable(tween(530), RepeatMode.Reverse), label = "cursor")
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.tarjeta))
            .background(if (active) Palette.brasaVelo else Palette.superficie1)
            .border(2.dp, if (active) Palette.brasa else Color.Transparent, RoundedCornerShape(Radius.tarjeta))
            .clickable(onClick = onClick).padding(vertical = Spacing.s5, horizontal = Spacing.s4),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        T("$prefix ", Type.titulo2, Palette.texto2)
        T(text, Type.cifra)
        if (active) Box(Modifier.padding(start = 2.dp).width(3.dp).height(40.dp).alpha(blink).background(Palette.brasa))
    }
}

@Composable
fun Keypad(allowsComma: Boolean, onKey: (Char) -> Unit, onDelete: () -> Unit) {
    val rows = listOf("123", "456", "789", (if (allowsComma) "," else " ") + "0<")
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                row.forEach { c ->
                    Box(
                        Modifier.weight(1f).height(54.dp).clip(RoundedCornerShape(Radius.campo))
                            .background(if (c == ' ') Color.Transparent else Palette.superficie3)
                            .clickable(enabled = c != ' ') { if (c == '<') onDelete() else onKey(c) },
                        contentAlignment = Alignment.Center,
                    ) { T(if (c == '<') "⌫" else c.toString(), Type.titulo2) }
                }
            }
        }
    }
}

/** Fila de lista con baldosa, título, subtítulo y algo a la derecha. */
@Composable
fun ListRow(glyph: String, title: String, subtitle: String? = null, tint: Color = Palette.superficie3, fg: Color = Palette.texto1,
            onClick: (() -> Unit)? = null, trailing: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(Radius.campo))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }.padding(vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
    ) {
        Tile(glyph, tint, fg)
        Column(Modifier.weight(1f)) {
            T(title, Type.titulo3, maxLines = 1)
            subtitle?.let { T(it, Type.cuerpo2, Palette.texto2, maxLines = 1) }
        }
        trailing()
    }
}

/**
 * Firma de Juan (skill firma-juan-olarte-dev): texto, línea de 1 x 22 y monograma JO de 30 x 20 con anillo brasa.
 * Centrada al final de Ajustes, con aire debajo para que la barra no la tape.
 */
@Composable
fun SignatureFooter() {
    val ink = Palette.texto1
    val ring = Palette.brasaTinta
    Row(
        Modifier.fillMaxWidth().padding(top = Spacing.s8, bottom = Spacing.s6).semantics(mergeDescendants = true) { contentDescription = "Desarrollado por juan-olarte-dev" },
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        T("juan-olarte-dev", TextStyle(fontSize = 14.sp, letterSpacing = 0.7.sp), ink.copy(alpha = 0.75f))
        Spacer(Modifier.width(16.dp))
        Box(Modifier.width(1.dp).height(22.dp).background(ink.copy(alpha = 0.2f)))
        Spacer(Modifier.width(16.dp))
        Canvas(Modifier.width(30.dp).height(20.dp)) {
            val sx = size.width / 30f
            val sy = size.height / 20f
            fun p(x: Float, y: Float) = Offset(x * sx, y * sy)
            val j = Path().apply {
                moveTo(11.3f * sx, 2.3f * sy); lineTo(11.3f * sx, 13.6f * sy)
                cubicTo(11.3f * sx, 16.5f * sy, 9.3f * sx, 18.2f * sy, 6.9f * sx, 18.2f * sy)
                cubicTo(5.1f * sx, 18.2f * sy, 3.6f * sx, 17.4f * sy, 2.7f * sx, 16.1f * sy)
            }
            drawPath(j, ink, style = Stroke(width = 2.3f * sx, cap = StrokeCap.Round))
            drawCircle(ink, radius = 7f * sx, center = p(21f, 10.8f), style = Stroke(width = 2.3f * sx))
            drawCircle(ring, radius = 2.1f * sx, center = p(21f, 10.8f), style = Stroke(width = 0.9f * sx))
        }
    }
}

