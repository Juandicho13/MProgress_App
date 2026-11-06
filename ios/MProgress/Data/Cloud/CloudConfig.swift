import Foundation

/// Proyecto de Supabase de MProgress (supabase/PROYECTO.md). La publishable key tiene permisos bajos y los
/// datos los protege la seguridad por fila: puede ir en la app. La secret key nunca va aquí.
enum CloudConfig {
    static let projectURL = URL(string: "https://qucnkajomuguqurwsvuy.supabase.co")!
    static let publishableKey = "sb_publishable_XYShe2GRVe4sOi4Jh-Mb1Q_Ij_w5hGR"
    /// A donde vuelve el enlace mágico del correo. Configurado en Supabase › Authentication › URL Configuration.
    static let redirectURL = "mprogress://auth-callback"
    static let callbackHost = "auth-callback"
    /// Escribir el código de 6 dígitos del correo (`POST /auth/v1/verify`). Apagado hasta tener SMTP propio,
    /// porque el correo por defecto de Supabase no muestra el código.
    static let allowsCodeEntry = false

    static var authURL: URL { projectURL.appending(path: "auth/v1") }
    static var restURL: URL { projectURL.appending(path: "rest/v1") }
}
