package com.olarte.mprogress.data.cloud

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Errores de la nube con textos para la persona (los mismos de iOS, con "teléfono" en vez de "iPhone"). */
sealed class CloudError(message: String) : Exception(message) {
    class Offline : CloudError("Sin conexión. Tus cambios se guardan en el teléfono y se suben cuando vuelva el internet.")
    class NotSignedIn : CloudError("Tu sesión se cerró. Vuelve a entrar con tu correo.")
    class Server(val status: Int, detail: String) : CloudError(
        if (status == 429) "Pediste muchos correos seguidos. Espera unos minutos e intenta de nuevo." else "La nube respondió con un error ($status). $detail".trim())
    class BadResponse : CloudError("La nube respondió algo que la app no entiende.")
    class LinkExpired : CloudError("Ese enlace ya no sirve. Pide uno nuevo desde este teléfono.")
}

/** Llamadas HTTPS a Supabase (Auth y PostgREST) sin SDK, con HttpURLConnection. Solo la publishable key y el token del usuario. */
object SupabaseHttp {
    /** Para las pruebas: cambia la red por una respuesta escrita a mano. */
    var transport: (suspend (method: String, url: String, headers: Map<String, String>, body: String?) -> Pair<Int, String>)? = null

    suspend fun send(method: String, url: String, body: String? = null, accessToken: String? = null, headers: Map<String, String> = emptyMap()): String {
        val all = mutableMapOf("apikey" to CloudConfig.PUBLISHABLE_KEY, "Content-Type" to "application/json", "Accept" to "application/json")
        accessToken?.let { all["Authorization"] = "Bearer $it" }
        all.putAll(headers)
        val (status, text) = transport?.invoke(method, url, all, body) ?: withContext(Dispatchers.IO) { real(method, url, all, body) }
        if (status !in 200..299) throw CloudError.Server(status, errorMessage(text))
        return text
    }

    private fun real(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        val conn = try { URL(url).openConnection() as HttpURLConnection } catch (e: IOException) { throw CloudError.Offline() }
        try {
            conn.requestMethod = method
            conn.connectTimeout = 30_000
            conn.readTimeout = 30_000
            conn.useCaches = false
            headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
            if (body != null) {
                conn.doOutput = true
                conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = conn.responseCode
            val stream = if (status in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
            return status to text
        } catch (e: IOException) {
            // Sin internet, DNS que no responde, tiempo agotado: todo cuenta como sin conexión.
            throw CloudError.Offline()
        } finally {
            conn.disconnect()
        }
    }

    /** URL con parámetros de consulta codificados (PostgREST usa `columna=eq.valor`). El "+" de una fecha va como %2B. */
    fun url(base: String, path: String, query: List<Pair<String, String>> = emptyList()): String {
        if (query.isEmpty()) return "$base/$path"
        fun enc(s: String) = URLEncoder.encode(s, "UTF-8").replace("+", "%20")
        return "$base/$path?" + query.joinToString("&") { (k, v) -> "${enc(k)}=${enc(v)}" }
    }

    private fun errorMessage(text: String): String {
        val o = runCatching { JSONObject(text) }.getOrNull() ?: return ""
        for (k in listOf("msg", "message", "error_description", "error")) {
            val v = o.optString(k)
            if (v.isNotEmpty()) return v
        }
        return ""
    }
}
