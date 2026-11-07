package com.olarte.mprogress.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing

/**
 * Pastilla de la barra de filtros (Resumen), igual que FilterPill de iOS: 44 de alto, cápsula, ícono de 18.
 * Elegida: rellena con texto1 y letra oscura; sin elegir: superficie1 con letra clara.
 */
@Composable
fun FilterPill(title: String, selected: Boolean = false, modifier: Modifier = Modifier, icon: ImageVector? = null, chevron: Boolean = false, onClick: () -> Unit) {
    val fg = if (selected) Palette.fondo else Palette.texto1
    Row(
        modifier.height(44.dp).clip(CircleShape).background(if (selected) Palette.texto1 else Palette.superficie1)
            .semantics { this.selected = selected }
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = Spacing.s4),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2),
    ) {
        if (icon != null) Icon(icon, null, Modifier.size(18.dp), tint = fg)
        T(title, Type.etiqueta, fg, maxLines = 1)
        if (chevron) Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(16.dp), tint = fg)
    }
}
