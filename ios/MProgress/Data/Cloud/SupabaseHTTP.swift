import Foundation

/// Errores de la nube con textos para la persona.
enum CloudError: Error, LocalizedError, Equatable {
    case offline
    case notSignedIn
    case server(status: Int, message: String)
    case badResponse
    case linkExpired

    var errorDescription: String? {
        switch self {
        case .offline: "Sin conexión. Tus cambios se guardan en el iPhone y se suben cuando vuelva el internet."
        case .notSignedIn: "Tu sesión se cerró. Vuelve a entrar con tu correo."
        case .server(let status, let message):
            status == 429 ? "Pediste muchos correos seguidos. Espera unos minutos e intenta de nuevo." : "La nube respondió con un error (\(status)). \(message)"
        case .badResponse: "La nube respondió algo que la app no entiende."
        case .linkExpired: "Ese enlace ya no sirve. Pide uno nuevo desde este iPhone."
        }
    }
}

/// Llamadas HTTPS a Supabase (Auth y PostgREST) sin SDK. Solo con la publishable key y, si hay sesión,
/// el access token del usuario.
enum SupabaseHTTP {
    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    /// Hace la llamada y devuelve el cuerpo. Lanza `CloudError` con el estado si no es 2xx.
    static func send(_ method: Method, _ url: URL, body: Data? = nil, accessToken: String? = nil,
                     headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        request.setValue(CloudConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = body

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                throw CloudError.offline
            default:
                throw error
            }
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else { throw CloudError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudError.server(status: http.statusCode, message: errorMessage(data))
        }
        return data
    }

    /// URL con parámetros de consulta ya codificados (PostgREST usa `columna=eq.valor`).
    static func url(_ base: URL, path: String, query: [(String, String)] = []) -> URL {
        var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        // URLComponents no codifica "+": en una fecha cambiaría el sentido.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    static func json<T: Encodable>(_ value: T) throws -> Data {
        try ServerTime.encoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do {
            return try ServerTime.decoder().decode(type, from: data)
        } catch {
            throw CloudError.badResponse
        }
    }

    private static func errorMessage(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        for key in ["msg", "message", "error_description", "error"] {
            if let text = object[key] as? String, !text.isEmpty { return text }
        }
        return ""
    }
}
