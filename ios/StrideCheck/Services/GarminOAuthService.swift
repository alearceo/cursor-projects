import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

enum GarminOAuthError: LocalizedError {
    case missingConsumerCredentials
    case startFailed
    case noCallback
    case badRedirect
    case stateMismatch
    case noAuthorizationCode
    case tokenExchangeFailed(Int)
    case decodeFailed
    case missingCodeVerifier

    var errorDescription: String? {
        switch self {
        case .missingConsumerCredentials:
            return "Add Garmin Consumer Key and Secret in Data sources (Keychain) or Info.plist from the Garmin Connect Developer Program."
        case .startFailed: return "Could not start Garmin sign-in."
        case .noCallback: return "Garmin sign-in did not return a callback URL."
        case .badRedirect: return "Unexpected redirect URL from Garmin."
        case .stateMismatch: return "OAuth state did not match (possible CSRF)."
        case .noAuthorizationCode: return "No authorization code from Garmin."
        case .tokenExchangeFailed(let code): return "Garmin token exchange failed (HTTP \(code))."
        case .decodeFailed: return "Could not decode Garmin token response."
        case .missingCodeVerifier: return "Internal OAuth error (missing PKCE verifier)."
        }
    }
}

private struct GarminTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private extension Data {
    static func randomPKCEVerifierBytes() -> Data {
        var bytes = [UInt8](repeating: 0, count: 48)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess)
        return Data(bytes)
    }

    func base64URLEncodedNoPad() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// OAuth 2.0 **PKCE** for the [Garmin Connect Developer Program](https://developer.garmin.com/gc-developer-program/health-api/) Health API.
@MainActor
enum GarminOAuthService {
    private static let authURL = URL(string: "https://connect.garmin.com/oauth2Confirm")!
    private static let tokenURL = URL(string: "https://diauth.garmin.com/di-oauth2-service/oauth/token")!

