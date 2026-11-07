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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Backspace
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import com.olarte.mprogress.R
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing

/** Archivo variable, la misma fuente de iOS, con peso y ancho exactos (las cifras al 112,5 % de ancho). */
@OptIn(ExperimentalTextApi::class)
private fun archivo(weight: Int, width: Float = 100f) = FontFamily(
    Font(R.font.archivo, FontWeight(weight), variationSettings = FontVariation.Settings(FontVariation.weight(weight), FontVariation.width(width)))
)

/** Estilos de texto de HANDOFF 10.2, iguales a iOS. */
object Type {
    val titulo1 = TextStyle(fontFamily = archivo(700), fontSize = 30.sp, lineHeight = 36.sp, letterSpacing = (-0.4).sp)
    val titulo2 = TextStyle(fontFamily = archivo(600), fontSize = 20.sp, lineHeight = 26.sp)
    val titulo3 = TextStyle(fontFamily = archivo(600), fontSize = 17.sp, lineHeight = 22.sp)
    val cuerpo = TextStyle(fontFamily = archivo(400), fontSize = 16.sp, lineHeight = 24.sp)
    val cuerpo2 = TextStyle(fontFamily = archivo(400), fontSize = 14.sp, lineHeight = 20.sp)
    val etiqueta = TextStyle(fontFamily = archivo(500), fontSize = 13.sp, lineHeight = 16.sp)
    val leyenda = TextStyle(fontFamily = archivo(500), fontSize = 12.sp, lineHeight = 16.sp, letterSpacing = 0.5.sp)
    val pestana = TextStyle(fontFamily = archivo(500), fontSize = 11.sp, lineHeight = 14.sp)
    val cifraHeroe = TextStyle(fontFamily = archivo(700, 112.5f), fontSize = 46.sp, lineHeight = 50.sp, letterSpacing = (-0.4).sp)
    val cifraGrande = TextStyle(fontFamily = archivo(600, 112.5f), fontSize = 32.sp, lineHeight = 38.sp)
    val cifra = TextStyle(fontFamily = archivo(600, 112.5f), fontSize = 17.sp, lineHeight = 22.sp)
    val cifraPequena = TextStyle(fontFamily = archivo(600, 112.5f), fontSize = 15.sp, lineHeight = 20.sp)
    val boton = TextStyle(fontFamily = archivo(600), fontSize = 17.sp, lineHeight = 22.sp)
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

/** Botón principal: píldora brasa de 56; deshabilitado al 40 %. */
@Composable
fun PrimaryButton(title: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(Size.botonPrincipal).alpha(if (enabled) 1f else 0.4f).clip(CircleShape)
            .background(Palette.brasa).clickable(enabled = enabled, onClick = onClick).padding(horizontal = Spacing.s5),
        contentAlignment = Alignment.Center,
    ) { T(title, Type.titulo3, Palette.sobreBrasa, maxLines = 1) }
}

/** Botón secundario: píldora gris de 48 (roja si es peligro). */
@Composable
fun SecondaryButton(title: String, modifier: Modifier = Modifier, enabled: Boolean = true, danger: Boolean = false, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(48.dp).alpha(if (enabled) 1f else 0.4f).clip(CircleShape)
            .background(if (danger) Palette.peligroVelo else Palette.superficie3).clickable(enabled = enabled, onClick = onClick).padding(horizontal = Spacing.s4),
        contentAlignment = Alignment.Center,
    ) { T(title, Type.titulo3, if (danger) Palette.peligro else Palette.texto1, maxLines = 1) }
}

/** Hoja inferior dibujada encima de la pantalla (sirve igual en la app y en las capturas). */
@Composable
fun OverlaySheet(onDismiss: () -> Unit, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    androidx.activity.compose.BackHandler(onBack = onDismiss)
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)).clickable(interactionSource = null, indication = null, onClick = onDismiss)) {
        Column(
            modifier.align(Alignment.BottomCenter).fillMaxWidth()
                .clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)).background(Palette.superficie2)
                .clickable(interactionSource = null, indication = null) {}.navigationBarsPadding()
                // El teclado empuja la hoja hacia arriba; el contenido que se desplaza deja ver el campo que tiene el foco.
                .imePadding(),
        ) {
            Box(Modifier.padding(top = Spacing.s2).align(Alignment.CenterHorizontally).width(36.dp).height(5.dp).clip(CircleShape).background(Palette.texto2.copy(alpha = 0.4f)))
            content()
        }
    }
}

