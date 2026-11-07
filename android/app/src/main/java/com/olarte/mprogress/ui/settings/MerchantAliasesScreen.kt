package com.olarte.mprogress.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.Categories
import com.olarte.mprogress.domain.MerchantAliasRule
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.home.CategoryPickerSheet
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing

/**
 * Ajustes › Nombres de comercios, igual que MerchantAliasesView de iOS: lo que la app aprendió al cambiar el nombre de un pago
 * que llegó solo (notificación, SMS o recibo). Cada regla se puede cambiar o borrar.
 */
@Composable
fun MerchantAliasesScreen(store: Store, onBack: () -> Unit) {
    val ledger by store.ledger.collectAsState()
    var editing by remember { mutableStateOf<MerchantAliasRule?>(null) }
    val aliases = ledger.merchantAliases.sortedBy { it.name.lowercase() }

    SettingsPage("Nombres de comercios", onBack) {
        if (aliases.isEmpty()) {
            Card {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                    IconTile(Icons.Outlined.Storefront, Palette.brasaVelo, Palette.brasaTinta)
                    T("Aún no hay nombres de comercios", Type.titulo3)
                    T("Cuando cambies el nombre o la categoría de un pago que llegó solo (notificación, SMS o recibo), la app lo recuerda y lo usa la próxima vez que pagues ahí.",
                        Type.cuerpo2, Palette.texto2)
                }
            }
        } else {
            Card(padding = Spacing.s3) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                    aliases.forEachIndexed { i, a ->
                        ListRow(a.name.ifBlank { "?" }, title = a.name, subtitle = "${a.key} · ${Categories.byId(a.categoryId)?.name ?: "Sin categoría"}",
                            chevron = true, onClick = { editing = a })
                        if (i < aliases.lastIndex) FormDivider()
                    }
                }
            }
            T("Cuando llega un pago de uno de estos comercios, la app le pone el nombre y la categoría que elegiste. Toca uno para cambiarlo o borrarlo.",
                Type.leyenda, Palette.texto2)
        }
    }
    editing?.let { rule ->
        MerchantAliasForm(store, rule) { deleted ->
            editing = null
            if (deleted) store.showUndo("Borraste ${rule.name}") { store.restoreMerchantAlias(rule) }
        }
    }
}

/** Cambiar el nombre o la categoría de un comercio, o borrarlo. `onDone(true)` si se borró. */
@Composable
private fun MerchantAliasForm(store: Store, rule: MerchantAliasRule, onDone: (Boolean) -> Unit) {
    val ledger by store.ledger.collectAsState()
    var name by remember { mutableStateOf(rule.name) }
    var categoryId by remember { mutableStateOf(rule.categoryId) }
    var picking by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }
    FormSheet("Comercio", { onDone(false) }, canConfirm = name.isNotBlank(), onConfirm = {
        store.updateMerchantAlias(rule.id, name, categoryId)
        onDone(false)
    }) {
        FormGroup(footer = "Así se anota la próxima vez que pagues en este comercio.") {
            FormRow("Llega del banco como", rule.key, chevron = false)
            FormDivider()
            FormTextField(name, "Nombre") { name = it }
            FormDivider()
            FormRow("Categoría", Categories.byId(categoryId)?.name ?: "Sin categoría", onClick = { picking = true })
        }
        SecondaryButton("Borrar", danger = true) { confirm = true }
        Spacer(Modifier.height(Size.barra))
    }
    if (picking) CategoryPickerSheet(ledger.entries, categoryId, { picking = false }) { categoryId = it; picking = false }
    if (confirm) AlertDialog(onDismissRequest = { confirm = false }, title = { T("¿Borrar ${rule.name}?", Type.titulo3) },
        text = { T("Los pagos que ya registraste no cambian.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { TextButton({ confirm = false; store.deleteMerchantAlias(rule.id); onDone(true) }) { T("Borrar", Type.etiqueta, Palette.peligro) } },
        dismissButton = { TextButton({ confirm = false }) { T("Cancelar", Type.etiqueta) } }, containerColor = Palette.superficie2)
}
