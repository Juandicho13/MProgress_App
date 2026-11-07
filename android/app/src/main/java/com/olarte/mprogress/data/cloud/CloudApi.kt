package com.olarte.mprogress.data.cloud

import com.olarte.mprogress.domain.E2EEFormat
import com.olarte.mprogress.domain.EnvelopeTransport
import com.olarte.mprogress.domain.ServerTime
import com.olarte.mprogress.domain.SyncEnvelope
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/** Un dispositivo de la cuenta, como lo devuelve `devices`. */
data class RemoteDevice(val id: String, val name: String?, val platform: String?, val publicKey: String?, val createdAt: Instant?, val lastSeenAt: Instant?) {
    val publicKeyData: ByteArray? get() = publicKey?.let(E2EEFormat::unb64)
}

/** Una llave de espacio envuelta (`space_keys`). `deviceId` null es la del código de recuperación. */
data class RemoteSpaceKey(val id: String, val deviceId: String?, val wrappedKey: String)

private fun JSONObject.strOrNull(k: String): String? = if (!has(k) || isNull(k)) null else optString(k)
private fun parseArray(text: String): JSONArray = runCatching { JSONArray(text) }.getOrNull() ?: throw CloudError.BadResponse()
private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }

/** Llamadas a PostgREST con la sesión del usuario, como CloudAPI de iOS. La seguridad por fila decide qué ve y qué escribe. */
class CloudApi(private val accessToken: suspend () -> String) {
    private suspend fun send(method: String, path: String, query: List<Pair<String, String>> = emptyList(), body: String? = null, prefer: String? = null): String =
        SupabaseHttp.send(method, SupabaseHttp.url(CloudConfig.REST_URL, path, query), body, accessToken(), prefer?.let { mapOf("Prefer" to it) } ?: emptyMap())

    /** El espacio Personal de la cuenta (lo crea el servidor al crear la cuenta). Si no está, lo crea. */
    suspend fun personalSpaceId(userId: String): String {
        val text = send("GET", "spaces", listOf("select" to "id", "owner_id" to "eq.${E2EEFormat.id(userId)}", "kind" to "eq.personal",
            "deleted_at" to "is.null", "order" to "created_at.asc", "limit" to "1"))
        parseArray(text).objects().firstOrNull()?.optString("id")?.takeIf { it.isNotEmpty() }?.let { return it.lowercase() }
        val body = JSONObject().put("owner_id", E2EEFormat.id(userId)).put("name", "Personal").put("kind", "personal").toString()
        val created = send("POST", "spaces", listOf("select" to "id"), body, "return=representation")
        return parseArray(created).objects().firstOrNull()?.optString("id")?.lowercase() ?: throw CloudError.BadResponse()
    }

    /** Registra (o actualiza) este dispositivo con su llave pública. */
    suspend fun registerDevice(id: String, userId: String, publicKey: ByteArray, name: String) {
        val body = JSONArray().put(JSONObject().put("id", E2EEFormat.id(id)).put("user_id", E2EEFormat.id(userId)).put("platform", "android").put("name", name)
            .put("public_key", E2EEFormat.b64(publicKey)).put("last_seen_at", ServerTime.format(ServerTime.now())))
        send("POST", "devices", listOf("on_conflict" to "id"), body.toString(), "resolution=merge-duplicates,return=minimal")
    }

    suspend fun devices(): List<RemoteDevice> =
        parseArray(send("GET", "devices", listOf("select" to "id,name,platform,public_key,created_at,last_seen_at", "order" to "created_at.asc"))).objects().map {
            RemoteDevice(it.getString("id").lowercase(), it.strOrNull("name"), it.strOrNull("platform"), it.strOrNull("public_key"),
                it.strOrNull("created_at")?.let(ServerTime::parse), it.strOrNull("last_seen_at")?.let(ServerTime::parse))
        }

    suspend fun deleteDevice(id: String) { send("DELETE", "devices", listOf("id" to "eq.${E2EEFormat.id(id)}"), prefer = "return=minimal") }

