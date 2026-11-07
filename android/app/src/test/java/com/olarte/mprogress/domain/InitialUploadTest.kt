package com.olarte.mprogress.domain

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.util.UUID

/** Pruebas de la primera subida (F10-05), las mismas de ios/MProgressTests/Domain/InitialUploadTests.swift. */
class InitialUploadTest {
    private fun at(day: Int) = Instant.parse("2026-11-%02dT14:00:00Z".format(day))
    private fun id() = UUID.randomUUID().toString()
    private fun item(table: String, id: String, day: Int, deleted: Boolean = false, key: String? = null) = InitialUpload.Item(table, id, at(day), deleted, key)
    private fun ref(table: String, id: String) = InitialUpload.Ref(table, id)

    /** Servidor en memoria: upsert por id. */
    class Server : RemoteSyncStore {
        val rows = linkedMapOf<String, SyncRecord>()
        var failNext = 0
        var pushes = 0
        class Offline : Exception("sin conexión")

        override suspend fun push(records: List<SyncRecord>) {
            if (failNext > 0) { failNext--; throw Offline() }
            pushes++
            records.forEach { rows[it.table + "/" + it.id] = it }
        }

        override suspend fun pull(table: String, since: Instant?) =
            rows.values.filter { it.table == table && (since == null || it.updatedAt > since) }.sortedBy { it.updatedAt }
    }

    /** Base local en memoria: cada fila es un mapa de campos de texto (el JSON del respaldo, simplificado). */
    class Local : InitialUploadLocal {
        class Row(val table: String, val id: String, var updatedAt: Instant, val fields: MutableMap<String, String>, var deletedAt: Instant? = null)
        val rows = linkedMapOf<String, Row>()
        val pendingIds = mutableListOf<String>()
        val failures = mutableMapOf<String, Int>()
        val cursors = mutableMapOf<String, Instant>()
        var resolved: Map<String, Map<String, String>> = emptyMap()

        fun add(table: String, id: String = UUID.randomUUID().toString(), at: Instant, fields: Map<String, String> = emptyMap(), pending: Boolean = true): String {
            rows["$table/$id"] = Row(table, id, at, fields.toMutableMap())
            if (pending) pendingIds += "$table/$id"
            return id
        }

        private fun encode(fields: Map<String, String>) = fields.entries.sortedBy { it.key }.joinToString("\n") { "${it.key}=${it.value}" }.toByteArray()
        private fun decode(bytes: ByteArray) = String(bytes).split("\n").filter { it.contains('=') }.associate { it.substringBefore('=') to it.substringAfter('=') }
        private fun record(r: Row) = SyncRecord(r.table, r.id, r.updatedAt, r.deletedAt, encode(r.fields))

        override fun pending() = pendingIds.mapNotNull { rows[it] }.map(::record)
        override fun markSynced(records: List<SyncRecord>) { records.forEach { pendingIds.remove(it.table + "/" + it.id) } }
        override fun markFailed(records: List<SyncRecord>, attempts: Int) { records.forEach { failures[it.id] = attempts } }
        override fun attempts(record: SyncRecord) = failures[record.id] ?: 0
        override fun local(table: String, id: String) = rows["$table/$id"]?.let(::record)
        override fun apply(record: SyncRecord) {
            rows[record.table + "/" + record.id] = Row(record.table, record.id, record.updatedAt, decode(record.payload).toMutableMap(), record.deletedAt)
            pendingIds.remove(record.table + "/" + record.id)
        }
        override fun cursor(table: String) = cursors[table]
        override fun setCursor(date: Instant, table: String) { cursors[table] = date }

        override fun uploadItems() = SyncEngine.TABLES.flatMap { t ->
            rows.values.filter { it.table == t }.map { InitialUpload.Item(t, it.id, it.updatedAt, it.deletedAt != null, InitialUpload.seedKey(t) { k -> it.fields[k] }) }
        }
        override fun seedKey(record: SyncRecord): String? { val f = decode(record.payload); return InitialUpload.seedKey(record.table) { f[it] } }
        override fun resolveDuplicates(remap: Map<String, Map<String, String>>) {
            resolved = remap
            val categories = remap["categories"].orEmpty()
            for (r in rows.values) {
                val to = r.fields["categoryId"]?.let { categories[it] } ?: continue
                r.fields["categoryId"] = to
                if (r.table + "/" + r.id !in pendingIds) pendingIds += r.table + "/" + r.id
            }
            for ((table, map) in remap) for (dup in map.keys) { rows.remove("$table/$dup"); pendingIds.remove("$table/$dup") }
        }
        override fun queue(refs: List<InitialUpload.Ref>) {
            for (r in refs) { val k = r.table + "/" + r.id; if (k !in pendingIds && rows.containsKey(k)) pendingIds += k }
        }
    }

