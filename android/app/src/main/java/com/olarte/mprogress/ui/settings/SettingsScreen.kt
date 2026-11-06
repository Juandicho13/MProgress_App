package com.olarte.mprogress.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.Segmented
import com.olarte.mprogress.ui.components.SignatureFooter
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.AppTheme
import com.olarte.mprogress.ui.theme.GlassLevel
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing

/** Ajustes (pantalla 13) con Apariencia, Borrar cuenta y datos y la firma al pie. */
@Composable
fun SettingsScreen(store: Store) {
    var appearance by remember { mutableStateOf(false) }
    if (appearance) { AppearanceScreen(store) { appearance = false }; return }

    val theme by store.theme.collectAsState()
    val glass by store.glass.collectAsState()
    var confirmErase by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 110.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        T("Ajustes", Type.titulo1)
        Column {
            T("Sin cuenta", Type.titulo3)
            T("Todo se guarda en este teléfono", Type.cuerpo2, Palette.texto2)
        }
        SectionLabel("General")
        Card(padding = Spacing.s2) {
            Row("Moneda", "COP $", enabled = false)
            Divider()
            Row("Apariencia", "${AppTheme.from(theme).title} · vidrio ${GlassLevel.from(glass).title.lowercase()}") { appearance = true }
        }
        SectionLabel("Datos")
        Card(padding = Spacing.s2) {
            Row("Respaldo", "Pronto", enabled = false)
            Divider()
            Row("Espacios compartidos", "Pronto", enabled = false)
            Divider()
            Row("Avisos", "Pronto", enabled = false)
        }
        SectionLabel("Cuenta")
        Card(padding = Spacing.s2) {
            Box(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).clickable { confirmErase = true }.padding(horizontal = Spacing.s2),
                contentAlignment = Alignment.CenterStart) { T("Borrar cuenta y datos", Type.cuerpo, Palette.peligro) }
        }
        T("Borra tus movimientos, bancos, pagos fijos y ajustes de este teléfono. No se puede deshacer.", Type.leyenda, Palette.texto2)
        SectionLabel("Información")
        Card(padding = Spacing.s2) {
            Row("Novedades", "0.1", enabled = false)
            Divider()
            Row("Escríbeme", "Pronto", enabled = false)
        }
        SignatureFooter()
    }

    if (confirmErase) {
        AlertDialog(
            onDismissRequest = { confirmErase = false },
            title = { T("¿Borrar tu cuenta y todos tus datos?", Type.titulo3) },
            text = { T("Se borra todo lo que hay en este teléfono. La app vuelve al inicio como nueva.", Type.cuerpo2, Palette.texto2) },
            confirmButton = { TextButton({ confirmErase = false; store.eraseAll() }) { T("Borrar todo", Type.etiqueta, Palette.peligro) } },
            dismissButton = { TextButton({ confirmErase = false }) { T("Cancelar", Type.etiqueta) } },
            containerColor = Palette.superficie2,
        )
    }
}

@Composable
private fun Row(title: String, value: String?, enabled: Boolean = true, onClick: () -> Unit = {}) {
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = Spacing.s2).alpha(if (enabled) 1f else 0.6f),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        T(title, Type.cuerpo, modifier = Modifier.weight(1f))
        value?.let { T(it, Type.cuerpo2, Palette.texto2, maxLines = 1) }
        if (enabled) T("  ›", Type.titulo3, Palette.texto2)
    }
}

@Composable
private fun Divider() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))

/** Apariencia (pantalla 5): vista previa del vidrio, 4 niveles y tema. Cambia al instante. */
@Composable
fun AppearanceScreen(store: Store, onBack: () -> Unit) {
    val theme by store.theme.collectAsState()
    val glass by store.glass.collectAsState()
    val level = GlassLevel.from(glass)
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = 110.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s4),
    ) {
        T("‹ Ajustes", Type.etiqueta, Palette.brasaTinta, Modifier.padding(top = Spacing.s4).clip(CircleShape).clickable(onClick = onBack).padding(4.dp))
        T("Apariencia", Type.titulo1)
        Box(
            Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(28.dp))
                .background(Brush.linearGradient(listOf(Palette.brasa, Color(0xFF6CC4F2), Palette.oroRelleno))),
            contentAlignment = Alignment.BottomCenter,
        ) {
            androidx.compose.foundation.layout.Row(
                Modifier.padding(Spacing.s4).fillMaxWidth().height(52.dp).clip(CircleShape).background(Palette.vidrioTinte.copy(alpha = level.tint)),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                listOf("Inicio", "Resumen", "Dinero", "Ajustes").forEach {
                    T(it, Type.leyenda, if (it == "Inicio") Palette.brasaTinta else Palette.texto1, Modifier.weight(1f), align = androidx.compose.ui.text.style.TextAlign.Center)
                }
            }
        }
        SectionLabel("Transparencia del vidrio")
        Segmented(GlassLevel.entries.map { it.raw to it.title }, glass) { store.setGlass(it) }
        SectionLabel("Tema")
        Segmented(AppTheme.entries.map { it.raw to it.title }, theme) { store.setTheme(it) }
        T("El texto siempre se mantiene legible: con menos transparencia el vidrio se oscurece y nunca baja del contraste mínimo.", Type.leyenda, Palette.texto2)
        SignatureFooter()
    }
}