/** Píldora como Chip de iOS: etiqueta, alto mínimo 40, velo brasa con texto brasa si está elegida. */
@Composable
fun Chip(title: String, selected: Boolean = false, modifier: Modifier = Modifier, icon: ImageVector? = null, onClick: () -> Unit) {
    Row(
        modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (selected) Palette.brasaVelo else Palette.superficie1)
            .clickable(onClick = onClick).padding(horizontal = Spacing.s4),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1),
    ) {
        val c = if (selected) Palette.brasaTinta else Palette.texto1
        if (icon != null) Icon(icon, null, Modifier.size(15.dp), tint = c)
        T(title, Type.etiqueta, c, maxLines = 1)
    }
}

@Composable
fun Tile(glyph: String, tint: Color = Palette.superficie3, fg: Color = Palette.texto1, size: androidx.compose.ui.unit.Dp = Size.baldosa) {
    Box(Modifier.size(size).clip(RoundedCornerShape(size * 0.32f)).background(tint), contentAlignment = Alignment.Center) {
        T(glyph.take(2).uppercase(), TextStyle(fontFamily = Type.titulo3.fontFamily, fontSize = (size.value * 0.32f).sp, fontWeight = FontWeight.Bold), fg)
    }
}

/** Baldosa con ícono, como IconTile de iOS. */
@Composable
fun IconTile(icon: ImageVector, tint: Color = Palette.superficie3, fg: Color = Palette.texto1, size: androidx.compose.ui.unit.Dp = Size.baldosa, circle: Boolean = false, rotate: Float = 0f) {
    Box(Modifier.size(size).clip(if (circle) CircleShape else RoundedCornerShape(size * 0.32f)).background(tint), contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(size * 0.46f).rotate(rotate), tint = fg)
    }
}

/** Avatar redondo con iniciales. */
@Composable
fun Avatar(name: String, size: androidx.compose.ui.unit.Dp = 32.dp) {
    val initials = name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.first().uppercase() }.ifEmpty { "?" }
    Box(Modifier.size(size).clip(CircleShape).background(Palette.brasa), contentAlignment = Alignment.Center) {
        T(initials, TextStyle(fontFamily = Type.titulo3.fontFamily, fontSize = (size.value * 0.36f).sp, fontWeight = FontWeight.Bold), Palette.sobreBrasa)
    }
}

/** Insignia: HOY, PRONTO. */
@Composable
fun Badge(text: String, bg: Color, fg: Color) {
    Box(Modifier.clip(CircleShape).background(bg).padding(horizontal = Spacing.s2, vertical = 3.dp)) {
        T(text.uppercase(), TextStyle(fontFamily = Type.etiqueta.fontFamily, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.4.sp), fg)
    }
}

/** Botón redondo con ícono (la campana de Inicio). */
@Composable
fun CircleIconButton(icon: ImageVector, label: String, filled: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    Box(Modifier.size(Size.toqueMinimo).alpha(if (enabled) 1f else 0.4f).clip(CircleShape).background(if (filled) Palette.brasa else Palette.superficie1)
        .clickable(enabled = enabled, onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center) { Icon(icon, null, Modifier.size(20.dp), tint = if (filled) Palette.sobreBrasa else Palette.texto1) }
}

/** Píldora segmentada como SegmentedPill de iOS. */
@Composable
fun Segmented(options: List<Pair<String, String>>, selected: String, modifier: Modifier = Modifier, onSelect: (String) -> Unit) {
    Row(modifier.fillMaxWidth().clip(CircleShape).background(Palette.superficie3).padding(Spacing.s1), horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        options.forEach { (value, title) ->
            val on = value == selected
            Box(
                Modifier.weight(1f).heightIn(min = 40.dp).clip(CircleShape).background(if (on) Palette.controlActivo else Color.Transparent).clickable { onSelect(value) },
                contentAlignment = Alignment.Center,
            ) { T(title, Type.etiqueta.copy(fontWeight = if (on) FontWeight.SemiBold else FontWeight.Medium), Palette.texto1, maxLines = 1) }
        }
    }
}

/** Monto grande que se resalta con borde brasa y cursor cuando está activo (igual que AmountDisplay de iOS). */
@Composable
fun AmountDisplay(prefix: String, text: String, active: Boolean, modifier: Modifier = Modifier, empty: Boolean = text == "0", onClick: () -> Unit = {}) {
    val blink by rememberInfiniteTransition(label = "cursor").animateFloat(1f, 0f, infiniteRepeatable(tween(530), RepeatMode.Reverse), label = "cursor")
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.tarjeta))
            .background(if (active) Palette.brasaVelo else Color.Transparent)
            .border(if (active) 2.dp else 1.dp, if (active) Palette.brasa else Palette.linea, RoundedCornerShape(Radius.tarjeta))
            .clickable(onClick = onClick).padding(vertical = Spacing.s3, horizontal = Spacing.s4),
        horizontalArrangement = Arrangement.spacedBy(Spacing.s2, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
    ) {
        T(prefix, Type.cifraGrande, if (active) Palette.brasaTinta else Palette.texto2)
        T(text, Type.cifraHeroe, if (empty) Palette.texto2 else Palette.texto1, maxLines = 1)
        if (active) Box(Modifier.width(3.dp).height(44.dp).alpha(blink).clip(RoundedCornerShape(1.5.dp)).background(Palette.brasa))
    }
}

