package com.olarte.mprogress.ui.settings

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import com.olarte.mprogress.ui.theme.Radius
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.R
import com.olarte.mprogress.ui.components.SectionLabel
import com.olarte.mprogress.ui.components.Segmented
import com.olarte.mprogress.ui.components.SignatureFooter
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing

/** Ícono de la app: 4 símbolos naranja (Trazo es el principal) con fondo negro o blanco, igual que iOS. */
enum class IconSymbol(val key: String, val title: String) { TRAZO("trazo", "Trazo"), ANILLO("anillo", "Anillo"), PROGRESO("progreso", "Progreso"), BARRAS("barras", "Barras") }

object AppIcons {
    private const val KEY = "apariencia.icono"
    fun alias(symbol: IconSymbol, white: Boolean) = "Icon" + symbol.key.replaceFirstChar { it.uppercase() } + if (white) "Blanco" else "Negro"

    fun current(context: Context): Pair<IconSymbol, Boolean> {
        val raw = context.getSharedPreferences("mprogress", Context.MODE_PRIVATE).getString(KEY, null) ?: return IconSymbol.TRAZO to false
        val white = raw.endsWith("Blanco")
        return (IconSymbol.entries.firstOrNull { raw.startsWith(it.key) } ?: IconSymbol.TRAZO) to white
    }

    /** Activa el alias elegido y apaga los demás. El lanzador puede tardar unos segundos en mostrarlo. */
    fun set(context: Context, symbol: IconSymbol, white: Boolean) {
        val pm = context.packageManager
        IconSymbol.entries.forEach { s ->
            listOf(false, true).forEach { w ->
                val on = s == symbol && w == white
                pm.setComponentEnabledSetting(ComponentName(context, "${context.packageName}.${alias(s, w)}"),
                    if (on) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
        context.getSharedPreferences("mprogress", Context.MODE_PRIVATE).edit().putString(KEY, symbol.key + if (white) "Blanco" else "Negro").apply()
    }

    fun preview(symbol: IconSymbol, white: Boolean): Int = when (symbol to white) {
        IconSymbol.TRAZO to false -> R.drawable.vista_trazo_negro
        IconSymbol.TRAZO to true -> R.drawable.vista_trazo_blanco
        IconSymbol.ANILLO to false -> R.drawable.vista_anillo_negro
        IconSymbol.ANILLO to true -> R.drawable.vista_anillo_blanco
        IconSymbol.PROGRESO to false -> R.drawable.vista_progreso_negro
        IconSymbol.PROGRESO to true -> R.drawable.vista_progreso_blanco
        IconSymbol.BARRAS to false -> R.drawable.vista_barras_negro
        else -> R.drawable.vista_barras_blanco
    }
}

/** Ícono de la app (pantalla 29, ahora sección de Diseño), igual que AppIconSection de iOS. */
@Composable
fun AppIconSection() {
    val context = LocalContext.current
    var state by remember { mutableStateOf(AppIcons.current(context)) }
    fun pick(s: IconSymbol, w: Boolean) { AppIcons.set(context, s, w); state = s to w }

    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s5)) {
        SectionLabel("Símbolo")
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            IconSymbol.entries.forEach { s ->
                val on = state.first == s
                Column(Modifier.weight(1f).heightIn(min = 110.dp).clip(RoundedCornerShape(Radius.boton)).clickable { pick(s, state.second) },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s2, Alignment.CenterVertically)) {
                    Box(Modifier.size(72.dp).border(3.dp, if (on) Palette.brasa else Color.Transparent, RoundedCornerShape(21.dp)), contentAlignment = Alignment.Center) {
                        Image(painterResource(AppIcons.preview(s, state.second)), s.title, Modifier.size(64.dp).clip(RoundedCornerShape(18.dp)))
                    }
                    T(s.title, Type.etiqueta)
                }
            }
        }
        SectionLabel("Fondo")
        Segmented(listOf("negro" to "Negro", "blanco" to "Blanco"), if (state.second) "blanco" else "negro") { pick(state.first, it == "blanco") }
        T("Qué entra en Premium se decide más adelante; por ahora todos están disponibles. Tu teléfono puede tardar unos segundos en mostrar el ícono nuevo.",
            Type.leyenda, Palette.texto2)
    }
}
