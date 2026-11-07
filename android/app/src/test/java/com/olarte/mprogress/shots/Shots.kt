package com.olarte.mprogress.shots

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import com.olarte.mprogress.ui.home.AddEntryContent
import com.olarte.mprogress.ui.home.AddRequest
import com.olarte.mprogress.ui.home.MoreContent
import com.olarte.mprogress.ui.theme.Radius
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.olarte.mprogress.MainActivity
import com.olarte.mprogress.data.BankDraft
import com.olarte.mprogress.data.FixedDraft
import com.olarte.mprogress.data.OnboardingDraft
import com.olarte.mprogress.data.ProductDraft
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.AmountInput
import com.olarte.mprogress.domain.Cycle
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.ProductKind
import com.olarte.mprogress.ui.onboarding.OnboardingScreen
import com.olarte.mprogress.ui.onboarding.OnboardingState
import com.olarte.mprogress.ui.onboarding.OnboardingStep
import com.olarte.mprogress.ui.onboarding.PlannedProduct
import com.olarte.mprogress.ui.theme.DarkColors
import com.olarte.mprogress.ui.theme.LightColors
import com.olarte.mprogress.ui.theme.LocalColors
import com.olarte.mprogress.ui.theme.Palette
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import android.os.Looper
import java.time.LocalDate