    suspend fun spaceKeys(spaceId: String): List<RemoteSpaceKey> =
        parseArray(send("GET", "space_keys", listOf("select" to "id,device_id,wrapped_key", "space_id" to "eq.${E2EEFormat.id(spaceId)}"))).objects().map {
            RemoteSpaceKey(it.getString("id"), it.strOrNull("device_id")?.lowercase(), it.getString("wrapped_key"))
        }

    /** Guarda una llave envuelta para un dispositivo (o la de recuperación con `deviceId` null). */
    suspend fun addSpaceKey(spaceId: String, deviceId: String?, wrappedKey: String) {
        val row = JSONObject().put("space_id", E2EEFormat.id(spaceId)).put("wrapped_key", wrappedKey).put("device_id", deviceId?.let(E2EEFormat::id) ?: JSONObject.NULL)
        send("POST", "space_keys", body = row.toString(), prefer = "return=minimal")
    }

    /** Quita la llave de recuperación (para poner una nueva al cambiar el código). */
    suspend fun deleteRecoveryKey(spaceId: String) {
        send("DELETE", "space_keys", listOf("space_id" to "eq.${E2EEFormat.id(spaceId)}", "device_id" to "is.null"), prefer = "return=minimal")
    }

    /** Borra la cuenta remota y todo lo suyo en el servidor (función `delete_my_account`). */
    suspend fun deleteMyAccount() { send("POST", "rpc/delete_my_account", body = "{}") }

    suspend fun token() = accessToken()
}

/** Sobres de `sync_records` por PostgREST: upsert por id y bajada por tipo desde un cursor del servidor. */
class PostgrestEnvelopeTransport(private val api: CloudApi, private val pageSize: Int = 1000) : EnvelopeTransport {
    override suspend fun upsert(rows: List<SyncEnvelope>) {
        // `deleted_at` va siempre (null incluido) para que un registro restaurado vuelva a estar vivo.
        val body = JSONArray(rows.map {
            JSONObject().put("id", E2EEFormat.id(it.id)).put("space_id", E2EEFormat.id(it.spaceId)).put("entity", it.entity).put("payload", it.payload)
                .put("changed_at", ServerTime.format(it.changedAt)).put("deleted_at", it.deletedAt?.let(ServerTime::format) ?: JSONObject.NULL)
        })
        val url = SupabaseHttp.url(CloudConfig.REST_URL, "sync_records", listOf("on_conflict" to "id", "columns" to "id,space_id,entity,payload,changed_at,deleted_at"))
        SupabaseHttp.send("POST", url, body.toString(), api.token(), mapOf("Prefer" to "resolution=merge-duplicates,return=minimal"))
    }

    override suspend fun fetch(entity: String, since: Instant?): List<SyncEnvelope> {
        val result = mutableListOf<SyncEnvelope>()
        var cursor = since
        while (true) {
            val query = mutableListOf("select" to "id,space_id,entity,payload,changed_at,updated_at,deleted_at", "entity" to "eq.$entity",
                "order" to "updated_at.asc", "limit" to "$pageSize")
            cursor?.let { query += "updated_at" to "gt.${ServerTime.format(it)}" }
            val text = SupabaseHttp.send("GET", SupabaseHttp.url(CloudConfig.REST_URL, "sync_records", query), accessToken = api.token())
            val page = parseArray(text).objects().map {
                SyncEnvelope(it.getString("id").lowercase(), it.getString("space_id").lowercase(), it.getString("entity"), it.getString("payload"),
                    ServerTime.parse(it.getString("changed_at")) ?: throw CloudError.BadResponse(), it.strOrNull("updated_at")?.let(ServerTime::parse),
                    it.strOrNull("deleted_at")?.let(ServerTime::parse))
            }
            result += page
            val last = page.lastOrNull()?.updatedAt
            if (page.size < pageSize || last == null) break
            cursor = last
        }
        return result
    }
}
