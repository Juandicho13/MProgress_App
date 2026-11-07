package com.olarte.mprogress.domain

import java.time.Instant

/**
 * Una fila lista para subir o recién bajada (HANDOFF 9), igual que ios/MProgress/Domain/Sync.swift. `payload` es la fila del respaldo
 * en JSON; viaja cifrada dentro de un sobre (EncryptedRemote). `updatedAt` es cuándo cambió en el teléfono y decide los choques.
 */
class SyncRecord(
    val table: String,
    val id: String,
    val updatedAt: Instant,
    val deletedAt: Instant? = null,
    val payload: ByteArray = ByteArray(0),
    /** Espacio al que pertenece. Null: el espacio por defecto del que sincroniza. */
    val spaceId: String? = null,
    /** Cuándo llegó al servidor (lo pone el servidor). Es el cursor para bajar cambios. */
    val serverUpdatedAt: Instant? = null,
)

sealed class SyncStatus {
    data object Sincronizado : SyncStatus()
    data object Sincronizando : SyncStatus()
    data class SinConexion(val pending: Int) : SyncStatus()
    data class Error(val detail: String) : SyncStatus()

    val title get() = when (this) {
        Sincronizado -> "Sincronizado"
        Sincronizando -> "Sincronizando"
        is SinConexion -> "Sin conexión"
        is Error -> "Error"
    }
}

/** El servidor (Supabase). En las pruebas es una memoria. */
interface RemoteSyncStore {
    /** Upsert por id. Si falla, lanza. */
    suspend fun push(records: List<SyncRecord>)
    /** Filas de una tabla cambiadas después de `since` (borrados incluidos), de la más vieja a la más nueva. */
    suspend fun pull(table: String, since: Instant?): List<SyncRecord>
}

/** La base local. */
interface LocalSyncStore {
    /** Cambios pendientes en el orden en que se hicieron. */
    fun pending(): List<SyncRecord>
    fun markSynced(records: List<SyncRecord>)
    /** Suma un intento fallido; al tercero la fila queda fallida. */
    fun markFailed(records: List<SyncRecord>, attempts: Int)
    fun attempts(record: SyncRecord): Int
    /** La versión local de una fila, si existe. */
    fun local(table: String, id: String): SyncRecord?
    /** Escribe una fila que bajó del servidor, sin marcarla pendiente. */
    fun apply(record: SyncRecord)
    fun cursor(table: String): Instant?
    fun setCursor(date: Instant, table: String)
}

/** Motor de sincronización: sube los pendientes, baja lo nuevo y resuelve choques por `updatedAt` (gana el más reciente). */
class SyncEngine(private val local: LocalSyncStore, private val remote: RemoteSyncStore, private val batchSize: Int = 200) {
    data class Report(var pushed: Int = 0, var pulled: Int = 0, var skipped: Int = 0, var failed: Int = 0)

    suspend fun run(): Report {
        val report = Report()
        val pending = local.pending()
        for (batch in pending.chunked(batchSize)) {
            try {
                remote.push(batch)
                local.markSynced(batch)
                report.pushed += batch.size
            } catch (e: Exception) {
                val attempts = batch.maxOfOrNull { local.attempts(it) + 1 } ?: 1
                local.markFailed(batch, attempts)
                report.failed += batch.size
                if (attempts >= MAX_ATTEMPTS) continue
                throw e
            }
        }
        for (table in TABLES) {
            val rows = remote.pull(table, local.cursor(table))
            for (row in rows) {
                val mine = local.local(table, row.id)
                if (mine != null && !remoteWins(row, mine)) { report.skipped++; continue }
                local.apply(row)
                report.pulled++
            }
            // El cursor es la hora del servidor (si la hay): así no se pierde nada por relojes distintos.
            rows.maxOfOrNull { it.serverUpdatedAt ?: it.updatedAt }?.let { local.setCursor(it, table) }
        }
        return report
    }