    @Test fun planUploadsMissingOrNewerAndTakesTheRest() {
        val mine = id(); val olderHere = id(); val newerHere = id(); val same = id(); val cloudOnly = id()
        val plan = InitialUpload.plan(
            listOf(item("entries", mine, 1), item("entries", olderHere, 1), item("entries", newerHere, 5), item("entries", same, 3)),
            listOf(item("entries", olderHere, 4), item("entries", newerHere, 2), item("entries", same, 3), item("entries", cloudOnly, 2)))
        assertEquals(listOf(ref("entries", mine), ref("entries", newerHere)), plan.push)
        assertEquals(listOf(ref("entries", olderHere), ref("entries", cloudOnly)), plan.take)
        assertEquals(1, plan.unchanged)
        assertTrue(plan.remap.isEmpty())
    }

    @Test fun planJoinsTheSameCategoryCreatedOnTwoPhones() {
        val here = id(); val cloud = id(); val other = id()
        val plan = InitialUpload.plan(
            listOf(item("categories", here, 5, key = InitialUpload.categoryKey("Mascotas ")), item("categories", other, 5, key = InitialUpload.categoryKey("Viajes"))),
            listOf(item("categories", cloud, 1, key = InitialUpload.categoryKey("MASCOTÁS"))))
        assertEquals(mapOf("categories" to mapOf(here to cloud)), plan.remap)
        assertEquals(listOf(ref("categories", other)), plan.push)
        assertEquals(listOf(ref("categories", cloud)), plan.take)
    }

    @Test fun planIgnoresDeletedTwinsAndTakesTheCloudSpace() {
        val here = id(); val deleted = id(); val space = id()
        val plan = InitialUpload.plan(
            listOf(item("categories", here, 5, key = "mascotas"), item("spaces", space, 6)),
            listOf(item("categories", deleted, 1, deleted = true, key = "mascotas"), item("spaces", space, 1)))
        assertTrue(plan.remap.isEmpty())
        assertEquals(listOf(ref("categories", here)), plan.push)
        assertTrue(ref("spaces", space) in plan.take)
    }

    @Test fun planPicksTheOldestOfTwoCloudTwins() {
        val here = id(); val old = id(); val newer = id()
        val plan = InitialUpload.plan(listOf(item("merchant_alias", here, 5, key = "pepepollo")),
            listOf(item("merchant_alias", newer, 3, key = "pepepollo"), item("merchant_alias", old, 2, key = "pepepollo")))
        assertEquals(mapOf("merchant_alias" to mapOf(here to old)), plan.remap)
    }

    @Test fun stableKeysAndRemapping() {
        assertEquals("mascotas y mas", InitialUpload.normalizedName("  Mascotás  y   Más! "))
        assertEquals("nino", InitialUpload.normalizedName("Niño"))
        assertEquals("gasto|comida", InitialUpload.categoryKey("Comida", "gasto"))
        assertNull(InitialUpload.categoryKey("  "))
        assertEquals("cafe", InitialUpload.seedKey("categories") { mapOf("name" to "Café ", "icon" to "cup")[it] })
        assertEquals("pepepollo", InitialUpload.seedKey("merchant_alias") { mapOf("key" to "PEPEPOLLO")[it] })
        assertNull(InitialUpload.seedKey("entries") { "x" })
        assertNull(InitialUpload.remapped(null, emptyMap()))
        val a = id(); val b = id()
        assertEquals(b, InitialUpload.remapped(a, mapOf(a to b)))
        assertEquals(b, InitialUpload.remapped(b, mapOf(a to b)))
    }

