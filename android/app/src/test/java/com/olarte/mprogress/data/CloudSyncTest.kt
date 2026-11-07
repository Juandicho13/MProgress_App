package com.olarte.mprogress.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.olarte.mprogress.data.cloud.AndroidCrypto
import com.olarte.mprogress.data.cloud.AuthClient
import com.olarte.mprogress.data.cloud.CloudAccount
import com.olarte.mprogress.data.cloud.SupabaseHttp
import com.olarte.mprogress.domain.*
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/** Servidor en memoria con las mismas reglas que `sync_records`: un changed_at más viejo no pisa la fila y updated_at lo pone el servidor. */
class MemoryServer : EnvelopeTransport {
    val rows = linkedMapOf<String, SyncEnvelope>()
    private var clock = Instant.parse("2026-11-08T10:00:00Z")

    override suspend fun upsert(rows: List<SyncEnvelope>) {
        for (r in rows) {
            val old = this.rows[r.id]
            if (old != null && r.changedAt < old.changedAt) continue
            clock = clock.plusMillis(1)
            this.rows[r.id] = r.copy(updatedAt = clock, spaceId = old?.spaceId ?: r.spaceId)
        }
    }

    override suspend fun fetch(entity: String, since: Instant?) =
        rows.values.filter { it.entity == entity && (since == null || it.updatedAt!! > since) }.sortedBy { it.updatedAt }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CloudSyncTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val crypto = AndroidCrypto()
    private val space = "5a0f3c1e-8d2b-4c6a-9e7f-112233445566"
    private val owner = "0e000000-0000-4000-8000-000000000001"
    private val key = crypto.randomBytes(32)
    private val server = MemoryServer()

    private fun newStore(name: String): Store {
        val dir = File(context.filesDir, "prueba-$name-${UUID.randomUUID()}").apply { mkdirs() }
        return Store(File(dir, "mprogress.json"), context.getSharedPreferences("prueba-$name-${UUID.randomUUID()}", Context.MODE_PRIVATE))
    }

    private fun run(store: Store): Pair<SyncEngine.Report, LedgerSyncStore> = runBlocking {
        val local = LedgerSyncStore(store, space, owner)
        val report = SyncEngine(local, EncryptedRemote(server, crypto, space) { if (it == space) key else null }).run()
        report to local
    }

    private fun open(row: SyncEnvelope) = JSONObject(String(Envelope.open(row.payload, row.spaceId, row.entity, row.id, key, crypto)))