/** Teclado numérico de iOS: teclas de 52 de alto, radio 20; la coma y borrar sin fondo. */
@Composable
fun Keypad(allowsComma: Boolean, onKey: (Char) -> Unit, onDelete: () -> Unit) {
    val rows = listOf("123", "456", "789", ",0<")
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                row.forEach { c ->
                    val hidden = c == ',' && !allowsComma
                    Box(
                        Modifier.weight(1f).height(52.dp).clip(RoundedCornerShape(Radius.boton))
                            .background(if (c == ',' || c == '<') Color.Transparent else Palette.superficie3)
                            .alpha(if (hidden) 0f else 1f)
                            .clickable(enabled = !hidden) { if (c == '<') onDelete() else onKey(c) },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (c == '<') Icon(androidx.compose.material.icons.Icons.AutoMirrored.Outlined.Backspace, "Borrar", Modifier.size(22.dp), tint = Palette.texto1)
                        else T(c.toString(), TextStyle(fontSize = 24.sp, fontWeight = FontWeight.Medium), Palette.texto1)
                    }
                }
            }
        }
    }
}

/** Fila de lista como ListRow de iOS: baldosa, título, subtítulo y algo a la derecha. */
@Composable
fun ListRow(glyph: String? = null, title: String, subtitle: String? = null, tint: Color = Palette.superficie3, fg: Color = Palette.texto1,
            icon: ImageVector? = null, chevron: Boolean = false, onClick: (() -> Unit)? = null, trailing: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp)
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }.padding(vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
    ) {
        when {
            icon != null -> IconTile(icon, tint, fg)
            glyph != null -> Tile(glyph, tint, fg)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, Type.titulo3, maxLines = 1)
            subtitle?.let { T(it, Type.cuerpo2, Palette.texto2, maxLines = 1) }
        }
        trailing()
        if (chevron) Icon(androidx.compose.material.icons.Icons.Rounded.ChevronRight, null, Modifier.size(18.dp), tint = Palette.texto2)
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
        Modifier.fillMaxWidth().padding(top = Spacing.s8, bottom = Size.barra + Spacing.s8 + Spacing.s6).semantics(mergeDescendants = true) { contentDescription = "Desarrollado por juan-olarte-dev" },
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


/** Monto con signo para listas: "+ $ 2.200.000" o "− $ 84.300". */
fun signedAmount(minor: Long, kind: com.olarte.mprogress.domain.EntryKind) =
    com.olarte.mprogress.domain.Money(if (kind == com.olarte.mprogress.domain.EntryKind.INGRESO) minor else -minor).formatted(sign = true)

/** Baldosa de un movimiento o pago fijo: iniciales, azul hielo si es ingreso. */
@Composable
fun EntryTile(name: String, kind: com.olarte.mprogress.domain.EntryKind, size: androidx.compose.ui.unit.Dp = Size.baldosa) {
    val income = kind == com.olarte.mprogress.domain.EntryKind.INGRESO
    Tile(name.ifBlank { "?" }, if (income) Palette.hieloVelo else Palette.superficie3, if (income) Palette.hielo else Palette.texto1, size)
}