/** Capturas de pantalla para comparar con iOS. Se generan en build/shots. No es una prueba de lógica. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class Shots {
    private fun shot(name: String, dark: Boolean = true, content: @Composable () -> Unit) {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        activity.setContent {
            CompositionLocalProvider(LocalColors provides if (dark) DarkColors else LightColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { content() }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        activity.window.decorView.captureRoboImage("build/shots/$name.png")
        controller.pause().stop().destroy()
    }

    private fun demoState(step: OnboardingStep) = OnboardingState().apply {
        income = AmountInput(text = "4000000")
        addBank("Bancolombia")
        val bank = banks.first()
        addProduct(PlannedProduct(ProductKind.CREDITO, "Crédito Oro", "4417"), bank.id)
        this.step = step
    }

    @Test fun onboarding() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        shot("01a_bienvenida") { OnboardingScreen(store) }
        shot("01b_ingreso") { OnboardingScreen(store, OnboardingState().apply { step = OnboardingStep.INGRESO; income = AmountInput(text = "4000000") }) }
        shot("01c_bancos") { OnboardingScreen(store, demoState(OnboardingStep.BANCOS)) }
        shot("01d_fijos") { OnboardingScreen(store, demoState(OnboardingStep.FIJOS)) }
        shot("01e_fechas") {
            OnboardingScreen(store, demoState(OnboardingStep.FECHAS).apply {
                val credit = plannedProducts.first { it.kind == ProductKind.CREDITO }.id
                incomeProductId = plannedProducts.first().id
                selectedFixed.forEach { setProduct(credit, it.id) }
                setDay(12, selectedFixed.first().id)
            })
        }
        shot("01f_intereses") { OnboardingScreen(store, demoState(OnboardingStep.INTERESES)) }
        shot("01g_funciones") { OnboardingScreen(store, demoState(OnboardingStep.FUNCIONES)) }
        shot("01h_bienvenida_claro", dark = false) { OnboardingScreen(store) }
    }

    private fun seed(store: Store) {
        if (store.onboarded.value) return
        store.finishOnboarding(OnboardingDraft(incomeMinor = 4_000_000_00, incomeDay = 1,
            banks = listOf(BankDraft("Bancolombia", listOf(ProductDraft(ProductKind.CUENTA, "Cuenta de ahorros"), ProductDraft(ProductKind.CREDITO, "Crédito Oro", "4417")))),
            fixed = listOf(FixedDraft("Gimnasio", 119_900_00, LocalDate.now().plusDays(2).dayOfMonth), FixedDraft("Música", 8_000_00, null))))
        store.add(EntryKind.GASTO, "Éxito", 84_300_00, Cycle.Puntual, LocalDate.now(), null)
    }

    /** Hoja inferior como la de la app: esquinas de 36 sobre la pantalla oscurecida. */
    @Composable
    private fun SheetFrame(top: Int, content: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f))) {
            Box(Modifier.fillMaxSize().padding(top = top.dp).clip(RoundedCornerShape(topStart = Radius.hoja, topEnd = Radius.hoja)).background(Palette.superficie2)) { content() }
        }
    }

    @Test fun hojas() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        shot("03a_agregar") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Puntual)) {} } }
        shot("03b_agregar_fijo") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Mensual)) {} } }
        shot("03c_mas") { SheetFrame(200) { MoreContent(store) {} } }
    }

    @Test fun ajustes() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        shot("04a_ajustes") { com.olarte.mprogress.ui.settings.SettingsScreen(store) }
        shot("04b_apariencia") { com.olarte.mprogress.ui.settings.AppearanceScreen(store) {} }
        shot("04c_icono") { com.olarte.mprogress.ui.settings.AppIconScreen {} }
        shot("04d_ajustes_claro", dark = false) { com.olarte.mprogress.ui.settings.SettingsScreen(store) }
    }

    @Test fun pantallas() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        shot("05a_dinero_vacio") { com.olarte.mprogress.ui.money.MoneyScreen(store) }
        shot("05h_historial_vacio") { com.olarte.mprogress.ui.history.HistoryScreen(store) {} }
        seed(store)
        val today = LocalDate.now()
        store.add(EntryKind.GASTO, "Mercado", 120_000_00, Cycle.Puntual, today.minusMonths(1), null)
        store.add(EntryKind.INGRESO, "Sueldo", 4_000_000_00, Cycle.Puntual, today.minusMonths(1).withDayOfMonth(1), null)
        store.add(EntryKind.GASTO, "Cine", 32_000_00, Cycle.Puntual, today.minusDays(1), null)
        val bank = store.ledger.value.institutions.first().id
        store.addProduct(bank, ProductKind.BOLSILLO, "Emergencias", null, 1_500_000_00, null)
        store.addInstitution("Nu", 0xA68CFF)
        shot("05b_dinero") { com.olarte.mprogress.ui.money.MoneyScreen(store) }
        shot("05c_banco") { com.olarte.mprogress.ui.money.MoneyScreen(store, bank) }
        shot("05d_resumen") { com.olarte.mprogress.ui.summary.SummaryScreen(store) }
        shot("05e_calendario") { com.olarte.mprogress.ui.calendar.CalendarScreen(store) }
        shot("05f_historial") { com.olarte.mprogress.ui.history.HistoryScreen(store) {} }
        shot("05g_fijos") { com.olarte.mprogress.ui.fixed.FixedScreen(store, {}, {}) }
    }

    @Test fun fase04() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        val e = store.add(EntryKind.GASTO, "Mercado", 120_000_00, Cycle.Puntual, LocalDate.now(), store.ledger.value.products.first().id,
            categoryId = com.olarte.mprogress.domain.Categories.byName("Mercado")!!.id, notes = "Compra de la semana")!!
        store.add(EntryKind.GASTO, "Celular", 300_000_00, Cycle.Mensual, LocalDate.now().plusDays(4), null, totalCount = 12)
        val gym = store.ledger.value.recurring.first { it.name == "Gimnasio" }.id
        shot("06a_detalle") { SheetFrame(40) { com.olarte.mprogress.ui.home.EntryDetailSheet(store, e.id) {} } }
        shot("06b_pago_fijo") { com.olarte.mprogress.ui.home.RecurringEditSheet(store, gym) {} }
        shot("06c_categorias") { com.olarte.mprogress.ui.home.CategoryPickerSheet(store.ledger.value.entries, e.categoryId, {}) {} }
        shot("06d_agregar_fijo") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Mensual)) {} } }
        shot("06e_fijos") { com.olarte.mprogress.ui.fixed.FixedScreen(store, {}, {}) }
        shot("06f_resumen") { com.olarte.mprogress.ui.summary.SummaryScreen(store) }
        shot("06g_aviso") { com.olarte.mprogress.ui.home.AlertEditSheet(store, store.ledger.value.recurring.first { it.id == gym },
            com.olarte.mprogress.domain.AlertRule(com.olarte.mprogress.domain.AlertMode.PERSONALIZADO, 2, 600), {}) {} }
    }

    @Test fun fase05() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        shot("07a_avisos") { com.olarte.mprogress.ui.settings.AlertsScreen(store) {} }
        shot("07b_moneda") { com.olarte.mprogress.ui.settings.CurrencyScreen(store) {} }
        shot("07c_respaldo") { com.olarte.mprogress.ui.settings.BackupScreen(store) {} }
        shot("07d_ajustes") { com.olarte.mprogress.ui.settings.SettingsScreen(store) }
        shot("07e_bloqueo") { com.olarte.mprogress.ui.LockGate(true) { } }
    }

    @Test fun fase06() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        val l = store.ledger.value
        val credit = l.products.first { it.kind == ProductKind.CREDITO }
        store.saveReward(com.olarte.mprogress.domain.RewardRecord(id = "r1", name = "LifeMiles", kind = com.olarte.mprogress.domain.RewardKind.MILLAS, balance = 12_450))
        store.saveProduct(credit.copy(creditLimitMinor = 8_000_000_00, cutDay = 25, dueDay = 10, rewardProgramId = "r1", pointsPerThousand = 2.0))
        store.add(EntryKind.GASTO, "Éxito", 84_300_00, Cycle.Puntual, LocalDate.now(), credit.id, categoryId = com.olarte.mprogress.domain.Categories.byName("Mercado")!!.id)
        store.saveBudget(com.olarte.mprogress.domain.BudgetRecord(categoryId = null, limitMinor = 2_000_000_00))
        store.saveBudget(com.olarte.mprogress.domain.BudgetRecord(categoryId = com.olarte.mprogress.domain.Categories.byName("Mercado")!!.id, limitMinor = 150_000_00))
        store.saveGoal(com.olarte.mprogress.domain.GoalRecord(name = "Viaje juntos", targetMinor = 5_000_000_00, targetDate = LocalDate.now().plusMonths(8)))
        store.addContribution(com.olarte.mprogress.domain.ContributionRecord(goalId = store.ledger.value.goals.first().id, amountMinor = 2_400_000_00, occurredAt = LocalDate.now()))
        val cash = store.addInstitution("Efectivo", 0x3A3F47)
        store.addProduct(cash, ProductKind.EFECTIVO, "Billetera", null, 120_000_00, null)
        store.addProduct(cash, ProductKind.EFECTIVO, "Alcancía", null, 45_000_00, null)
        shot("08a_dinero") { com.olarte.mprogress.ui.money.MoneyScreen(store) }
        shot("08b_transferir") { com.olarte.mprogress.ui.money.TransferSheet(store) {} }
        shot("08c_limites") { com.olarte.mprogress.ui.planning.BudgetsScreen(store) {} }
        shot("08d_ahorro") { com.olarte.mprogress.ui.planning.SavingsScreen(store) {} }
        shot("08e_efectivo") { com.olarte.mprogress.ui.money.MoneyScreen(store, cash) }
    }

    @Test fun fase07() {
        shot("09a_recibo") { com.olarte.mprogress.ui.auto.ReceiptScanSheet({}) { _, _ -> } }
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        shot("09b_agregar_recibo") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Puntual, "Farmacia Pasteur", 32_400_00, "recibo")) {} } }
    }

    @Test fun fase08() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        val t = LocalDate.now()
        store.add(EntryKind.GASTO, "Mercado", 900_000_00, Cycle.Puntual, t.minusMonths(1), null)
        store.add(EntryKind.GASTO, "Salida", 1_200_000_00, Cycle.Puntual, t.withDayOfMonth(1), null)
        shot("10a_resumen_este_mes") { com.olarte.mprogress.ui.summary.SummaryScreen(store) }
        shot("10b_inicio_te_pasaste") { com.olarte.mprogress.ui.home.HomeScreen(store, {}, {}, {}, {}) }
        shot("10c_dia_del_mes") { SheetFrame(40) { AddEntryContent(store, AddRequest(EntryKind.GASTO, Cycle.Mensual)) {} } }
    }

    /** PLAN_F12B Paso 4 sin predicciones: sueldo de $ 2 en Inicio, próximos cargos plegables y Este mes en Resumen. */
    @Test fun sinPredicciones() {
        val store = Store.get(ApplicationProvider.getApplicationContext())
        seed(store)
        val t = LocalDate.now()
        store.add(EntryKind.INGRESO, "Sueldo", 2_00, Cycle.Mensual, t.plusDays(5), null)
        listOf("Internet" to 95_000_00L, "Celular" to 60_000_00L, "Arriendo" to 1_200_000_00L, "Seguro" to 80_000_00L).forEachIndexed { i, (n, v) ->
            store.add(EntryKind.GASTO, n, v, Cycle.Mensual, t.plusDays(3L + i), null)
        }
        shot("12m_inicio_sueldo_raro") { com.olarte.mprogress.ui.home.HomeScreen(store, {}, {}, {}, {}) }
        store.setUpcomingExpanded(true)
        shot("12n_inicio_proximos_abiertos") { com.olarte.mprogress.ui.home.HomeScreen(store, {}, {}, {}, {}) }
        store.setUpcomingExpanded(false)
        shot("12o_resumen_este_mes") { com.olarte.mprogress.ui.summary.SummaryScreen(store) }
    }

    @Test fun fase09() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val store = Store.get(ctx)
        seed(store)
        com.olarte.mprogress.auto.AutoCapture.handle(ctx, "notificacion", "com.google.android.apps.walletnfcrel", "ÉXITO CALLE 80", "\$ 84.300,00 con Visa •••• 4417")
        com.olarte.mprogress.auto.AutoCapture.handle(ctx, "notificacion", "com.nequi.MobileApp", "Nequi", "Pagaste \$45.500 en RAPPI")
        shot("11a_automatico") { com.olarte.mprogress.ui.auto.AutoCaptureScreen(store, {}, {}) {} }
    }

    @Test fun fase10() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val store = Store.get(ctx)
        seed(store)
        val cloud = com.olarte.mprogress.data.cloud.CloudAccount(store, com.olarte.mprogress.data.cloud.MemorySecretStore())
        com.olarte.mprogress.data.cloud.CloudAccount.install(cloud)
        val me = "0d000000-0000-4000-8000-00000000000a"
        val now = java.time.Instant.now()
        val pixel = com.olarte.mprogress.data.cloud.RemoteDevice(me, "Galaxy S24 de Juan", "android", "AAAA", now.minusSeconds(86400 * 3), now)
        val iphone = com.olarte.mprogress.data.cloud.RemoteDevice("0d000000-0000-4000-8000-00000000000b", "iPhone 18 Pro", "ios", "BBBB", now.minusSeconds(86400 * 20), now)
        val tablet = com.olarte.mprogress.data.cloud.RemoteDevice("0d000000-0000-4000-8000-00000000000c", null, "android", "CCCC", now, now)
        val base = com.olarte.mprogress.data.cloud.CloudUi(thisDeviceId = me, email = "juan@correo.com")
        fun account(name: String, ui: com.olarte.mprogress.data.cloud.CloudUi, dark: Boolean = true) {
            cloud.preview(ui)
            shot(name, dark) { com.olarte.mprogress.ui.settings.AccountScreen(cloud) {} }
        }
        account("12a_cuenta_entrar", com.olarte.mprogress.data.cloud.CloudUi(thisDeviceId = me))
        account("12b_cuenta_enlace", base.copy(phase = com.olarte.mprogress.data.cloud.CloudPhase.LinkSent("juan@correo.com"), email = null))
        account("12c_cuenta_conectando", base.copy(phase = com.olarte.mprogress.data.cloud.CloudPhase.Connecting))
        account("12d_cuenta_aprobar", base.copy(phase = com.olarte.mprogress.data.cloud.CloudPhase.NeedsApproval))
        val ready = base.copy(phase = com.olarte.mprogress.data.cloud.CloudPhase.Ready, lastSyncAt = now.minusSeconds(180), devices = listOf(iphone, pixel, tablet))
        account("12e_cuenta_lista", ready)
        account("12f_cuenta_nuevo_dispositivo", ready.copy(pendingApprovals = listOf(tablet)))
        account("12g_cuenta_lista_claro", ready.copy(status = com.olarte.mprogress.domain.SyncStatus.Error("2 cambios no subieron")), dark = false)
        cloud.preview(ready.copy(pendingApprovals = listOf(tablet)))
        shot("12h_dispositivos") { com.olarte.mprogress.ui.settings.DevicesScreen(cloud) {} }
        shot("12i_codigo") { com.olarte.mprogress.ui.settings.RecoveryCodeScreen("CAJT-EE2W-CWMB-QGA3-DJPT-2HJ8") {} }
        cloud.preview(ready.copy(status = com.olarte.mprogress.domain.SyncStatus.SinConexion(3)))
        shot("12j_inicio_sin_conexion") { com.olarte.mprogress.ui.home.HomeScreen(store, {}, {}, {}, {}) }
        shot("12k_ajustes_con_cuenta") { com.olarte.mprogress.ui.settings.SettingsScreen(store) }
        cloud.preview(ready.copy(approvalPrompt = tablet))
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        controller.get().setContent {
            CompositionLocalProvider(LocalColors provides DarkColors) {
                Box(Modifier.fillMaxSize().background(Palette.fondo)) { com.olarte.mprogress.ui.settings.ApprovalPrompt(cloud) }
            }
        }
        shadowOf(Looper.getMainLooper()).idle()
        com.github.takahirom.roborazzi.captureScreenRoboImage("build/shots/12l_aprobar_aviso.png")
        controller.pause().stop().destroy()
    }

    @Test fun capturas() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val store = Store.get(ctx)
        store.finishOnboarding(OnboardingDraft(incomeMinor = 4_000_000_00, incomeDay = 1,
            banks = listOf(BankDraft("Bancolombia", listOf(ProductDraft(ProductKind.CUENTA, "Cuenta de ahorros"), ProductDraft(ProductKind.CREDITO, "Crédito Oro", "4417")))),
            fixed = listOf(FixedDraft("Gimnasio", 119_900_00, LocalDate.now().plusDays(2).dayOfMonth), FixedDraft("Música", 8_000_00, null))))
        store.add(EntryKind.GASTO, "Éxito", 84_300_00, Cycle.Puntual, LocalDate.now(), null)
        ActivityScenario.launch(MainActivity::class.java).use { s ->
            s.onActivity { it.window.decorView.captureRoboImage("build/shots/02_inicio.png") }
        }
    }
}