    static func signInInteractively() async throws {
        guard let consumerKey = StrideCheckSecrets.garminConsumerKey,
              let consumerSecret = StrideCheckSecrets.garminConsumerSecret else {
            throw GarminOAuthError.missingConsumerCredentials
        }
        let redirect = StrideCheckSecrets.garminRedirectURI
        guard let scheme = URL(string: redirect)?.scheme else { throw GarminOAuthError.badRedirect }

        let verifierData = Data.randomPKCEVerifierBytes()
        let codeVerifier = verifierData.base64URLEncodedNoPad()
        let challengeHash = SHA256.hash(data: Data(codeVerifier.utf8))
        let codeChallenge = Data(challengeHash).base64URLEncodedNoPad()

        GarminOAuthPresenter.shared.pendingCodeVerifier = codeVerifier

        let state = String(UUID().uuidString.prefix(12))
        var comp = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: consumerKey),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "state", value: state)
        ]
        guard let startURL = comp.url else { throw GarminOAuthError.badRedirect }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: startURL, callbackURLScheme: scheme) { url, error in
                GarminOAuthPresenter.shared.pendingSession = nil
                if let error {
                    GarminOAuthPresenter.shared.pendingCodeVerifier = nil
                    cont.resume(throwing: error)
                    return
                }
                guard let url else {
                    GarminOAuthPresenter.shared.pendingCodeVerifier = nil
                    cont.resume(throwing: GarminOAuthError.noCallback)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = GarminOAuthPresenter.shared
            GarminOAuthPresenter.shared.pendingSession = session
            guard session.start() else {
                GarminOAuthPresenter.shared.pendingSession = nil
                GarminOAuthPresenter.shared.pendingCodeVerifier = nil
                cont.resume(throwing: GarminOAuthError.startFailed)
                return
            }
        }

        guard let q = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems else {
            GarminOAuthPresenter.shared.pendingCodeVerifier = nil
            throw GarminOAuthError.badRedirect
        }
        guard q.first(where: { $0.name == "state" })?.value == state else {
            GarminOAuthPresenter.shared.pendingCodeVerifier = nil
            throw GarminOAuthError.stateMismatch
        }
        guard let code = q.first(where: { $0.name == "code" })?.value else {
            GarminOAuthPresenter.shared.pendingCodeVerifier = nil
            throw GarminOAuthError.noAuthorizationCode
        }
        guard let verifier = GarminOAuthPresenter.shared.pendingCodeVerifier else {
            throw GarminOAuthError.missingCodeVerifier
        }
        GarminOAuthPresenter.shared.pendingCodeVerifier = nil

        try await exchangeCode(
            code: code,
            codeVerifier: verifier,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            redirectURI: redirect
        )
    }

    static func disconnect() {
        KeychainCredentialStore.delete(.garminAccessToken)
        KeychainCredentialStore.delete(.garminRefreshToken)
        KeychainCredentialStore.delete(.garminExpiryEpoch)
    }

    static func refreshAccessTokenIfNeeded() async throws {
        guard KeychainCredentialStore.string(for: .garminAccessToken) != nil else { return }
        if let exp = KeychainCredentialStore.garminExpiry(), exp > Date().addingTimeInterval(120) {
            return
        }
        guard let refresh = KeychainCredentialStore.string(for: .garminRefreshToken),
              let consumerKey = StrideCheckSecrets.garminConsumerKey,
              let consumerSecret = StrideCheckSecrets.garminConsumerSecret else {
            return
        }
        try await exchangeRefreshToken(
            refreshToken: refresh,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret
        )
    }

    private static func exchangeCode(
        code: String,
        codeVerifier: String,
        consumerKey: String,
        consumerSecret: String,
        redirectURI: String
    ) async throws {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let pairs: [(String, String)] = [
            ("grant_type", "authorization_code"),
            ("client_id", consumerKey),
            ("client_secret", consumerSecret),
            ("code", code),
            ("code_verifier", codeVerifier),
            ("redirect_uri", redirectURI)
        ]
        req.httpBody = formBody(pairs).data(using: .utf8)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GarminOAuthError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded: GarminTokenResponse
        do {
            decoded = try JSONDecoder().decode(GarminTokenResponse.self, from: data)
        } catch {
            throw GarminOAuthError.decodeFailed
        }
        store(decoded)
    }

    private static func exchangeRefreshToken(
        refreshToken: String,
        consumerKey: String,
        consumerSecret: String
    ) async throws {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let pairs: [(String, String)] = [
            ("grant_type", "refresh_token"),
            ("client_id", consumerKey),
            ("client_secret", consumerSecret),
            ("refresh_token", refreshToken)
        ]
        req.httpBody = formBody(pairs).data(using: .utf8)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GarminOAuthError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded: GarminTokenResponse
        do {
            decoded = try JSONDecoder().decode(GarminTokenResponse.self, from: data)
        } catch {
            throw GarminOAuthError.decodeFailed
        }
        store(decoded)
    }

    private static func formBody(_ pairs: [(String, String)]) -> String {
        pairs.map { key, value in
            let enc = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }
            return "\(enc(key))=\(enc(value))"
        }
        .joined(separator: "&")
    }

    private static func store(_ t: GarminTokenResponse) {
        KeychainCredentialStore.set(t.accessToken, for: .garminAccessToken)
        if let r = t.refreshToken, !r.isEmpty {
            KeychainCredentialStore.set(r, for: .garminRefreshToken)
        }
        if let sec = t.expiresIn {
            KeychainCredentialStore.setGarminExpiry(Date().addingTimeInterval(TimeInterval(sec)))
        }
    }
}

private final class GarminOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GarminOAuthPresenter()

    fileprivate var pendingSession: ASWebAuthenticationSession?
    fileprivate var pendingCodeVerifier: String?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let win = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return win
        }
        if let win = scenes.flatMap(\.windows).first {
            return win
        }
        return ASPresentationAnchor()
    }
}