/** Fila de un movimiento en Inicio, Historial y Calendario, como EntryRow de iOS. */
@Composable
fun EntryRow(name: String, kind: com.olarte.mprogress.domain.EntryKind, amountMinor: Long, subtitle: String?, onClick: (() -> Unit)? = null,
             pending: Boolean = false, trailing: (@Composable () -> Unit)? = null) {
    val income = kind == com.olarte.mprogress.domain.EntryKind.INGRESO
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).let { if (onClick != null) it.clickable(onClick = onClick) else it }.padding(vertical = Spacing.s1),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
    ) {
        EntryTile(name, kind)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(name.ifBlank { if (income) "Ingreso" else "Gasto" }, Type.titulo3, maxLines = 1)
            subtitle?.let { T(it, Type.cuerpo2, Palette.texto2, maxLines = 1) }
        }
        if (trailing != null) trailing() else Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(signedAmount(amountMinor, kind), Type.cifra, if (income) Palette.hielo else Palette.texto1)
            if (pending) PendingMark()
        }
    }
}

/** Marca de un movimiento con cambios que todavía no suben a la nube (F10-04): reloj pequeño y "Pendiente". */
@Composable
fun PendingMark() {
    Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        Icon(androidx.compose.material.icons.Icons.Outlined.Schedule, null, Modifier.size(12.dp), tint = Palette.texto2)
        T("Pendiente", Type.leyenda, Palette.texto2, maxLines = 1)
    }
}

/** Estado vacío con dibujo, título, texto y acciones. */
@Composable
fun EmptyState(title: String, message: String, art: @Composable () -> Unit, actions: @Composable () -> Unit = {}) {
    Column(Modifier.fillMaxWidth().padding(Spacing.s6), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
        art()
        T(title, Type.titulo2, align = TextAlign.Center)
        T(message, Type.cuerpo, Palette.texto2, align = TextAlign.Center)
        actions()
    }
}

/** Botón redondo para volver, como el de la barra de iOS. */
@Composable
fun BackButton(label: String = "Volver", onBack: () -> Unit) {
    Box(Modifier.padding(top = Spacing.s2)) { CircleIconButton(androidx.compose.material.icons.Icons.AutoMirrored.Rounded.ArrowBack, label, onClick = onBack) }
}

/** Campo de búsqueda con botón para borrar. */
@Composable
fun SearchField(text: String, prompt: String, onChange: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie1).padding(horizontal = Spacing.s4),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        Box(Modifier.weight(1f)) {
            if (text.isEmpty()) T(prompt, Type.cuerpo, Palette.texto2, maxLines = 1)
            androidx.compose.foundation.text.BasicTextField(text, onChange, Modifier.appTextField().fillMaxWidth(), textStyle = Type.cuerpo.copy(color = Palette.texto1),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(Palette.brasa), singleLine = true)
        }
        if (text.isNotEmpty()) Icon(androidx.compose.material.icons.Icons.Rounded.Cancel, "Borrar búsqueda", Modifier.size(20.dp).clickable { onChange("") }, tint = Palette.texto2)
    }
}

/** Hoja casi de pantalla completa para detalles (Detalle, Pago fijo), dibujada encima de todo. */
@Composable
fun SheetPanel(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    androidx.activity.compose.BackHandler(onBack = onDismiss)
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)).clickable(interactionSource = null, indication = null, onClick = onDismiss)) {
        Box(Modifier.fillMaxSize().statusBarsPaddingCompat().padding(top = Spacing.s5).clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja))
            .background(Palette.superficie2).clickable(interactionSource = null, indication = null) {}.navigationBarsPadding().imePadding()) { content() }
    }
}

private fun Modifier.statusBarsPaddingCompat() = this.then(Modifier.statusBarsPadding())

/** Aviso con Deshacer abajo, como UndoCenter de iOS. Se cierra solo a los 5 segundos. */
@Composable
fun UndoToast(message: com.olarte.mprogress.data.UndoMessage?, bottom: androidx.compose.ui.unit.Dp, onClose: () -> Unit) {
    if (message == null) return
    androidx.compose.runtime.LaunchedEffect(message.id) { kotlinx.coroutines.delay(5000); onClose() }
    Box(Modifier.fillMaxSize().padding(bottom = bottom).navigationBarsPadding().padding(horizontal = Spacing.s4), contentAlignment = Alignment.BottomCenter) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.boton)).background(Palette.superficie3).padding(start = Spacing.s4, end = Spacing.s2).heightIn(min = 52.dp),
            verticalAlignment = Alignment.CenterVertically) {
            T(message.text, Type.cuerpo2, modifier = Modifier.weight(1f).padding(vertical = Spacing.s2))
            message.undo?.let { u -> T("Deshacer", Type.etiqueta, Palette.brasaTinta, Modifier.clip(CircleShape).clickable { u(); onClose() }.padding(Spacing.s3)) }
        }
    }
}
