package com.olarte.mprogress.ui.home

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.Categories
import com.olarte.mprogress.domain.CategoryForm
import com.olarte.mprogress.domain.CategoryRecord
import com.olarte.mprogress.ui.components.FormGroup
import com.olarte.mprogress.ui.components.FormSheet
import com.olarte.mprogress.ui.components.FormTextField
import com.olarte.mprogress.ui.components.IconTile
import com.olarte.mprogress.ui.components.SecondaryButton
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.Sym
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing

/**
 * Nueva categoría o editar una propia, igual que CategoryFormView de iOS: nombre, ícono de una cuadrícula de 30 y,
 * al editar, Borrar. Mientras no elijas ícono, se sugiere uno por el nombre ("Mascotas" da la huella).
 */
@Composable
fun CategoryFormSheet(store: Store, editing: CategoryRecord?, onDismiss: () -> Unit, onSaved: (CategoryRecord) -> Unit) {
    val ledger by store.ledger.collectAsState()
    var name by remember { mutableStateOf(editing?.name.orEmpty()) }
    var icon by remember { mutableStateOf(editing?.icon ?: CategoryForm.DEFAULT_ICON) }
    var iconTouched by remember { mutableStateOf(editing != null) }
    val existing = Categories.all + ledger.categories
    val problem = CategoryForm.problem(name, existing, editing?.id)

    fun save() {
        if (problem != null) return
        if (editing == null) onSaved(store.addCategory(name, icon))
        else {
            store.updateCategory(editing.id, name, icon)
            onSaved(editing.copy(name = CategoryForm.cleanName(name), icon = icon))
        }
    }

    FormSheet(if (editing == null) "Nueva categoría" else "Editar categoría", onDismiss, canConfirm = problem == null, onConfirm = ::save) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            IconTile(Sym.sf(icon) ?: Sym.more, Palette.brasaVelo, Palette.brasaTinta, size = 72.dp)
        }
        FormGroup("Nombre", footer = problem?.takeIf { it == CategoryForm.Problem.DUPLICATE }?.message) {
            FormTextField(name, "Mascotas, viajes, regalos") { v ->
                name = v.take(CategoryForm.MAX_LENGTH + 5)
                if (!iconTouched) CategoryForm.suggestedIcon(v)?.let { icon = it }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            SectionLabel("Ícono")
            CategoryForm.icons.chunked(5).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    row.forEach { (symbol, words) ->
                        val on = symbol == icon
                        Box(
                            Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(18.dp))
                                .background(if (on) Palette.brasaVelo else Palette.superficie3)
                                .border(2.dp, if (on) Palette.brasa else Palette.superficie3, RoundedCornerShape(18.dp))
                                .clickable { icon = symbol; iconTouched = true }
                                .semantics { contentDescription = words.substringBefore(' ') },
                            contentAlignment = Alignment.Center,
                        ) { Icon(Sym.sf(symbol) ?: Sym.more, null, Modifier.size(24.dp), tint = if (on) Palette.brasaTinta else Palette.texto1) }
                    }
                }
            }
        }
        if (editing != null) {
            SecondaryButton("Borrar categoría", danger = true) {
                store.deleteCategory(editing.id)
                store.showUndo("Borraste la categoría ${editing.name}") { store.restoreCategory(editing) }
                onDismiss()
            }
            T("Los movimientos que la usan quedan sin categoría.", Type.leyenda, Palette.texto2)
        }
    }
}

/** "+ Nueva categoría" arriba del selector de categoría. */
@Composable
fun NewCategoryRow(onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(Radius.campo)).clickable(onClick = onClick).padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
    ) {
        IconTile(Icons.Rounded.Add, Palette.brasaVelo, Palette.brasaTinta, size = 36.dp)
        T("Nueva categoría", Type.cuerpo.copy(fontWeight = FontWeight.SemiBold), Palette.brasaTinta)
    }
}

/** Fila del selector: tocar elige; mantener presionada una propia la abre para cambiarla o borrarla. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CategoryChoiceRow(category: CategoryRecord, selected: Boolean, onClick: () -> Unit, onLongClick: (() -> Unit)?) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(Radius.campo))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick, onLongClickLabel = onLongClick?.let { "Editar o borrar" })
            .padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3),
    ) {
        IconTile(Sym.sf(category.icon) ?: Sym.more, if (selected) Palette.brasaVelo else Palette.superficie3, if (selected) Palette.brasaTinta else Palette.texto1, size = 36.dp)
        Column(Modifier.weight(1f)) {
            T(category.name, Type.cuerpo.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal), if (selected) Palette.brasaTinta else Palette.texto1)
            if (onLongClick != null) T("Tuya", Type.leyenda, Palette.texto2)
        }
        if (selected) Icon(Icons.Rounded.Check, null, Modifier.size(18.dp), tint = Palette.brasaTinta)
    }
}
