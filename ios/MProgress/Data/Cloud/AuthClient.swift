import Foundation

/// Sesión de Supabase Auth guardada en el llavero.
struct CloudSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: UUID
    var email: String

    /// Se renueva un minuto antes de vencer.
    func needsRefresh(now: Date = .now) -> Bool { expiresAt.timeIntervalSince(now) < 60 }
}

/// Supabase Auth (GoTrue) por HTTPS: enlace mágico con PKCE, renovación y cierre de sesión (docs/PLAN_F10.md).
enum AuthClient {
    private struct TokenResponse: Decodable {
        struct User: Decodable {
            let id: String
            let email: String?
        }

        let access_token: String
        let refresh_token: String
        let expires_in: Double?
        let expires_at: Double?
        let user: User?
    }

    /// Manda el enlace mágico. `create_user` crea la cuenta si el correo es nuevo.
    static func sendMagicLink(email: String, codeChallenge: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "create_user": true,
            "code_challenge": codeChallenge,
            "code_challenge_method": "s256",
        ]
        let url = SupabaseHTTP.url(CloudConfig.authURL, path: "otp", query: [("redirect_to", CloudConfig.redirectURL)])
        _ = try await SupabaseHTTP.send(.post, url, body: try JSONSerialization.data(withJSONObject: body))
    }

    /// Cambia el `code` del enlace por la sesión.
    static func exchange(code: String, verifier: String, email: String?) async throws -> CloudSession {
        let url = SupabaseHTTP.url(CloudConfig.authURL, path: "token", query: [("grant_type", "pkce")])
        do {
            let data = try await SupabaseHTTP.send(.post, url, body: try JSONSerialization.data(withJSONObject: [
                "auth_code": code, "code_verifier": verifier,
            ]))
            return try session(from: data, fallbackEmail: email)
        } catch CloudError.server(let status, _) where (400..<500).contains(status) {
            throw CloudError.linkExpired
        }
    }

    /// Código de 6 dígitos del correo (solo con `CloudConfig.allowsCodeEntry`).
    static func verify(email: String, code: String) async throws -> CloudSession {
        let url = SupabaseHTTP.url(CloudConfig.authURL, path: "verify")
        let data = try await SupabaseHTTP.send(.post, url, body: try JSONSerialization.data(withJSONObject: [
            "type": "email", "email": email, "token": code,
        ]))
        return try session(from: data, fallbackEmail: email)
    }

    static func refresh(_ current: CloudSession) async throws -> CloudSession {
        let url = SupabaseHTTP.url(CloudConfig.authURL, path: "token", query: [("grant_type", "refresh_token")])
        do {
            let data = try await SupabaseHTTP.send(.post, url, body: try JSONSerialization.data(withJSONObject: [
                "refresh_token": current.refreshToken,
            ]))
            return try session(from: data, fallbackEmail: current.email)
        } catch CloudError.server(let status, _) where (400..<500).contains(status) {
            throw CloudError.notSignedIn
        }
    }

    /// Cierra la sesión en el servidor. Si falla (sin conexión), igual se cierra en el iPhone.
    static func signOut(accessToken: String) async {
        let url = SupabaseHTTP.url(CloudConfig.authURL, path: "logout")
        _ = try? await SupabaseHTTP.send(.post, url, accessToken: accessToken)
    }

    private static func session(from data: Data, fallbackEmail: String?) throws -> CloudSession {
        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data),
              let user = token.user, let userId = UUID(uuidString: user.id) else { throw CloudError.badResponse }
        let expiresAt = token.expires_at.map { Date(timeIntervalSince1970: $0) }
            ?? Date.now.addingTimeInterval(token.expires_in ?? 3600)
        return CloudSession(accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: expiresAt,
                            userId: userId, email: user.email ?? fallbackEmail ?? "")
    }
}
