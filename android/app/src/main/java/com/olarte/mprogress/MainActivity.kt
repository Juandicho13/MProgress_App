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
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
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
import com.olarte.mprogress.ui.components.Sym
import androidx.compose.foundation.layout.size
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

class MainActivity : androidx.fragment.app.FragmentActivity() {
    override fun onResume() {
        super.onResume()
        // Al volver a primer plano se sincroniza (si hay cuenta).
        runCatching { com.olarte.mprogress.data.cloud.CloudAccount.get(this).syncNow() }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        com.olarte.mprogress.auto.LaunchAction.from(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = Store.get(this)
        // Al recrear la pantalla (girar) no se repite la acción ni el enlace del correo.
        if (savedInstanceState == null) com.olarte.mprogress.auto.LaunchAction.from(intent)
        // Ningún gestor de contraseñas (Samsung Pass, Google) ofrece llenar campos en esta ventana.
        window.decorView.importantForAutofill = android.view.View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
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
                val lock by store.lock.collectAsState()
                // Con el teclado abierto todo se acomoda encima de él (adjustResize con edge-to-edge): las hojas suben
                // y las listas que se desplazan dejan ver el campo que tiene el foco.
                Box(Modifier.fillMaxSize().background(Palette.fondo).imePadding()) {
                    com.olarte.mprogress.ui.LockGate(lock && onboarded) {
                        if (onboarded) RootScreen(store) else OnboardingScreen(store)
                    }
                    NotificationAsk(store)
                    if (onboarded) CloudOverlays()
                }
            }
        }
    }
}

/** Lo de la cuenta que sale encima de todo: el enlace del correo, el código de recuperación recién creado y aprobar otro dispositivo. */
@Composable
fun CloudOverlays() {
    val context = LocalContext.current
    val cloud = remember { runCatching { com.olarte.mprogress.data.cloud.CloudAccount.get(context) }.getOrNull() } ?: return
    val callback by com.olarte.mprogress.auto.LaunchAction.authCallback.collectAsState()
    LaunchedEffect(callback) {
        callback?.let { cloud.handle(it); com.olarte.mprogress.auto.LaunchAction.authCallback.value = null }
    }
    val ui by cloud.ui.collectAsState()
    ui.recoveryCode?.let { code -> com.olarte.mprogress.ui.settings.RecoveryCodeScreen(code) { cloud.dismissRecoveryCode() } }
    com.olarte.mprogress.ui.settings.ApprovalPrompt(cloud)
}

/** "¿Te aviso antes de cada pago?": se pregunta en el momento justo (Paso 2), nunca al abrir la app sin contexto. */
@Composable
fun NotificationAsk(store: Store) {
    val ask by com.olarte.mprogress.ui.Permissions.ask.collectAsState()
    val context = LocalContext.current
    val launcher = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) {
        com.olarte.mprogress.notify.Notifier.reschedule(context, store)
    }
    if (!ask) return
    fun close() { store.prefs.edit().putBoolean(com.olarte.mprogress.notify.Notifier.KEY_ASKED, true).apply(); com.olarte.mprogress.ui.Permissions.done() }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = { close() },
        title = { T("¿Te aviso antes de cada pago?", Type.titulo3) },
        text = { T("Te escribo unos días antes de cada pago fijo y cuando te acerques a un límite. Lo cambias cuando quieras en Ajustes › Avisos.", Type.cuerpo2, Palette.texto2) },
        confirmButton = { androidx.compose.material3.TextButton({
            close()
            if (android.os.Build.VERSION.SDK_INT >= 33) launcher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }) { T("Sí, avísame", Type.etiqueta, Palette.brasaTinta) } },
        dismissButton = { androidx.compose.material3.TextButton({ close() }) { T("Ahora no", Type.etiqueta) } },
        containerColor = Palette.superficie2,
    )
}

enum class AppTab(val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector, val iconOn: androidx.compose.ui.graphics.vector.ImageVector) {
    Inicio("Inicio", Sym.house, Sym.houseFill), Resumen("Resumen", Sym.chart, Sym.chartFill), Dinero("Dinero", Sym.bank, Sym.bankFill),
    Calendario("Calendario", Sym.calendar, Sym.calendarFill), Ajustes("Ajustes", Sym.gear, Sym.gearFill)
}

