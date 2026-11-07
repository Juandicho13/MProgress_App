package com.olarte.mprogress.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AccentPresets
import com.olarte.mprogress.domain.ColorMath
import com.olarte.mprogress.domain.ColorPreset
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.SignatureFooter
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.LiveColors
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import com.olarte.mprogress.ui.theme.rgb

/** Diseño (Ajustes): Tema y vidrio, Colores e Ícono de la app en una sola pantalla, igual que DesignView de iOS. */
@Composable
fun DesignScreen(store: Store, onBack: () -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = Spacing.s8),
        verticalArrangement = Arrangement.spacedBy(Spacing.s6),
    ) {
        BackBar(onBack)
        T("Diseño", Type.titulo1)
        T("Tema y vidrio", Type.titulo2, modifier = Modifier.padding(top = Spacing.s2))
        AppearanceSection(store)
        T("Colores", Type.titulo2, modifier = Modifier.padding(top = Spacing.s2))
        ColorsSection(store)
        T("Ícono de la app", Type.titulo2, modifier = Modifier.padding(top = Spacing.s2))
        AppIconSection()
        SignatureFooter()
    }
}

/** Colores: acento (la brasa) e ingresos (el hielo), con vista previa y Restablecer. Toda la app cambia al instante. */
@Composable
fun ColorsSection(store: Store) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
        // Vista previa: una pastilla elegida, un ingreso y un botón con los colores elegidos.
        Card(Modifier.semantics(mergeDescendants = true) { contentDescription = "Vista previa: botón, pastilla elegida e ingreso con los colores elegidos" }) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    Chip("Mercado", selected = true, icon = Icons.Rounded.ShoppingCart) {}
                    Chip("Salidas", icon = Icons.Rounded.Restaurant) {}
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    T("Sueldo", Type.cuerpo, modifier = Modifier.weight(1f))
                    T(Money.units(2_500_000L).formatted(sign = true), Type.cifra, Palette.hielo)
                }
                PrimaryButton("Guardar") {}
            }
        }
        SectionLabel("Acento")
        Swatches(AccentPresets.accents, LiveColors.accentId) { store.setAccent(it) }
        SectionLabel("Ingresos")
        Swatches(AccentPresets.incomes, LiveColors.incomeId) { store.setIncome(it) }
        if (LiveColors.accentId != "original" || LiveColors.incomeId != "original") {
            SecondaryButton("Restablecer", Modifier.fillMaxWidth()) { store.resetColors() }
        }
        T("El texto sobre el acento cambia a blanco u oscuro para que siempre se lea. Los widgets usan los colores originales.", Type.leyenda, Palette.texto2)
    }
}

@Composable
private fun Swatches(presets: List<ColorPreset>, selectedId: String, onPick: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
        presets.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                row.forEach { p ->
                    val on = p.id == selectedId
                    Column(
                        Modifier.weight(1f).heightIn(min = 48.dp).clip(RoundedCornerShape(16.dp)).clickable { onPick(p.id) }
                            .semantics(mergeDescendants = true) { selected = on; contentDescription = if (p.isOriginal) "${p.name}, original" else p.name },
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s1),
                    ) {
                        Box(Modifier.size(52.dp).border(2.dp, if (on) Palette.texto1 else Color.Transparent, CircleShape), contentAlignment = Alignment.Center) {
                            Box(Modifier.size(44.dp).clip(CircleShape).background(rgb(p.swatch)), contentAlignment = Alignment.Center) {
                                if (on) Icon(Icons.Rounded.Check, null, Modifier.size(20.dp), tint = rgb(ColorMath.onAccent(p.swatch)))
                            }
                        }
                        T(p.name, Type.etiqueta, maxLines = 1)
                        T(if (p.isOriginal) "Original" else " ", Type.leyenda, Palette.texto2)
                    }
                }
            }
        }
    }
}
