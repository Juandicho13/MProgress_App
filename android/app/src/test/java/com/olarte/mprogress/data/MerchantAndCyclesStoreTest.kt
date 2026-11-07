package com.olarte.mprogress.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.olarte.mprogress.domain.*
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** Nombres de comercios, marcar pagado con otro valor y pagos cada N meses en la base de Android. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class MerchantAndCyclesStoreTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val salidas = Categories.byName("Salidas")!!.id
    private lateinit var file: File

    private fun newStore(): Store {
        val dir = File(context.filesDir, "prueba-${UUID.randomUUID()}").apply { mkdirs() }
        file = File(dir, "mprogress.json")
        return Store(file, context.getSharedPreferences("prueba-${UUID.randomUUID()}", Context.MODE_PRIVATE))
    }

    @Test fun renombrarUnPagoAutomaticoAprendeYElSiguienteLlegaConEseNombre() {
        val store = newStore()
        val e = store.add(EntryKind.GASTO, "Pepepollo Sas 123", 32_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 2), null, source = "sms", merchant = "Pepepollo Sas 123")!!
        assertTrue(store.ledger.value.merchantAliases.isEmpty())
        store.updateEntry(store.ledger.value.entries.first { it.id == e.id }.copy(name = "El Corral", categoryId = salidas))
        val rule = store.ledger.value.merchantAliases.single()
        assertEquals("PEPEPOLLO", rule.key); assertEquals("El Corral", rule.name); assertEquals(salidas, rule.categoryId)
        assertEquals(rule, store.merchantAlias("PEPEPOLLO SAS 456"))
        // Guardar lo mismo otra vez no crea otra regla ni la cambia.
        val before = store.ledger.value.merchantAliases
        store.updateEntry(store.ledger.value.entries.first { it.id == e.id }.copy(amountMinor = 33_000_00))
        assertSame(before, store.ledger.value.merchantAliases)
    }

    @Test fun manualNoAprendeYReciboSi() {
        val store = newStore()
        store.add(EntryKind.GASTO, "Mercado", 10_000_00, Cycle.Puntual, LocalDate.now(), null)
        assertTrue(store.ledger.value.merchantAliases.isEmpty())
        store.add(EntryKind.GASTO, "Droguería", 9_900_00, Cycle.Puntual, LocalDate.now(), null, source = "recibo", merchant = "Farmatodo Sas")
        assertEquals("FARMATODO", store.ledger.value.merchantAliases.single().key)
        assertNull(store.add(EntryKind.GASTO, "x", 1_00, Cycle.Puntual, LocalDate.now(), null)?.merchant)
    }

    @Test fun cambiarYBorrarConDeshacer() {
        val store = newStore()
        store.add(EntryKind.GASTO, "Éxito", 9_900_00, Cycle.Puntual, LocalDate.now(), null, source = "notificacion", merchant = "EXITO CALLE 80", categoryId = salidas)
        val rule = store.ledger.value.merchantAliases.single()
        store.updateMerchantAlias(rule.id, "  Éxito Calle 80 ", null)
        assertEquals("Éxito Calle 80", store.ledger.value.merchantAliases.single().name)
        assertNull(store.ledger.value.merchantAliases.single().categoryId)
        val saved = store.ledger.value.merchantAliases.single()
        store.deleteMerchantAlias(saved.id)
        assertNull(store.merchantAlias("EXITO CALLE 80"))
        store.restoreMerchantAlias(saved)
        assertEquals("Éxito Calle 80", store.merchantAlias("EXITO CALLE 80")?.name)
    }

    @Test fun marcarPagadoGuardaLoQueSePagoYCadaDosMesesMueveLaFecha() {
        val store = newStore()
        store.add(EntryKind.GASTO, "Energía", 120_000_00, Cycle.CadaMeses(2), LocalDate.of(2026, 11, 10), null, today = LocalDate.of(2026, 11, 6))
        val r = store.ledger.value.recurring.single()
        val (entry, finished) = store.markPaid(r.id, LocalDate.of(2026, 11, 10), amountMinor = 98_500_00)!!
        assertEquals(98_500_00, entry.amountMinor)
        assertEquals(false, finished)
        val after = store.ledger.value.recurring.single()
        assertEquals(120_000_00, after.amountMinor)
        assertEquals(LocalDate.of(2027, 1, 10), after.nextDate)
        // Sin monto (o con cero) usa el planeado.
        assertEquals(120_000_00, store.markPaid(r.id, LocalDate.of(2027, 1, 10), amountMinor = 0)!!.first.amountMinor)
    }

    @Test fun archivoYRespaldoGuardanLoNuevo() {
        val store = newStore()
        store.add(EntryKind.GASTO, "El Corral", 32_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 2), null, source = "sms", merchant = "PEPEPOLLO SAS 123")
        store.add(EntryKind.GASTO, "Seguro", 300_000_00, Cycle.CadaMeses(6), LocalDate.of(2026, 12, 1), null, today = LocalDate.of(2026, 11, 6))
        val reopened = Store(file, context.getSharedPreferences("otra-${UUID.randomUUID()}", Context.MODE_PRIVATE)).ledger.value
        assertEquals(store.ledger.value.merchantAliases, reopened.merchantAliases)
        assertEquals(Cycle.CadaMeses(6), reopened.recurring.single().cycle)
        assertEquals("PEPEPOLLO SAS 123", reopened.entries.single().merchant)

        val json = BackupCodec.encode(store.ledger.value, Currency.COP)
        assertEquals(6, json.getJSONArray("recurring").getJSONObject(0).getInt("intervalMonths"))
        val (restored, _) = BackupCodec.decode(json.toString())
        assertEquals(store.ledger.value.merchantAliases, restored.merchantAliases)
        assertEquals(Cycle.CadaMeses(6), restored.recurring.single().cycle)
        // Un respaldo de antes (sin intervalMonths) sigue siendo mensual.
        json.getJSONArray("recurring").getJSONObject(0).remove("intervalMonths")
        assertEquals(Cycle.Mensual, BackupCodec.decode(json.toString()).first.recurring.single().cycle)
    }
}
