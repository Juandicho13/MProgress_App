package com.olarte.mprogress

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.QuickActionKind
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.fixed.FixedScreen
import com.olarte.mprogress.ui.home.AddEntryContent
import com.olarte.mprogress.ui.home.AddRequest
import com.olarte.mprogress.ui.home.HomeScreen
import com.olarte.mprogress.ui.home.MoreContent
import com.olarte.mprogress.ui.onboarding.OnboardingScreen
import com.olarte.mprogress.ui.settings.SettingsScreen
import com.olarte.mprogress.ui.theme.AppTheme
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.GlassLevel
import com.olarte.mprogress.ui.theme.LightColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = Store.get(this)
        setContent {
            val themeRaw by store.theme.collectAsState()
            val dark = when (AppTheme.from(themeRaw)) { AppTheme.OSCURO -> true; AppTheme.CLARO -> false; AppTheme.SISTEMA -> isSystemInDarkTheme() }
            // Barras del sistema acordes al tema elegido, al instante.
            LaunchedEffect(dark) {
                val style = if (dark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
                else SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)
                enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
            }
            CompositionLocalProvider(LocalColors provides if (dark) DarkColors else LightColors) {
                val onboarded by store.onboarded.collectAsState()
                Box(Modifier.fillMaxSize().background(Palette.fondo)) {
                    if (onboarded) RootScreen(store) else OnboardingScreen(store)
                }
            }
        }
    }
}

enum class AppTab(val title: String, val glyph: String) {
    Inicio("Inicio", "⌂"), Resumen("Resumen", "▥"), Dinero("Dinero", "▤"), Calendario("Calendario", "▦"), Ajustes("Ajustes", "⚙")
}

private enum class Route { FIJOS }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RootScreen(store: Store) {
    var tab by remember { mutableStateOf(AppTab.Inicio) }
    var route by remember { mutableStateOf<Route?>(null) }
    var adding by remember { mutableStateOf<AddRequest?>(null) }
    var more by remember { mutableStateOf(false) }
    val glass by store.glass.collectAsState()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    fun perform(kind: QuickActionKind) {
        when (kind) {
            QuickActionKind.GASTO, QuickActionKind.RAPIDO -> adding = AddRequest(EntryKind.GASTO, Cycle.Puntual)
            QuickActionKind.INGRESO -> adding = AddRequest(EntryKind.INGRESO, Cycle.Puntual)
            QuickActionKind.FIJO -> adding = AddRequest(EntryKind.GASTO, Cycle.Mensual)
            QuickActionKind.SUELDO -> adding = AddRequest(EntryKind.INGRESO, Cycle.Mensual)
            QuickActionKind.ANUAL -> adding = AddRequest(EntryKind.GASTO, Cycle.Anual)
            QuickActionKind.FIJOS -> route = Route.FIJOS
            else -> android.widget.Toast.makeText(context, "${kind.title} llega en la siguiente fase de Android.", android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    BackHandler(enabled = route != null) { route = null }

    Box(Modifier.fillMaxSize()) {
        when {
            route == Route.FIJOS -> FixedScreen(store, onBack = { route = null }, onAdd = { adding = AddRequest(EntryKind.GASTO, Cycle.Mensual) })
            tab == AppTab.Inicio -> HomeScreen(store, ::perform) { more = true }
            tab == AppTab.Ajustes -> SettingsScreen(store)
            else -> Soon(tab.title)
        }
        GlassTabBar(
            selected = tab, tint = GlassLevel.from(glass).tint,
            onSelect = { tab = it; route = null },
            modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(horizontal = Spacing.s4, vertical = Spacing.s2),
        )
    }

    adding?.let { request ->
        val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet({ adding = null }, sheetState = state, containerColor = Palette.superficie2, shape = RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)) {
            AddEntryContent(store, request) { scope.launch { state.hide() }.invokeOnCompletion { adding = null } }
        }
    }
    if (more) {
        ModalBottomSheet({ more = false }, containerColor = Palette.superficie2, shape = RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)) {
            MoreContent(store) { kind -> more = false; perform(kind) }
        }
    }
}

@Composable
private fun Soon(title: String) {
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(Spacing.margen), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        T(title, Type.titulo1)
        T("Esta pantalla llega en la siguiente fase de Android. En el iPhone ya está lista.", Type.cuerpo, Palette.texto2)
    }
}

@Composable
fun GlassTabBar(selected: AppTab, tint: Float, onSelect: (AppTab) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().height(Size.barra).clip(CircleShape).background(Palette.vidrioTinte.copy(alpha = tint))
            .border(1.dp, Palette.vidrioBorde, CircleShape).padding(Spacing.s2),
        horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically,
    ) {
        AppTab.entries.forEach { item ->
            val active = item == selected
            Column(
                Modifier.weight(1f).height(Size.toqueMinimo).clip(CircleShape)
                    .background(if (active) Palette.texto1.copy(alpha = 0.10f) else Color.Transparent).clickable { onSelect(item) },
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                val c = if (active) Palette.brasaTinta else Palette.texto2
                T(item.glyph, Type.etiqueta, c)
                T(item.title, Type.leyenda.copy(letterSpacing = androidx.compose.ui.unit.TextUnit.Unspecified), c, maxLines = 1)
            }
        }
    }
}
