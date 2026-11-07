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

/** Categorías propias en Android: se guardan, van en el respaldo y viajan a la nube como las de iOS (tabla `categories`). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CustomCategoryTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val crypto = AndroidCrypto()
    private val space = "5a0f3c1e-8d2b-4c6a-9e7f-112233445566"
    private val owner = "0e000000-0000-4000-8000-000000000001"
    private val key = crypto.randomBytes(32)
    private val server = MemoryServer()

    private fun newStore(name: String, dir: File = File(context.filesDir, "cat-$name-${UUID.randomUUID()}").apply { mkdirs() }): Store =
        Store(File(dir, "mprogress.json"), context.getSharedPreferences("cat-$name-${UUID.randomUUID()}", Context.MODE_PRIVATE))

    private fun run(store: Store) = runBlocking {
        SyncEngine(LedgerSyncStore(store, space, owner), EncryptedRemote(server, crypto, space) { if (it == space) key else null }).run()
    }

    private fun firstUpload(store: Store) = runBlocking {
        SyncEngine(LedgerSyncStore(store, space, owner), EncryptedRemote(server, crypto, space) { if (it == space) key else null }, InitialUpload.BATCH_SIZE).initialUpload()
    }

    private fun open(row: SyncEnvelope) = JSONObject(String(Envelope.open(row.payload, row.spaceId, row.entity, row.id, key, crypto)))

    @Test fun seGuardaYVaEnElRespaldo() {
        val dir = File(context.filesDir, "cat-persist-${UUID.randomUUID()}").apply { mkdirs() }
        val a = newStore("a", dir)
        val pets = a.addCategory("  Mascotas  ", "pawprint")
        assertEquals("Mascotas", pets.name)
        assertEquals(15, pets.sort) // después de las de la app y antes de Otros
        assertEquals(pets, Categories.byId(pets.id))
        assertTrue(Categories.available().indexOf(pets) < Categories.available().indexOfFirst { it.name == "Otros" })
        a.add(EntryKind.GASTO, "Concentrado", 80_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 5), null, categoryId = pets.id)

        // Al abrir de nuevo sigue ahí.
        val reopened = Store(File(dir, "mprogress.json"), context.getSharedPreferences("cat-otra-${UUID.randomUUID()}", Context.MODE_PRIVATE))
        assertEquals(listOf(pets), reopened.ledger.value.categories)

        // Respaldo .mprogress: va con su espacio (como iOS) y vuelve igual; las de la app no se duplican.
        val text = BackupCodec.encode(a.ledger.value, Currency.COP).toString()
        val rows = JSONObject(text).getJSONArray("categories")
        val own = (0 until rows.length()).map { rows.getJSONObject(it) }.single { !it.isNull("ownerSpaceId") }
        assertEquals("Mascotas", own.getString("name")); assertEquals("pawprint", own.getString("icon"))
        val (back, _) = BackupCodec.decode(text)
        assertEquals(listOf(pets), back.categories)

        // Una de iOS con id en mayúsculas queda en minúscula al restaurar.
        val b = newStore("b")
        b.replaceAll(back.copy(categories = listOf(pets.copy(id = pets.id.uppercase()))))
        assertEquals(pets.id, b.ledger.value.categories.single().id)

        // Cambiar y borrar; las de la app no se tocan.
        a.updateCategory(pets.id, "Mascotas de la casa", "heart")
        assertEquals("Mascotas de la casa", a.ledger.value.categories.single().name)
        a.deleteCategory(Categories.byName("Mercado")!!.id)
        assertNotNull(Categories.byName("Mercado"))
        a.deleteCategory(pets.id)
        assertTrue(a.ledger.value.categories.isEmpty())
        assertNull(Categories.byId(pets.id))
        a.restoreCategory(pets)
        assertEquals(1, a.ledger.value.categories.size)
    }

    @Test fun filaDeLaNubeIdaYVuelta() {
        val c = CategoryRecord(UUID.randomUUID().toString(), "Viajes", "airplane", 16)
        val row = SyncRows.customCategory(c, SyncRows.Ctx(space, owner))
        assertEquals(space, row.getString("ownerSpaceId"))
        assertEquals(c, SyncRows.categoryFrom(row))
        assertEquals("categories", SyncRows.TABLES[1])
    }

    @Test fun viajaEntreTelefonosYSeBorra() {
        val a = newStore("a")
        val pets = a.addCategory("Mascotas", "pawprint")
        a.add(EntryKind.GASTO, "Concentrado", 80_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 5), null, categoryId = pets.id)
        run(a)
        val row = open(server.rows.values.single { it.entity == "categories" })
        for (k in "id ownerSpaceId name icon sort createdAt updatedAt".split(" ")) assertTrue("categories sin $k", row.has(k) && !row.isNull(k))
        assertEquals(space, row.getString("ownerSpaceId"))

        val b = newStore("b"); run(b)
        assertEquals(listOf(pets), b.ledger.value.categories)
        assertEquals(pets.id, b.ledger.value.entries.single().categoryId)

        b.updateCategory(pets.id, "Mascotas", "heart")
        run(b); run(a)
        assertEquals("heart", a.ledger.value.categories.single().icon)

        a.deleteCategory(pets.id)
        run(a); run(b)
        assertTrue(b.ledger.value.categories.isEmpty())
    }

    @Test fun primeraSubidaUneLaMismaCategoriaPorNombre() {
        val a = newStore("a")
        val pets = a.addCategory("Mascotas", "pawprint")
        firstUpload(a)

        val b = newStore("b")
        val twin = b.addCategory("MASCOTÁS", "heart")
        b.add(EntryKind.GASTO, "Veterinaria", 50_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 6), null, categoryId = twin.id)
        val report = firstUpload(b)
        // Solo sube el movimiento: la categoría repetida se une con la de la nube y no se sube.
        assertEquals(1, report.pushed)
        assertEquals(1, server.rows.values.count { it.entity == "categories" })
        assertEquals(listOf(pets.id), b.ledger.value.categories.map { it.id })
        assertEquals(pets.id, b.ledger.value.entries.single().categoryId)
        assertEquals(pets.id, open(server.rows.values.single { it.entity == "entries" }).getString("categoryId"))
    }
}
