package com.olarte.mprogress.data.cloud

/**
 * Proyecto de Supabase de MProgress (supabase/PROYECTO.md). La publishable key tiene permisos bajos y los datos los protege la
 * seguridad por fila: puede ir en la app. La secret key nunca va aquí.
 */
object CloudConfig {
    const val PROJECT_URL = "https://qucnkajomuguqurwsvuy.supabase.co"
    const val PUBLISHABLE_KEY = "sb_publishable_XYShe2GRVe4sOi4Jh-Mb1Q_Ij_w5hGR"
    /** A donde vuelve el enlace mágico del correo. Configurado en Supabase › Authentication › URL Configuration. */
    const val REDIRECT_URL = "mprogress://auth-callback"
    const val CALLBACK_SCHEME = "mprogress"
    const val CALLBACK_HOST = "auth-callback"
    const val AUTH_URL = "$PROJECT_URL/auth/v1"
    const val REST_URL = "$PROJECT_URL/rest/v1"
}
