import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Tokens de la cuenta Microsoft. Se guardan como un único blob JSON en el
/// llavero para evitar estados a medias (access sin refresh).
struct MicrosoftTokenSet: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var accountName: String?
}

/// OAuth 2.0 (authorization code + PKCE S256) contra Microsoft Entra ID para
/// cuentas personales, sin MSAL: ASWebAuthenticationSession + URLSession.
@MainActor
final class MicrosoftAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = MicrosoftAuthService()

    // 'consumers' y no 'common': fuerza cuenta personal (outlook.com/hotmail)
    // y evita que un tenant corporativo intercepte el login.
    private static let authority = "https://login.microsoftonline.com/consumers/oauth2/v2.0"
    private static let redirectURI = "jarvis-auth://callback"
    private static let callbackScheme = "jarvis-auth"
    private static let scopes = "openid profile offline_access User.Read Mail.Read Mail.Send"

    static let clientIdDefaultsKey = "jarvis.msClientId"

    private var session: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    // MARK: - Estado

    var isSignedIn: Bool { tokenSet != nil }

    var accountName: String? { tokenSet?.accountName }

    private var tokenSet: MicrosoftTokenSet? {
        get {
            guard let json = KeychainStore.read(account: KeychainStore.microsoftTokensAccount),
                  let data = json.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(MicrosoftTokenSet.self, from: data)
        }
        set {
            guard let newValue,
                  let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                KeychainStore.delete(account: KeychainStore.microsoftTokensAccount)
                return
            }
            KeychainStore.save(json, account: KeychainStore.microsoftTokensAccount)
        }
    }

    private var clientId: String? {
        let value = UserDefaults.standard.string(forKey: Self.clientIdDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    // MARK: - Inicio y cierre de sesión

    func signIn() async throws {
        guard let clientId else {
            throw ToolError("Falta el Application ID de Azure. Pégalo en los ajustes (instrucciones en el README).")
        }

        // PKCE: verifier aleatorio y challenge SHA-256 en base64url.
        let verifier = Self.base64URLEncoded(Self.randomBytes(count: 64))
        let challengeDigest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Self.base64URLEncoded(Data(challengeDigest))
        let state = UUID().uuidString

        var components = URLComponents(string: "\(Self.authority)/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]

        let callbackURL = try await authenticate(url: components.url!)

        let query = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func queryValue(_ name: String) -> String? {
            query.first(where: { $0.name == name })?.value
        }

        if let error = queryValue("error") {
            let description = queryValue("error_description") ?? error
            throw ToolError("Microsoft rechazó el inicio de sesión: \(String(description.prefix(160)))")
        }
        guard queryValue("state") == state, let code = queryValue("code") else {
            throw ToolError("Respuesta de inicio de sesión no válida.")
        }

        let tokens = try await requestToken(parameters: [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "code_verifier": verifier,
            "scope": Self.scopes,
        ])
        tokenSet = tokens

        await fetchAccountName()
    }

    func signOut() {
        tokenSet = nil
    }

    /// Devuelve un access token vigente, refrescándolo si ha caducado.
    func validAccessToken() async throws -> String {
        guard var tokens = tokenSet else {
            throw ToolError("No ha iniciado sesión en Microsoft. Puede hacerlo en los ajustes.")
        }
        if tokens.expiresAt > Date() {
            return tokens.accessToken
        }

        guard let clientId else {
            throw ToolError("Falta el Application ID de Azure en los ajustes.")
        }
        do {
            var refreshed = try await requestToken(parameters: [
                "client_id": clientId,
                "grant_type": "refresh_token",
                "refresh_token": tokens.refreshToken,
                "scope": Self.scopes,
            ])
            refreshed.accountName = tokens.accountName
            tokenSet = refreshed
            return refreshed.accessToken
        } catch let error as MicrosoftOAuthError where error.code == "invalid_grant" {
            // Refresh token caducado o revocado: hay que volver a iniciar sesión.
            tokenSet = nil
            throw ToolError("Su sesión de Microsoft ha caducado. Vuelva a iniciar sesión en los ajustes.")
        }
    }

    /// Fuerza un refresh (para reintentar tras un 401 de Graph).
    func forceRefreshedAccessToken() async throws -> String {
        if var tokens = tokenSet {
            tokens.expiresAt = .distantPast
            tokenSet = tokens
        }
        return try await validAccessToken()
    }

    // MARK: - ASWebAuthenticationSession

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: ToolError("Inicio de sesión cancelado."))
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: ToolError("Respuesta de inicio de sesión vacía."))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
        }
    }

    // MARK: - Token endpoint

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    private struct OAuthErrorResponse: Decodable {
        let error: String?
        let errorDescription: String?

        private enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    private func requestToken(parameters: [String: String]) async throws -> MicrosoftTokenSet {
        var request = URLRequest(url: URL(string: "\(Self.authority)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(parameters).data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ToolError("No se pudo conectar con Microsoft.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ToolError("Respuesta inesperada de Microsoft.")
        }

        guard http.statusCode == 200 else {
            let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data)
            throw MicrosoftOAuthError(
                code: oauthError?.error ?? "http_\(http.statusCode)",
                message: String((oauthError?.errorDescription ?? "error \(http.statusCode)").prefix(200))
            )
        }

        guard let tokens = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw ToolError("Respuesta de tokens no válida.")
        }

        return MicrosoftTokenSet(
            accessToken: tokens.accessToken,
            // Microsoft rota los refresh tokens: usar siempre el más reciente.
            refreshToken: tokens.refreshToken ?? tokenSet?.refreshToken ?? "",
            expiresAt: Date().addingTimeInterval(TimeInterval(max(tokens.expiresIn - 120, 60))),
            accountName: nil
        )
    }

    private func fetchAccountName() async {
        guard var tokens = tokenSet else { return }
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me?$select=displayName,mail,userPrincipalName")!)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")

        struct Me: Decodable {
            let displayName: String?
            let mail: String?
            let userPrincipalName: String?
        }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let me = try? JSONDecoder().decode(Me.self, from: data) else {
            return
        }
        tokens.accountName = me.mail ?? me.userPrincipalName ?? me.displayName
        tokenSet = tokens
    }

    // MARK: - Utilidades

    private static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ parameters: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return parameters
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
    }
}

/// Error del endpoint de tokens, con el código OAuth para poder distinguir
/// `invalid_grant` (sesión caducada) de otros fallos.
struct MicrosoftOAuthError: LocalizedError {
    let code: String
    let message: String

    var errorDescription: String? {
        "Error de Microsoft (\(code)): \(message)"
    }
}