enum class Route { FIJOS, HISTORIAL, LIMITES, AHORRO, AUTOMATICO }

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun RootScreen(store: Store) {
    var tab by remember { mutableStateOf(AppTab.Inicio) }
    var route by remember { mutableStateOf<Route?>(null) }
    var adding by remember { mutableStateOf<AddRequest?>(null) }
    var more by remember { mutableStateOf(false) }
    var entryDetail by remember { mutableStateOf<String?>(null) }
    var recurringEdit by remember { mutableStateOf<String?>(null) }
    var scanning by remember { mutableStateOf(false) }
    val undo by store.undo.collectAsState()
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
            QuickActionKind.HISTORIAL -> route = Route.HISTORIAL
            QuickActionKind.LIMITES -> route = Route.LIMITES
            QuickActionKind.RECIBO -> scanning = true
            QuickActionKind.AUTOMATICO -> route = Route.AUTOMATICO
            QuickActionKind.AHORRO -> route = Route.AHORRO
            else -> android.widget.Toast.makeText(context, "${kind.title} llega pronto a Android.", android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    BackHandler(enabled = route != null) { route = null }
    val launch by com.olarte.mprogress.auto.LaunchAction.pending.collectAsState()
    androidx.compose.runtime.LaunchedEffect(launch) {
        when (launch) {
            "gasto" -> adding = AddRequest(EntryKind.GASTO, Cycle.Puntual)
            "fijos" -> route = Route.FIJOS
            "calendario" -> { route = null; tab = AppTab.Calendario }
            "inicio" -> { route = null; tab = AppTab.Inicio }
            "revisar" -> route = Route.AUTOMATICO
            "cuenta" -> { route = null; tab = AppTab.Ajustes; com.olarte.mprogress.ui.settings.SettingsNav.page.value = "cuenta" }
        }
        if (launch != null) com.olarte.mprogress.auto.LaunchAction.pending.value = null
    }

    Box(Modifier.fillMaxSize()) {
        when {
            route == Route.FIJOS -> FixedScreen(store, onBack = { route = null }, onAdd = { k -> adding = AddRequest(k, Cycle.Mensual) }, onEdit = { recurringEdit = it })
            route == Route.HISTORIAL -> com.olarte.mprogress.ui.history.HistoryScreen(store, onAdd = { adding = AddRequest(EntryKind.GASTO, Cycle.Puntual) }, onOpenEntry = { entryDetail = it }) { route = null }
            route == Route.AUTOMATICO -> com.olarte.mprogress.ui.auto.AutoCaptureScreen(store, onReview = { c ->
                adding = AddRequest(c.kind, Cycle.Puntual, c.merchant ?: c.bank.orEmpty(), c.amountMinor, c.source,
                    com.olarte.mprogress.auto.AutoCapture.matchProduct(store.ledger.value, com.olarte.mprogress.domain.ParsedCharge(c.kind, c.amountMinor, c.merchant, c.last4, c.bank)))
                store.removeCapture(c.id)
            }, onOpenEntry = { entryDetail = it }, onScan = { scanning = true }) { route = null }
            route == Route.LIMITES -> com.olarte.mprogress.ui.planning.BudgetsScreen(store) { route = null }
            route == Route.AHORRO -> com.olarte.mprogress.ui.planning.SavingsScreen(store) { route = null }
            tab == AppTab.Inicio -> HomeScreen(store, ::perform, onMore = { more = true }, onOpenFixed = { route = Route.FIJOS }, onOpenHistory = { route = Route.HISTORIAL }, onOpenEntry = { entryDetail = it })
            tab == AppTab.Resumen -> com.olarte.mprogress.ui.summary.SummaryScreen(store)
            tab == AppTab.Dinero -> com.olarte.mprogress.ui.money.MoneyScreen(store)
            tab == AppTab.Calendario -> com.olarte.mprogress.ui.calendar.CalendarScreen(store, onOpenEntry = { entryDetail = it })
            else -> SettingsScreen(store)
        }
        // Con el teclado abierto la barra se esconde para no tapar lo que escribes.
        if (!WindowInsets.isImeVisible) GlassTabBar(
            selected = tab, tint = GlassLevel.from(glass).tint,
            onSelect = { tab = it; route = null },
            modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(horizontal = Spacing.s4, vertical = Spacing.s2),
        )
        entryDetail?.let { id -> com.olarte.mprogress.ui.components.SheetPanel({ entryDetail = null }) { com.olarte.mprogress.ui.home.EntryDetailSheet(store, id) { entryDetail = null } } }
        recurringEdit?.let { id -> com.olarte.mprogress.ui.home.RecurringEditSheet(store, id) { recurringEdit = null } }
        if (scanning) com.olarte.mprogress.ui.auto.ReceiptScanSheet({ scanning = false }) { merchant, amount ->
            scanning = false; adding = AddRequest(EntryKind.GASTO, Cycle.Puntual, merchant.orEmpty(), amount ?: 0, "recibo")
        }
        com.olarte.mprogress.ui.components.UndoToast(undo, Size.barra + Spacing.s4) { store.clearUndo() }
    }

    adding?.let { request ->
        val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet({ adding = null }, sheetState = state, dragHandle = null, containerColor = Palette.superficie2, shape = RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)) {
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
                androidx.compose.material3.Icon(if (active) item.iconOn else item.icon, null, Modifier.padding(bottom = 2.dp).size(22.dp), tint = c)
                T(item.title, Type.pestana.copy(fontWeight = if (active) androidx.compose.ui.text.font.FontWeight.SemiBold else androidx.compose.ui.text.font.FontWeight.Medium), c, maxLines = 1)
            }
        }
    }
}