    @Test fun textsAndMarker() {
        assertEquals("Subiendo tus datos: 120 de 340", InitialUpload.progressText(120, 340))
        assertEquals("Subiendo tus datos: 340 de 340", InitialUpload.progressText(400, 340))
        assertEquals("Preparando tus datos…", InitialUpload.progressText(0, 0))
        assertEquals("Tus datos ya están en la nube, cifrados", InitialUpload.DONE_TEXT)
        assertEquals("nube.subidaInicial.5a0f3c1e-8d2b-4c6a-9e7f-112233445566.0e000000-0000-4000-8000-000000000001",
            InitialUpload.storageKey("5A0F3C1E-8D2B-4C6A-9E7F-112233445566", "0E000000-0000-4000-8000-000000000001"))
    }

    @Test fun firstDeviceUploadsEverythingOnceInBatchesWithProgress() = runBlocking {
        val server = Server()
        val juan = Local()
        for (day in 1..7) juan.add("entries", at = at(day), fields = mapOf("name" to "Gasto $day"))
        juan.add("categories", at = at(1), fields = mapOf("name" to "Mascotas"))
        val seen = mutableListOf<String>()
        val report = SyncEngine(juan, server, 3).initialUpload { done, total -> seen += "$done/$total" }
        assertEquals(8, report.pushed)
        assertEquals(listOf("0/8", "3/8", "6/8", "8/8"), seen)
        assertEquals(7, server.rows.values.count { it.table == "entries" })
        assertTrue(juan.pending().isEmpty())
        assertEquals(0, SyncEngine(juan, server).run().pushed)
    }

    @Test fun secondDevicePullsFirstJoinsTheRepeatedCategoryAndPushesOnlyItsOwn() = runBlocking {
        val server = Server()
        val juan = Local()
        val petsJuan = juan.add("categories", at = at(1), fields = mapOf("name" to "Mascotas"))
        val shared = juan.add("entries", at = at(2), fields = mapOf("name" to "Concentrado", "categoryId" to petsJuan))
        SyncEngine(juan, server).initialUpload()
        assertEquals(1, server.pushes)

        val tablet = Local()
        val petsTablet = tablet.add("categories", at = at(3), fields = mapOf("name" to "mascotas "))
        val vet = tablet.add("entries", at = at(4), fields = mapOf("name" to "Veterinaria", "categoryId" to petsTablet))
        // El mismo movimiento ya estaba aquí (por un respaldo) pero más viejo: gana la nube y no se sube.
        tablet.add("entries", shared, at(1), mapOf("name" to "Viejo"))
        val report = SyncEngine(tablet, server).initialUpload()

        assertEquals(mapOf("categories" to mapOf(petsTablet to petsJuan)), tablet.resolved)
        assertNull(tablet.rows["categories/$petsTablet"])
        assertEquals(petsJuan, tablet.rows["entries/$vet"]!!.fields["categoryId"])
        assertEquals("Concentrado", tablet.rows["entries/$shared"]!!.fields["name"])
        assertEquals(1, report.pushed)
        assertEquals(1, server.rows.values.count { it.table == "categories" })
        assertEquals(2, server.rows.values.count { it.table == "entries" })
        assertTrue(tablet.cursors["entries"] != null)
        assertEquals(0, SyncEngine(tablet, server).run().pushed)
    }

    @Test fun syncedRowTheCloudDoesNotHaveIsUploadedAgain() = runBlocking {
        val server = Server()
        val local = Local()
        val id = local.add("entries", at = at(2), fields = mapOf("name" to "Mercado"), pending = false)
        assertTrue(local.pending().isEmpty())
        assertEquals(1, SyncEngine(local, server).initialUpload().pushed)
        assertTrue(server.rows.containsKey("entries/$id"))
    }

    @Test fun offlineFirstUploadRetriesWithoutRepeating() = runBlocking {
        val server = Server()
        val local = Local()
        for (day in 1..4) local.add("entries", at = at(day))
        server.failNext = 1
        val failed = runCatching { SyncEngine(local, server, 2).initialUpload() }
        assertTrue(failed.exceptionOrNull() is Server.Offline)
        assertEquals(4, SyncEngine(local, server, 2).initialUpload().pushed)
        assertEquals(4, server.rows.size)
        val again = SyncEngine(local, server).initialUpload()
        assertEquals(0, again.pushed)
        assertEquals(4, again.skipped)
    }
}
