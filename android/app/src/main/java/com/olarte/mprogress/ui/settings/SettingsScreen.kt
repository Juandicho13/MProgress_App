package com.olarte.mprogress.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.Icon
import com.olarte.mprogress.ui.components.Avatar
import com.olarte.mprogress.ui.components.CircleIconButton
import com.olarte.mprogress.ui.theme.Radius
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

/** Ajustes (pantalla 13): General, Datos, Información y Cuenta, con la firma al pie, igual que iOS. */
@Composable
fun SettingsScreen(store: Store) {
    var appearance by remember { mutableStateOf(false) }
    var icon by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler(enabled = appearance || icon) { appearance = false; icon = false }
    if (appearance) { AppearanceScreen(store) { appearance = false }; return }
    if (icon) { AppIconScreen { icon = false }; return }
    val context = androidx.compose.ui.platform.LocalContext.current
    val (iconSymbol, iconWhite) = AppIcons.current(context)
    val version = remember { runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0" }

    val theme by store.theme.collectAsState()
    val glass by store.glass.collectAsState()
    var confirmErase by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = Spacing.s8),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        T("Ajustes", Type.titulo1)
        androidx.compose.foundation.layout.Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            Avatar("Mi cuenta", 48.dp)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T("Sin cuenta", Type.titulo3)
                T("Todo se guarda en este teléfono", Type.cuerpo2, Palette.texto2)
            }
        }
        SectionLabel("General")
        Card(padding = Spacing.s2) {
            Row("Bloqueo con huella", "Pronto", enabled = false)
            Divider()
            Row("Moneda", "COP $", enabled = false)
            Divider()
            Row("Apariencia", "${AppTheme.from(theme).title} · vidrio ${GlassLevel.from(glass).title.lowercase()}") { appearance = true }
            Divider()
            Row("Ícono de la app", "${iconSymbol.title} · ${if (iconWhite) "blanco" else "negro"}") { icon = true }
        }
        SectionLabel("Datos")
        Card(padding = Spacing.s2) {
            Row("Respaldo y dispositivos", "Pronto", enabled = false)
            Divider()
            Row("Espacios compartidos", "Pronto", enabled = false)
            Divider()
            Row("Avisos", "Pronto", enabled = false)
        }
        SectionLabel("Información")
        Card(padding = Spacing.s2) {
            Row("Novedades", version, enabled = false)
            Divider()
            Row("Escríbeme", "Pronto", enabled = false)
        }
        SectionLabel("Cuenta")
        Card(padding = Spacing.s2) {
            androidx.compose.foundation.layout.Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).clickable { confirmErase = true }.padding(horizontal = Spacing.s2),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                T("Borrar cuenta y datos", Type.cuerpo, Palette.peligro, Modifier.weight(1f))
                Icon(Icons.Outlined.Delete, null, Modifier.size(18.dp), tint = Palette.peligro)
            }
        }
        T("Borra tus movimientos, bancos, pagos fijos, metas, respaldos y ajustes de este teléfono. No se puede deshacer.", Type.leyenda, Palette.texto2)
        SignatureFooter()
    }

    if (confirmErase) {
        AlertDialog(
            onDismissRequest = { confirmErase = false },
            title = { T("¿Borrar tu cuenta y todos tus datos?", Type.titulo3) },
            text = { T("Se borra todo lo que hay en este teléfono, también los respaldos. La app vuelve al inicio como nueva.", Type.cuerpo2, Palette.texto2) },
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
        if (enabled) Icon(Icons.Rounded.ChevronRight, null, Modifier.padding(start = Spacing.s1).size(18.dp), tint = Palette.texto2)
    }
}

@Composable
private fun Divider() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))

/** Barra de una pantalla de Ajustes: botón redondo para volver, como la de iOS. */
@Composable
fun BackBar(onBack: () -> Unit) {
    Box(Modifier.padding(top = Spacing.s2)) { CircleIconButton(Icons.AutoMirrored.Rounded.ArrowBack, "Volver a Ajustes", onClick = onBack) }
}

/** Apariencia (pantalla 5): vista previa del vidrio, 4 niveles y tema. Cambia al instante. */
@Composable
fun AppearanceScreen(store: Store, onBack: () -> Unit) {
    val theme by store.theme.collectAsState()
    val glass by store.glass.collectAsState()
    val level = GlassLevel.from(glass)
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(bottom = Spacing.s8),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        BackBar(onBack)
        T("Apariencia", Type.titulo1)
        Box(
            Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(Radius.tarjeta))
                .background(Brush.linearGradient(listOf(Palette.brasa, Color(0xFF6CC4F2), Palette.oroRelleno))),
            contentAlignment = Alignment.BottomCenter,
        ) {
            androidx.compose.foundation.layout.Row(
                Modifier.padding(Spacing.s4).fillMaxWidth().height(52.dp).clip(CircleShape).background(Palette.vidrioTinte.copy(alpha = level.tint))
                    .border(1.dp, Palette.vidrioBorde, CircleShape),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                listOf("Inicio", "Resumen", "Dinero", "Ajustes").forEach {
                    T(it, Type.pestana, if (it == "Inicio") Palette.brasaTinta else Palette.texto1, Modifier.weight(1f), align = androidx.compose.ui.text.style.TextAlign.Center)
                }
            }
        }
        SectionLabel("Transparencia del vidrio")
        Segmented(GlassLevel.entries.map { it.raw to it.title }, glass) { store.setGlass(it) }
        T(when (level) {
            GlassLevel.NORMAL -> "Vidrio con tinte, como en el resto de la app."
            GlassLevel.MUCHA -> "Más transparente: se ve lo que hay detrás."
            GlassLevel.POCA -> "Vidrio con un tinte oscuro, más fácil de leer."
            GlassLevel.NINGUNA -> "Sin transparencia."
        }, Type.cuerpo2, Palette.texto2)
        SectionLabel("Tema")
        Segmented(AppTheme.entries.map { it.raw to it.title }, theme) { store.setTheme(it) }
        T("El texto siempre se mantiene legible: con menos transparencia el vidrio se oscurece y nunca baja del contraste mínimo.", Type.leyenda, Palette.texto2)
        SignatureFooter()
    }
}