    private fun seed(store: Store) {
        val bank = store.addInstitution("Bancolombia", 0xF5C451)
        val card = store.addProduct(bank, ProductKind.CREDITO, "Crédito Oro", "4417", 0, 10)
        store.add(EntryKind.GASTO, "Mercado", 120_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 3), card, categoryId = Categories.byName("Mercado")!!.id, notes = "Semana")
        store.add(EntryKind.GASTO, "Gimnasio", 119_900_00, Cycle.Mensual, LocalDate.of(2026, 11, 20), card, today = LocalDate.of(2026, 11, 6))
        val gym = store.ledger.value.recurring.first()
        store.updateRecurring(gym.copy(alert = AlertRule(AlertMode.PERSONALIZADO, 2, 600)))
        store.saveBudget(BudgetRecord(categoryId = null, limitMinor = 2_000_000_00))
        store.saveGoal(GoalRecord(name = "Viaje", targetMinor = 5_000_000_00))
        store.addContribution(ContributionRecord(goalId = store.ledger.value.goals.first().id, amountMinor = 100_000_00, occurredAt = LocalDate.of(2026, 11, 1)))
        store.saveReward(RewardRecord(name = "LifeMiles", kind = RewardKind.MILLAS, balance = 1200))
        store.addTransfer(TransferRecord(fromProductId = card, toProductId = card, amountMinor = 1, occurredAt = LocalDate.of(2026, 11, 2)))
    }

    /** Las claves que iOS exige en cada fila (las que no son opcionales en BackupSnapshot, Domain/Backup.swift). */
    private val required = mapOf(
        "spaces" to "id ownerId name kindRaw currencyCode colorHex shareTotalsOnly defaultSplit createdAt updatedAt",
        "institutions" to "id spaceId name hidden sort createdAt updatedAt",
        "products" to "id spaceId institutionId kindRaw name balanceMinor balanceAt inWallet hidden createdAt updatedAt",
        "recurring" to "id spaceId kindRaw name amountMinor cycleRaw nextDate anchorDay anchorMonth active createdAt updatedAt",
        "entries" to "id spaceId kindRaw amountMinor occurredAt name sourceRaw needsReview createdAt updatedAt",
        "transfers" to "id spaceId fromProductId toProductId amountMinor occurredAt createdAt updatedAt",
        "reminders" to "id spaceId recurringId daysBefore targetRaw atMinutes notifyPartnerOnPaid sameDay createdAt updatedAt",
        "budgets" to "id spaceId monthlyLimitMinor createdAt updatedAt",
        "savings_goals" to "id spaceId name targetAmountMinor createdAt updatedAt",
        "goal_contributions" to "id spaceId goalId amountMinor occurredAt createdAt updatedAt",
        "reward_programs" to "id spaceId name kindRaw balance balanceAt createdAt updatedAt",
    ).mapValues { it.value.split(" ") }

    @Test fun pushedRowsHaveEveryKeyIOSNeeds() {
        val a = newStore("a"); seed(a)
        val (report, _) = run(a)
        assertEquals(10, report.pushed) // 1 banco, 1 tarjeta, 1 gasto, 1 fijo, 1 aviso, 1 límite, 1 meta, 1 aporte, 1 programa, 1 transferencia
        val tables = server.rows.values.map { it.entity }.toSet()
        assertEquals(setOf("institutions", "products", "entries", "recurring", "reminders", "budgets", "savings_goals", "goal_contributions", "reward_programs", "transfers"), tables)
        for (row in server.rows.values) {
            val o = open(row)
            for (k in required.getValue(row.entity)) assertTrue("${row.entity} sin $k", o.has(k) && !o.isNull(k))
            assertEquals(space, o.getString("spaceId"))
            assertTrue(o.has("deletedAt") && o.isNull("deletedAt"))
            // Fechas con 6 decimales y Z, como ServerTime de iOS.
            assertTrue(Regex("^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}Z$").matches(o.getString("updatedAt")))
            assertEquals(ServerTime.parse(o.getString("updatedAt")), row.changedAt)
            assertEquals(row.id, row.id.lowercase())
        }
        val entry = open(server.rows.values.first { it.entity == "entries" })
        assertEquals("manual", entry.getString("sourceRaw"))
        assertEquals("2026-11-03T12:00:00.000000Z", entry.getString("occurredAt"))
        assertEquals("4417", open(server.rows.values.first { it.entity == "products" }).getString("last4"))
        val reminder = open(server.rows.values.first { it.entity == "reminders" })
        assertEquals("personalizado", reminder.getString("modeRaw")); assertEquals(2, reminder.getInt("daysBefore"))
    }

    @Test fun secondDeviceGetsEverythingAndChangesGoBothWays() {
        val a = newStore("a"); seed(a)
        run(a)
        val b = newStore("b")
        val (pullB, _) = run(b)
        assertEquals(10, pullB.pulled)
        val la = a.ledger.value; val lb = b.ledger.value
        assertEquals(la.institutions, lb.institutions)
        assertEquals(la.products, lb.products)
        assertEquals(la.recurring.map { it.copy(finished = false) }, lb.recurring.map { it.copy(finished = false) })
        assertEquals(la.entries.map { it.copy(pointsEarned = 0) }, lb.entries)
        assertEquals(la.budgets, lb.budgets); assertEquals(la.goals, lb.goals); assertEquals(la.contributions, lb.contributions)
        assertEquals(la.rewards, lb.rewards); assertEquals(la.transfers, lb.transfers)

        // Sincronizar otra vez no sube ni escribe nada.
        val (again, localB) = run(b)
        assertEquals(0, again.pushed); assertEquals(0, localB.appliedChanges)

        // B cambia un gasto y A lo recibe.
        val e = lb.entries.first()
        b.updateEntry(e.copy(amountMinor = 99_000_00))
        assertEquals(1, run(b).first.pushed)
        run(a)
        assertEquals(99_000_00, a.ledger.value.entries.first { it.id == e.id }.amountMinor)

        // A borra el gasto y B lo deja de ver.
        a.deleteEntry(e.id)
        assertEquals(1, run(a).first.pushed)
        assertNotNull(server.rows[e.id]!!.deletedAt)
        run(b)
        assertTrue(b.ledger.value.entries.none { it.id == e.id })

        // B pasa el aviso a "Como el general": la fila del aviso se borra y A vuelve al general.
        val gym = b.ledger.value.recurring.first()
        b.updateRecurring(gym.copy(alert = AlertRule()))
        run(b); run(a)
        assertEquals(AlertMode.GENERAL, a.ledger.value.recurring.first().alert.mode)
    }

    @Test fun keepsWhatOnlyIOSKnowsAndReadsIOSRows() {
        val b = newStore("b")
        val id = "E1000000-0000-4000-8000-0000000000AA"
        // Fila como la escribe iOS: UUID en mayúscula, comercio, método de pago y hora exacta.
        val ios = JSONObject().put("id", id).put("spaceId", space.uppercase()).put("kindRaw", "gasto").put("amountMinor", 8_430_000).put("occurredAt", "2026-11-05T18:22:10.123456Z")
            .put("name", "Éxito").put("merchant", "ÉXITO CALLE 80").put("icon", "cart").put("categoryId", "0A000000-0000-4000-8000-000000000006").put("productId", JSONObject.NULL)
            .put("recurringId", JSONObject.NULL).put("paidBy", JSONObject.NULL).put("methodRaw", "wallet").put("sourceRaw", "applePay").put("needsReview", false)
            .put("notes", JSONObject.NULL).put("createdBy", JSONObject.NULL).put("createdAt", "2026-11-05T18:22:10.123456Z").put("updatedAt", "2026-11-05T18:22:10.123456Z").put("deletedAt", JSONObject.NULL)
        runBlocking {
            server.upsert(listOf(SyncEnvelope(id.lowercase(), space, "entries", Envelope.seal(ios.toString().toByteArray(), space, "entries", id, key, crypto),
                ServerTime.parse("2026-11-05T18:22:10.123456Z")!!)))
        }
        run(b)
        val e = b.ledger.value.entries.single()
        assertEquals(id.lowercase(), e.id)
        assertEquals("Mercado", Categories.byId(e.categoryId)?.name)
        assertEquals(LocalDate.of(2026, 11, 5), e.occurredAt)

        b.updateEntry(e.copy(amountMinor = 90_000_00))
        run(b)
        val pushed = open(server.rows[id.lowercase()]!!)
        assertEquals(9_000_000, pushed.getLong("amountMinor"))
        assertEquals("ÉXITO CALLE 80", pushed.getString("merchant"))
        assertEquals("wallet", pushed.getString("methodRaw"))
        assertEquals("applePay", pushed.getString("sourceRaw"))
        assertEquals("cart", pushed.getString("icon"))
        assertEquals("2026-11-05T18:22:10.123456Z", pushed.getString("occurredAt"))
        assertEquals("2026-11-05T18:22:10.123456Z", pushed.getString("createdAt"))
    }

    @Test fun newestChangeWins() {
        val a = newStore("a"); seed(a); run(a)
        val b = newStore("b"); run(b)
        val id = a.ledger.value.entries.first().id
        // B cambia primero, A después: gana A aunque B suba de último.
        b.updateEntry(b.ledger.value.entries.first().copy(name = "De B"))
        Thread.sleep(5)
        a.updateEntry(a.ledger.value.entries.first().copy(name = "De A"))
        run(a); run(b)
        assertEquals("De A", b.ledger.value.entries.first { it.id == id }.name)
        assertEquals("De A", open(server.rows[id]!!).getString("name"))
        run(a)
        assertEquals("De A", a.ledger.value.entries.first { it.id == id }.name)
    }

    @Test fun offlineChangesWaitAndThenGoUp() {
        val a = newStore("a"); seed(a)
        val offline = object : EnvelopeTransport {
            override suspend fun upsert(rows: List<SyncEnvelope>) = throw com.olarte.mprogress.data.cloud.CloudError.Offline()
            override suspend fun fetch(entity: String, since: Instant?) = throw com.olarte.mprogress.data.cloud.CloudError.Offline()
        }
        val local = LedgerSyncStore(a, space, owner)
        val failed = runCatching { runBlocking { SyncEngine(local, EncryptedRemote(offline, crypto, space) { key }).run() } }
        assertTrue(failed.exceptionOrNull() is com.olarte.mprogress.data.cloud.CloudError.Offline)
        assertEquals(10, local.pendingCount())
        assertEquals(10, run(a).first.pushed)
        assertEquals(0, LedgerSyncStore(a, space, owner).pendingCount())
    }

    @Test fun currencyComesFromTheCloudFirst() {
        val a = newStore("a")
        val ios = JSONObject().put("id", space.uppercase()).put("ownerId", owner).put("name", "Personal").put("kindRaw", "personal").put("currencyCode", "EUR")
            .put("colorHex", "F55F1F").put("icon", JSONObject.NULL).put("shareTotalsOnly", false).put("defaultSplit", 50).put("endsOn", JSONObject.NULL)
            .put("createdAt", "2026-11-05T18:00:00Z").put("updatedAt", "2026-11-05T18:00:00Z").put("deletedAt", JSONObject.NULL)
        runBlocking { server.upsert(listOf(SyncEnvelope(space, space, "spaces", Envelope.seal(ios.toString().toByteArray(), space, "spaces", space, key, crypto), Instant.parse("2026-11-05T18:00:00Z")))) }
        run(a)
        assertEquals("EUR", a.currency.value.code)
        a.setCurrency(Currency.from("COP"))
        run(a)
        assertEquals("COP", open(server.rows[space]!!).getString("currencyCode"))
        assertEquals("personal", open(server.rows[space]!!).getString("kindRaw"))
    }

    @Test fun merchantNamesAndMonthIntervalsTravelLikeIOS() {
        val a = newStore("a")
        val e = a.add(EntryKind.GASTO, "Pepepollo Sas 123", 32_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 2), null, source = "notificacion",
            merchant = "Pepepollo Sas 123")!!
        a.updateEntry(a.ledger.value.entries.first { it.id == e.id }.copy(name = "El Corral", categoryId = Categories.byName("Salidas")!!.id))
        a.add(EntryKind.GASTO, "Seguro", 300_000_00, Cycle.CadaMeses(3), LocalDate.of(2026, 12, 10), null, today = LocalDate.of(2026, 11, 6))
        run(a)
        val alias = open(server.rows.values.single { it.entity == "merchant_alias" })
        for (k in "id spaceId key name categoryId createdAt updatedAt".split(" ")) assertTrue("merchant_alias sin $k", alias.has(k) && !alias.isNull(k))
        assertEquals("PEPEPOLLO", alias.getString("key"))
        assertEquals(3, open(server.rows.values.single { it.entity == "recurring" }).getInt("intervalMonths"))
        assertEquals("Pepepollo Sas 123", open(server.rows.values.single { it.entity == "entries" }).getString("merchant"))

        val b = newStore("b"); run(b)
        assertEquals(a.ledger.value.merchantAliases, b.ledger.value.merchantAliases)
        assertEquals(Cycle.CadaMeses(3), b.ledger.value.recurring.single().cycle)
        assertEquals("El Corral", b.merchantAlias("PEPEPOLLO SAS 456")?.name)

        // B borra la regla y A la deja de usar.
        b.deleteMerchantAlias(b.ledger.value.merchantAliases.single().id)
        run(b); run(a)
        assertTrue(a.ledger.value.merchantAliases.isEmpty())
    }

    @Test fun authSessionAndCallbackParsing() {
        val s = AuthClient.session("""{"access_token":"a","refresh_token":"r","expires_at":1893456000,"user":{"id":"ABCDEF00-0000-4000-8000-000000000001","email":"juan@correo.com"}}""", null)
        assertEquals("abcdef00-0000-4000-8000-000000000001", s.userId)
        assertEquals(Instant.ofEpochSecond(1893456000), s.expiresAt)
        assertEquals(s, com.olarte.mprogress.data.cloud.CloudSession.fromJson(s.toJson()))
        assertEquals(mapOf("code" to "abc-123"), CloudAccount.callbackParams("mprogress://auth-callback?code=abc-123"))
        assertEquals("Email link is invalid or has expired", CloudAccount.callbackParams("mprogress://auth-callback#error=access_denied&error_description=Email+link+is+invalid+or+has+expired")!!["error_description"])
        assertNull(CloudAccount.callbackParams("mprogress://rapido"))
        assertEquals("https://x.supabase.co/rest/v1/sync_records?updated_at=gt.2026-11-08T10%3A00%3A00.000000Z&order=updated_at.asc",
            SupabaseHttp.url("https://x.supabase.co/rest/v1", "sync_records", listOf("updated_at" to "gt.2026-11-08T10:00:00.000000Z", "order" to "updated_at.asc")))
        assertFalse(s.needsRefresh(Instant.ofEpochSecond(1893456000 - 3600)))
        assertTrue(s.needsRefresh(Instant.ofEpochSecond(1893456000 - 30)))
    }

    private fun learnPepepollo(store: Store, name: String) {
        val e = store.add(EntryKind.GASTO, "Pepepollo Sas 123", 32_000_00, Cycle.Puntual, LocalDate.of(2026, 11, 2), null, source = "notificacion",
            merchant = "Pepepollo Sas 123")!!
        store.updateEntry(store.ledger.value.entries.first { it.id == e.id }.copy(name = name))
    }

    private fun firstUpload(store: Store): Pair<SyncEngine.Report, LedgerSyncStore> = runBlocking {
        val local = LedgerSyncStore(store, space, owner)
        val report = SyncEngine(local, EncryptedRemote(server, crypto, space) { if (it == space) key else null }, InitialUpload.BATCH_SIZE).initialUpload()
        report to local
    }

    @Test fun firstUploadOnTheSecondPhoneJoinsTheRepeatedMerchantRule() {
        val a = newStore("a"); seed(a); learnPepepollo(a, "El Corral")
        val (first, _) = firstUpload(a)
        assertEquals(12, first.pushed) // lo de seed, el movimiento del comercio y su regla

        val b = newStore("b"); learnPepepollo(b, "Corral")
        val (report, local) = firstUpload(b)
        // B solo sube su movimiento: su regla repetida se une con la de la nube y no se sube.
        assertEquals(1, report.pushed)
        assertEquals(1, server.rows.values.count { it.entity == "merchant_alias" })
        assertEquals(listOf("El Corral"), b.ledger.value.merchantAliases.map { it.name })
        assertEquals(a.ledger.value.merchantAliases.single().id, b.ledger.value.merchantAliases.single().id)
        assertEquals(0, local.pendingCount())
        assertTrue(local.pendingCounts().isEmpty())
        assertTrue(local.pendingEntryIds().isEmpty())
        // Otra vez no sube nada.
        assertEquals(0, run(b).first.pushed)
        assertEquals(0, firstUpload(a).first.pushed)
    }

    @Test fun pendingCountsAndMarksComeFromTheJournal() {
        val a = newStore("a"); seed(a)
        val local = LedgerSyncStore(a, space, owner)
        assertEquals(1, local.pendingCounts()["entries"])
        assertEquals(1, local.pendingCounts()["recurring"])
        assertEquals(a.ledger.value.entries.map { it.id }.toSet(), local.pendingEntryIds())
        run(a)
        assertTrue(LedgerSyncStore(a, space, owner).pendingEntryIds().isEmpty())
        val e = a.ledger.value.entries.first()
        a.updateEntry(e.copy(name = "Cambiado"))
        assertEquals(setOf(e.id), LedgerSyncStore(a, space, owner).pendingEntryIds())
        assertEquals(mapOf("entries" to 1), LedgerSyncStore(a, space, owner).pendingCounts())
    }
}
