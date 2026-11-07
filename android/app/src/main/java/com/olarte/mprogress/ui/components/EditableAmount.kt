package com.olarte.mprogress.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing

/**
 * Monto ya puesto que se puede cambiar (Pagar tarjeta, Marcar pagado y Transferir), igual que EditableAmountField de iOS:
 * campo con borde y tinte, lápiz y "Toca para cambiar el valor". Tocarlo abre el teclado numérico, que muestra quien lo usa.
 */
@Composable
fun EditableAmountField(input: AmountInput, editing: Boolean, modifier: Modifier = Modifier, onTap: () -> Unit) {
    val blink by rememberInfiniteTransition(label = "cursor").animateFloat(1f, 0f, infiniteRepeatable(tween(530), RepeatMode.Reverse), label = "cursor")
    val shape = RoundedCornerShape(Radius.tarjeta)
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        Row(
            Modifier.fillMaxWidth().clip(shape)
                .background(if (editing) Palette.brasaVelo else Palette.superficie3)
                .border(if (editing) 2.dp else 1.dp, if (editing) Palette.brasa else Palette.brasa.copy(alpha = 0.45f), shape)
                .clickable(onClickLabel = "Cambiar el valor", onClick = onTap)
                .semantics { contentDescription = "Monto, ${input.money.formatted()}. Toca para cambiar el valor" }
                .padding(vertical = Spacing.s3, horizontal = Spacing.s4),
            horizontalArrangement = Arrangement.spacedBy(Spacing.s2, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
        ) {
            T(input.currency.symbol, Type.cifraGrande, if (editing) Palette.brasaTinta else Palette.texto2)
            T(input.display, Type.cifraHeroe, if (input.text.isEmpty()) Palette.texto2 else Palette.texto1, maxLines = 1)
            if (editing) Box(Modifier.width(3.dp).height(44.dp).alpha(blink).clip(RoundedCornerShape(1.5.dp)).background(Palette.brasa))
            Icon(Icons.Rounded.Edit, null, Modifier.size(20.dp), tint = Palette.brasaTinta)
        }
        T(if (editing) "Escribe el nuevo valor" else "Toca para cambiar el valor", Type.leyenda, if (editing) Palette.brasaTinta else Palette.texto2,
            Modifier.padding(horizontal = Spacing.s2))
    }
}
