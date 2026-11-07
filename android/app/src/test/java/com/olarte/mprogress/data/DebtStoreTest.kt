package com.olarte.mprogress.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.olarte.mprogress.data.cloud.AndroidCrypto
import com.olarte.mprogress.domain.*
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** Quién te debe en la base de Android: saldos de la cuenta elegida, abonos, borrar con Deshacer, respaldo y nube. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DebtStoreTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val today = LocalDate.now()
    private fun pesos(v: Long) = v * 100
    private lateinit var file: File

    private fun newStore(): Store {
        val dir = File(context.filesDir, "deudas-${UUID.randomUUID()}").apply { mkdirs() }
        file = File(dir, "mprogress.json")
        return Store(file, context.getSharedPreferences("deudas-${UUID.randomUUID()}", Context.MODE_PRIVATE))
    }

    private fun Store.account(): Product {
        val bank = addInstitution("Bancolombia")
        val id = addProduct(bank, ProductKind.CUENTA, "Ahorros", null, pesos(1_000_000), null)
        return ledger.value.product(id)!!
    }

    private fun Store.balance(id: String) = ledger.value.balance(ledger.value.product(id)!!)

    @Test fun prestarDesdeUnaCuentaMueveSuSaldoSinContarComoGastoDelMes() {
        val store = newStore()
        val cuenta = store.account()
        val d = store.saveDebt(null, "  Ana   María ", DebtDirection.ME_DEBE, pesos(300_000), today, today.plusDays(10), " Almuerzo ", cuenta.id)
        assertEquals("Ana María", d.person); assertEquals("Almuerzo", d.note); assertNotNull(d.transferId)
        assertEquals(pesos(700_000), store.balance(cuenta.id))
        val t = store.ledger.value.transfers.single()
        assertEquals(cuenta.id, t.fromProductId); assertEquals(DebtMath.OUTSIDE_PRODUCT_ID, t.toProductId); assertEquals("Préstamo a Ana María", t.note)
        // No es gasto ni ingreso: Te quedan este mes no cambia y el patrimonio solo baja lo que salió de la cuenta.
        assertTrue(store.ledger.value.entries.isEmpty())
        assertEquals(pesos(700_000), MoneyCalculator.netWorth(store.ledger.value.productRecords, emptyList(), store.ledger.value.transfers).third)

        val abono = store.addDebtPayment(d.id, pesos(100_000), today, cuenta.id)!!
        assertEquals(pesos(800_000), store.balance(cuenta.id))
        assertEquals(DebtMath.OUTSIDE_PRODUCT_ID, store.ledger.value.transfers.first { it.id == abono.transferId }.fromProductId)
        // De más no se puede: queda en lo que falta.
        val resto = store.addDebtPayment(d.id, pesos(900_000), today, null)!!
        assertEquals(pesos(200_000), resto.amountMinor)
        assertNull(store.addDebtPayment(d.id, pesos(1), today, null))
        assertEquals(DebtStatus.SALDADA, DebtMath.status(store.ledger.value.debts.single(), store.ledger.value.debtPayments, today))
        assertEquals(pesos(800_000), store.balance(cuenta.id))
    }

    @Test fun editarQuitaOVoltealaPlataYSaldarCierraLaDeuda() {
        val store = newStore()
        val cuenta = store.account()
        var d = store.saveDebt(null, "Carlos", DebtDirection.LE_DEBO, pesos(80_000), today, null, null, cuenta.id)
        assertEquals(pesos(1_080_000), store.balance(cuenta.id))
        store.addDebtPayment(d.id, pesos(30_000), today, cuenta.id)
        assertEquals(pesos(1_050_000), store.balance(cuenta.id))
        // Era al revés: Carlos me debe. La deuda y su abono mueven la plata al otro lado.
        d = store.saveDebt(store.ledger.value.debts.single(), "Carlos", DebtDirection.ME_DEBE, pesos(80_000), today, null, null, cuenta.id)
        assertEquals(pesos(1_000_000 - 80_000 + 30_000), store.balance(cuenta.id))
        // Sin cuenta: se quita la transferencia de la deuda.
        store.saveDebt(d, "Carlos", DebtDirection.ME_DEBE, pesos(80_000), today, null, null, null)
        assertNull(store.ledger.value.debts.single().transferId)
        assertEquals(pesos(1_030_000), store.balance(cuenta.id))
        store.settleDebt(d.id, today, null)
        assertEquals(0L, DebtMath.remaining(store.ledger.value.debts.single(), store.ledger.value.debtPayments))
    }

    @Test fun borrarConDeshacerYGuardarEnElArchivo() {
        val store = newStore()
        val cuenta = store.account()
        val d = store.saveDebt(null, "Ana", DebtDirection.ME_DEBE, pesos(50_000), today, null, null, cuenta.id)
        store.addDebtPayment(d.id, pesos(20_000), today, cuenta.id)
        val removed = store.deleteDebt(d.id)!!
        assertTrue(store.ledger.value.debts.isEmpty() && store.ledger.value.debtPayments.isEmpty() && store.ledger.value.transfers.isEmpty())
        assertEquals(pesos(1_000_000), store.balance(cuenta.id))
        store.restoreDebt(removed)
        assertEquals(pesos(970_000), store.balance(cuenta.id))
        // Se lee igual al abrir la app otra vez.
        val again = Store(file, store.prefs)
        assertEquals(store.ledger.value.debts, again.ledger.value.debts)
        assertEquals(store.ledger.value.debtPayments, again.ledger.value.debtPayments)
    }

    @Test fun respaldoConDeudasYAbonos() {
        val store = newStore()
        val cuenta = store.account()
        val d = store.saveDebt(null, "Ana", DebtDirection.ME_DEBE, pesos(50_000), today, today.plusDays(3), "Taxi", cuenta.id)
        store.addDebtPayment(d.id, pesos(20_000), today, cuenta.id)
        val json = BackupCodec.encode(store.ledger.value, Currency.COP)
        val row = json.getJSONArray("debts").getJSONObject(0)
        assertEquals("me_debe", row.getString("directionRaw")); assertEquals("Ana", row.getString("person"))
        val (back, _) = BackupCodec.decode(json.toString())
        assertEquals(store.ledger.value.debts, back.debts)
        assertEquals(store.ledger.value.debtPayments, back.debtPayments)
    }

    @Test fun laNubeLlevaDeudasYAbonosAlOtroTelefono() = runBlocking {
        val crypto = AndroidCrypto()
        val space = "5a0f3c1e-8d2b-4c6a-9e7f-112233445566"
        val owner = "0e000000-0000-4000-8000-000000000001"
        val key = crypto.randomBytes(32)
        val server = MemoryServer()
        suspend fun sync(s: Store) = SyncEngine(LedgerSyncStore(s, space, owner), EncryptedRemote(server, crypto, space) { if (it == space) key else null }).run()

        val a = newStore()
        val cuenta = a.account()
        val d = a.saveDebt(null, "Ana", DebtDirection.ME_DEBE, pesos(50_000), today, today.plusDays(3), "Taxi", cuenta.id)
        a.addDebtPayment(d.id, pesos(20_000), today, cuenta.id)
        sync(a)
        val required = mapOf("debts" to "id spaceId person directionRaw amountMinor occurredAt createdAt updatedAt",
            "debt_payments" to "id spaceId debtId amountMinor occurredAt createdAt updatedAt").mapValues { it.value.split(" ") }
        for (row in server.rows.values.filter { it.entity in required }) {
            val o = JSONObject(String(Envelope.open(row.payload, row.spaceId, row.entity, row.id, key, crypto)))
            for (k in required.getValue(row.entity)) assertTrue("${row.entity} sin $k", o.has(k) && !o.isNull(k))
        }
        assertEquals(setOf("debts", "debt_payments"), server.rows.values.map { it.entity }.filter { it.startsWith("debt") }.toSet())

        val b = newStore()
        sync(b)
        assertEquals(a.ledger.value.debts, b.ledger.value.debts)
        assertEquals(a.ledger.value.debtPayments, b.ledger.value.debtPayments)
        assertEquals(a.balance(cuenta.id), b.balance(cuenta.id))
        // Un abono en el segundo teléfono vuelve al primero.
        b.addDebtPayment(d.id, pesos(30_000), today, null)
        sync(b); sync(a)
        assertEquals(0L, DebtMath.remaining(a.ledger.value.debts.single(), a.ledger.value.debtPayments))
    }
}
