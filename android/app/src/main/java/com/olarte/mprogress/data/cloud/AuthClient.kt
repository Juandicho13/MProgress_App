package com.olarte.mprogress.data.cloud

import com.olarte.mprogress.domain.ServerTime
import org.json.JSONObject
import java.time.Instant

/** Sesión de Supabase Auth, guardada cifrada con una llave del Android Keystore. */
data class CloudSession(val accessToken: String, val refreshToken: String, val expiresAt: Instant, val userId: String, val email: String) {
    /** Se renueva un minuto antes de vencer. */
    fun needsRefresh(now: Instant = Instant.now()) = expiresAt.epochSecond - now.epochSecond < 60

    fun toJson(): String = JSONObject().put("accessToken", accessToken).put("refreshToken", refreshToken).put("expiresAt", ServerTime.format(expiresAt))
        .put("userId", userId).put("email", email).toString()

    companion object {
        fun fromJson(text: String): CloudSession? = runCatching {
            val o = JSONObject(text)
            CloudSession(o.getString("accessToken"), o.getString("refreshToken"), ServerTime.parse(o.getString("expiresAt"))!!, o.getString("userId"), o.optString("email"))
        }.getOrNull()
    }
}

/** Supabase Auth (GoTrue) por HTTPS: enlace mágico con PKCE, renovación y cierre de sesión (docs/PLAN_F10.md), igual que iOS. */
object AuthClient {
    /** Manda el enlace mágico. `create_user` crea la cuenta si el correo es nuevo. */
    suspend fun sendMagicLink(email: String, codeChallenge: String) {
        val body = JSONObject().put("email", email).put("create_user", true).put("code_challenge", codeChallenge).put("code_challenge_method", "s256")
        SupabaseHttp.send("POST", SupabaseHttp.url(CloudConfig.AUTH_URL, "otp", listOf("redirect_to" to CloudConfig.REDIRECT_URL)), body.toString())
    }

    /** Cambia el `code` del enlace por la sesión. */
    suspend fun exchange(code: String, verifier: String, email: String?): CloudSession {
        val url = SupabaseHttp.url(CloudConfig.AUTH_URL, "token", listOf("grant_type" to "pkce"))
        val text = try {
            SupabaseHttp.send("POST", url, JSONObject().put("auth_code", code).put("code_verifier", verifier).toString())
        } catch (e: CloudError.Server) {
            if (e.status in 400..499) throw CloudError.LinkExpired() else throw e
        }
        return session(text, email)
    }

    suspend fun refresh(current: CloudSession): CloudSession {
        val url = SupabaseHttp.url(CloudConfig.AUTH_URL, "token", listOf("grant_type" to "refresh_token"))
        val text = try {
            SupabaseHttp.send("POST", url, JSONObject().put("refresh_token", current.refreshToken).toString())
        } catch (e: CloudError.Server) {
            if (e.status in 400..499) throw CloudError.NotSignedIn() else throw e
        }
        return session(text, current.email)
    }

    /** Cierra la sesión en el servidor. Si falla (sin conexión), igual se cierra en el teléfono. */
    suspend fun signOut(accessToken: String) {
        runCatching { SupabaseHttp.send("POST", SupabaseHttp.url(CloudConfig.AUTH_URL, "logout"), accessToken = accessToken) }
    }

    fun session(text: String, fallbackEmail: String?, now: Instant = Instant.now()): CloudSession {
        val o = runCatching { JSONObject(text) }.getOrNull() ?: throw CloudError.BadResponse()
        val user = o.optJSONObject("user") ?: throw CloudError.BadResponse()
        val access = o.optString("access_token"); val refresh = o.optString("refresh_token"); val userId = user.optString("id")
        if (access.isEmpty() || refresh.isEmpty() || userId.isEmpty()) throw CloudError.BadResponse()
        val expiresAt = if (o.has("expires_at") && !o.isNull("expires_at")) Instant.ofEpochSecond(o.getLong("expires_at"))
            else now.plusSeconds(o.optLong("expires_in", 3600))
        val email = user.optString("email").ifEmpty { fallbackEmail ?: "" }
        return CloudSession(access, refresh, expiresAt, userId.lowercase(), email)
    }
}
