package com.olarte.mprogress.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.QuickAddMath
import com.olarte.mprogress.domain.QuickNames
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.CircleIconButton
import com.olarte.mprogress.ui.components.EditableAmountField
import com.olarte.mprogress.ui.components.Keypad
import com.olarte.mprogress.ui.components.OverlaySheet
import com.olarte.mprogress.ui.components.PrimaryButton
import com.olarte.mprogress.ui.components.Segmented
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.components.appTextField
import com.olarte.mprogress.ui.components.signedAmount
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate

/**
 * Registro rápido en una sola hoja, igual que QuickAddView de iOS: Gasto o Ingreso, el monto con el teclado de la app
 * (listo para escribir al abrir), "¿En qué?" opcional con los nombres que más usas y Guardar. Un toque guarda, cierra y
 * muestra Deshacer. Sin nombre queda "Gasto rápido" o "Ingreso rápido".
 */
@Composable
fun QuickAddSheet(store: Store, onDismiss: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    val currency by store.currency.collectAsState()
    var kind by remember { mutableStateOf(EntryKind.GASTO) }
    var amount by remember { mutableStateOf(AmountInput(currency)) }
    var name by remember { mutableStateOf("") }
    var nameFocused by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val suggestions = remember(ledger.entries, kind) { QuickNames.recent(ledger.entries, kind) }
    val visible = QuickNames.matching(suggestions, name)

    fun save() {
        val minor = amount.money.minor
        if (minor <= 0) return
        val finalName = QuickAddMath.name(kind, name)
        val categoryId = if (kind == EntryKind.GASTO) QuickNames.categoryId(name, suggestions) else null
        val created = store.add(kind, finalName, minor, Cycle.Puntual, LocalDate.now(), null, categoryId = categoryId) ?: return
        focus.clearFocus()
        onDismiss()
        store.showUndo("Anotado: $finalName · ${signedAmount(created.amountMinor, kind)}") { store.deleteEntry(created.id) }
    }

    OverlaySheet(onDismiss) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            Row(Modifier.fillMaxWidth().padding(top = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                CircleIconButton(Icons.Rounded.Close, "Cerrar", onClick = onDismiss)
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) { T("Registro rápido", Type.titulo3) }
                Spacer(Modifier.size(Size.toqueMinimo))
            }
            Segmented(listOf("GASTO" to "Gasto", "INGRESO" to "Ingreso"), kind.name) { kind = EntryKind.valueOf(it) }
            // El teclado de la app escribe en el monto salvo mientras escribes el nombre.
            EditableAmountField(amount, editing = !nameFocused, showsCaption = false) { focus.clearFocus() }
            Row(
                Modifier.fillMaxWidth().heightIn(min = Size.toqueMinimo).clip(RoundedCornerShape(Radius.campo)).background(Palette.superficie3)
                    .padding(start = Spacing.s4),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s2),
            ) {
                Icon(Icons.Rounded.TextFields, null, Modifier.size(18.dp), tint = Palette.texto2)
                Box(Modifier.weight(1f).padding(vertical = Spacing.s3)) {
                    if (name.isEmpty()) T("¿En qué? Almuerzo, taxi, mercado", Type.cuerpo, Palette.texto2, maxLines = 1)
                    BasicTextField(name, { name = it.take(60) },
                        Modifier.appTextField().fillMaxWidth().onFocusChanged { nameFocused = it.isFocused }.semantics { contentDescription = "¿En qué?" },
                        textStyle = Type.cuerpo.copy(color = Palette.texto1), cursorBrush = SolidColor(Palette.brasa), singleLine = true,
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }))
                }
                if (name.isNotEmpty()) {
                    Box(Modifier.size(Size.toqueMinimo).clip(CircleShape).clickable { name = "" }.semantics { contentDescription = "Borrar el nombre" },
                        contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Cancel, null, Modifier.size(18.dp), tint = Palette.texto2)
                    }
                } else Spacer(Modifier.size(Spacing.s2))
            }
            if (visible.isNotEmpty()) {
                Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    visible.forEach { item -> Chip(item.name) { name = item.name; focus.clearFocus() } }
                }
            }
            PrimaryButton("Guardar", enabled = amount.money.minor > 0) { save() }
            if (!nameFocused) Keypad(amount.allowsDecimals, { amount = amount.press(it) }, { amount = amount.deleteLast() })
        }
    }
}