    companion object {
        const val MAX_ATTEMPTS = 3
        /** Orden de las tablas: primero lo que otras filas referencian. */
        val TABLES = listOf("spaces", "categories", "institutions", "reward_programs", "products", "recurring", "entries", "splits",
            "transfers", "reminders", "budgets", "savings_goals", "goal_contributions")

        /** Gana el `updatedAt` más reciente; si empatan, gana el servidor para que todos los teléfonos terminen igual. */
        fun remoteWins(remote: SyncRecord, local: SyncRecord) = remote.updatedAt >= local.updatedAt

        /** Estado para la pastilla de Inicio. */
        fun status(online: Boolean, pending: Int, failed: Int, running: Boolean): SyncStatus = when {
            failed > 0 -> SyncStatus.Error("$failed ${if (failed == 1) "cambio no subió" else "cambios no subieron"}")
            !online -> SyncStatus.SinConexion(pending)
            running || pending > 0 -> SyncStatus.Sincronizando
            else -> SyncStatus.Sincronizado
        }

        /** "Sin conexión · 3 cambios sin sincronizar". */
        fun pillText(status: SyncStatus): String? = when (status) {
            is SyncStatus.SinConexion -> if (status.pending == 0) "Sin conexión" else "Sin conexión · ${status.pending} ${if (status.pending == 1) "cambio" else "cambios"} sin sincronizar"
            is SyncStatus.Error -> "Error · ${status.detail}"
            else -> null
        }
    }
}

/** Una fila de `sync_records` tal como la ve Supabase: solo ids, tipo y fechas en claro; el resto cifrado. */
data class SyncEnvelope(
    val id: String,
    val spaceId: String,
    val entity: String,
    /** base64(AES-GCM(JSON del registro)) con datos asociados "espacio|entidad|id". */
    val payload: String,
    /** Cuándo cambió en el teléfono: decide quién gana. */
    val changedAt: Instant,
    /** Cuándo llegó al servidor: lo pone el servidor. Null al subir. */
    val updatedAt: Instant? = null,
    val deletedAt: Instant? = null,
)

/** El transporte de los sobres (PostgREST en la app, una memoria en las pruebas). */
interface EnvelopeTransport {
    suspend fun upsert(rows: List<SyncEnvelope>)
    /** Sobres de un tipo que llegaron al servidor después de `since`, del más viejo al más nuevo. */
    suspend fun fetch(entity: String, since: Instant?): List<SyncEnvelope>
}

/** RemoteSyncStore que cifra al subir y descifra al bajar: el SyncEngine de siempre, con sobres. */
class EncryptedRemote(
    private val transport: EnvelopeTransport,
    private val crypto: CryptoProvider,
    /** Espacio de los registros que no dicen el suyo. */
    private val defaultSpaceId: String,
    /** Llave de cada espacio; null si este dispositivo no la tiene. */
    private val keyFor: (String) -> ByteArray?,
) : RemoteSyncStore {
    /** Sobres que bajaron pero no se pudieron abrir (sin llave o alterados). Se ignoran. */
    var unreadable = 0
        private set

    override suspend fun push(records: List<SyncRecord>) {
        val rows = records.map { record ->
            val space = E2EEFormat.id(record.spaceId ?: defaultSpaceId)
            val key = keyFor(space) ?: throw E2EEError.MissingKey()
            SyncEnvelope(E2EEFormat.id(record.id), space, record.table, Envelope.seal(record.payload, space, record.table, record.id, key, crypto),
                record.updatedAt, null, record.deletedAt)
        }
        if (rows.isEmpty()) return
        transport.upsert(rows)
    }

    override suspend fun pull(table: String, since: Instant?): List<SyncRecord> =
        transport.fetch(table, since).mapNotNull { row ->
            val key = keyFor(E2EEFormat.id(row.spaceId))
            val payload = key?.let { runCatching { Envelope.open(row.payload, row.spaceId, row.entity, row.id, it, crypto) }.getOrNull() }
            if (payload == null) { unreadable++; null }
            else SyncRecord(row.entity, E2EEFormat.id(row.id), row.changedAt, row.deletedAt, payload, E2EEFormat.id(row.spaceId), row.updatedAt)
        }
}
