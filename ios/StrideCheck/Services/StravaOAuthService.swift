import AuthenticationServices
import Foundation
import UIKit

enum StravaOAuthError: LocalizedError {
    case missingClientCredentials
    case startFailed
    case noCallback
    case badRedirect
    case stateMismatch
    case noAuthorizationCode
    case authorizationDeclined(String?)
    case tokenExchangeFailed(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingClientCredentials:
            return "Add StravaClientId and StravaClientSecret (xcconfig or Info.plist) from Strava API settings."
        case .startFailed: return "Could not start Strava sign-in."
        case .noCallback: return "Strava sign-in did not return a callback URL."
        case .badRedirect: return "Unexpected redirect URL from Strava."
        case .stateMismatch: return "OAuth state did not match (possible CSRF)."
        case .noAuthorizationCode: return "No authorization code from Strava."
        case .authorizationDeclined(let detail):
            if let detail, !detail.isEmpty { return "Strava authorization declined: \(detail)" }
            return "Strava authorization was declined or failed."
        case .tokenExchangeFailed(let code): return "Token exchange failed (HTTP \(code))."
        case .decodeFailed: return "Could not decode Strava token response."
        }
    }
}

private struct StravaTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Int?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
    }
}

/// OAuth 2.0 authorization code flow for [Strava](https://developers.strava.com/docs/authentication/).
@MainActor
enum StravaOAuthService {
    private static let authURL = URL(string: "https://www.strava.com/oauth/authorize")!
    private static let tokenURL = URL(string: "https://www.strava.com/oauth/token")!

    private static let scope = "read,activity:read"

    static func signInInteractively() async throws {
        guard let clientId = StrideCheckSecrets.stravaClientId,
              let clientSecret = StrideCheckSecrets.stravaClientSecret else {
            throw StravaOAuthError.missingClientCredentials
        }
        let redirect = StrideCheckSecrets.stravaRedirectURI
        guard let scheme = URL(string: redirect)?.scheme else { throw StravaOAuthError.badRedirect }

        let state = String(UUID().uuidString.prefix(12))
        var comp = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state)
        ]
        guard let startURL = comp.url else { throw StravaOAuthError.badRedirect }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: startURL, callbackURLScheme: scheme) { url, error in
                StravaOAuthPresenter.shared.pendingSession = nil
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let url else {
                    cont.resume(throwing: StravaOAuthError.noCallback)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = StravaOAuthPresenter.shared
            StravaOAuthPresenter.shared.pendingSession = session
            guard session.start() else {
                StravaOAuthPresenter.shared.pendingSession = nil
                cont.resume(throwing: StravaOAuthError.startFailed)
                return
            }
        }

        guard let q = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems else {
            throw StravaOAuthError.badRedirect
        }
        if q.contains(where: { $0.name == "error" }) {
            let encodedDesc = q.first { $0.name == "error_description" }?.value
            let spaced = encodedDesc?.replacingOccurrences(of: "+", with: " ")
            let desc = spaced.flatMap { $0.removingPercentEncoding ?? $0 }
            throw StravaOAuthError.authorizationDeclined(desc)
        }
        guard q.first(where: { $0.name == "state" })?.value == state else { throw StravaOAuthError.stateMismatch }
        guard let code = q.first(where: { $0.name == "code" })?.value else { throw StravaOAuthError.noAuthorizationCode }

        try await exchangeCode(
            code: code,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectURI: redirect
        )
    }

    static func disconnect() {
        KeychainCredentialStore.delete(.stravaAccessToken)
        KeychainCredentialStore.delete(.stravaRefreshToken)
        KeychainCredentialStore.delete(.stravaExpiryEpoch)
    }

    static func refreshAccessTokenIfNeeded() async throws {
        guard KeychainCredentialStore.string(for: .stravaAccessToken) != nil else { return }
        if let exp = KeychainCredentialStore.stravaExpiry(), exp > Date().addingTimeInterval(120) {
            return
        }
        guard let refreshToken = KeychainCredentialStore.string(for: .stravaRefreshToken),
              let clientId = StrideCheckSecrets.stravaClientId,
              let clientSecret = StrideCheckSecrets.stravaClientSecret else {
            return
        }
        try await exchangeRefreshToken(refreshToken: refreshToken, clientId: clientId, clientSecret: clientSecret)
    }

    private static func exchangeCode(code: String, clientId: String, clientSecret: String, redirectURI: String) async throws {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let pairs: [(String, String)] = [
            ("client_id", clientId),
            ("client_secret", clientSecret),
            ("code", code),
            ("grant_type", "authorization_code"),
            ("redirect_uri", redirectURI)
        ]
        req.httpBody = formBody(pairs).data(using: .utf8)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StravaOAuthError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded: StravaTokenResponse
        do {
            decoded = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        } catch {
            throw StravaOAuthError.decodeFailed
        }
        store(decoded)
    }

    private static func exchangeRefreshToken(refreshToken: String, clientId: String, clientSecret: String) async throws {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let pairs: [(String, String)] = [
            ("client_id", clientId),
            ("client_secret", clientSecret),
            ("refresh_token", refreshToken),
            ("grant_type", "refresh_token")
        ]
        req.httpBody = formBody(pairs).data(using: .utf8)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StravaOAuthError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded: StravaTokenResponse
        do {
            decoded = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        } catch {
            throw StravaOAuthError.decodeFailed
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

    private static func store(_ t: StravaTokenResponse) {
        KeychainCredentialStore.set(t.accessToken, for: .stravaAccessToken)
        if let r = t.refreshToken {
            KeychainCredentialStore.set(r, for: .stravaRefreshToken)
        }
        if let epoch = t.expiresAt {
            KeychainCredentialStore.setStravaExpiry(Date(timeIntervalSince1970: TimeInterval(epoch)))
        } else if let sec = t.expiresIn {
            KeychainCredentialStore.setStravaExpiry(Date().addingTimeInterval(TimeInterval(sec)))
        }
    }
}

private final class StravaOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = StravaOAuthPresenter()

    fileprivate var pendingSession: ASWebAuthenticationSession?

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
