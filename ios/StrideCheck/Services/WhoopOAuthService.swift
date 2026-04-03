import AuthenticationServices
import Foundation
import UIKit

enum WhoopError: LocalizedError {
    case missingClientCredentials
    case startFailed
    case noCallback
    case badRedirect
    case stateMismatch
    case noAuthorizationCode
    case tokenExchangeFailed(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingClientCredentials:
            return "Add WhoopClientId and WhoopClientSecret (xcconfig or Info.plist) from developer.whoop.com."
        case .startFailed: return "Could not start Whoop sign-in."
        case .noCallback: return "Whoop sign-in did not return a callback URL."
        case .badRedirect: return "Unexpected redirect URL from Whoop."
        case .stateMismatch: return "OAuth state did not match (possible CSRF)."
        case .noAuthorizationCode: return "No authorization code from Whoop."
        case .tokenExchangeFailed(let code): return "Token exchange failed (HTTP \(code))."
        case .decodeFailed: return "Could not decode Whoop token response."
        }
    }
}

private struct WhoopTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// OAuth 2.0 authorization code flow for [Whoop](https://developer.whoop.com/docs/developing/oauth).
@MainActor
enum WhoopOAuthService {
    private static let authURL = URL(string: "https://api.prod.whoop.com/oauth/oauth2/auth")!
    private static let tokenURL = URL(string: "https://api.prod.whoop.com/oauth/oauth2/token")!

    /// Present system browser sheet; exchanges code for tokens and stores them in Keychain.
    static func signInInteractively() async throws {
        guard let clientId = StrideCheckSecrets.whoopClientId,
              let clientSecret = StrideCheckSecrets.whoopClientSecret else {
            throw WhoopError.missingClientCredentials
        }
        let redirect = StrideCheckSecrets.whoopRedirectURI
        guard let scheme = URL(string: redirect)?.scheme else { throw WhoopError.badRedirect }

        let state = String(UUID().uuidString.prefix(12))
        var comp = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "scope", value: "read:recovery read:cycles read:sleep offline"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let startURL = comp.url else { throw WhoopError.badRedirect }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: startURL, callbackURLScheme: scheme) { url, error in
                WhoopOAuthPresenter.shared.pendingSession = nil
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let url else {
                    cont.resume(throwing: WhoopError.noCallback)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = WhoopOAuthPresenter.shared
            WhoopOAuthPresenter.shared.pendingSession = session
            guard session.start() else {
                WhoopOAuthPresenter.shared.pendingSession = nil
                cont.resume(throwing: WhoopError.startFailed)
                return
            }
        }

        guard let q = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems else {
            throw WhoopError.badRedirect
        }
        guard q.first(where: { $0.name == "state" })?.value == state else { throw WhoopError.stateMismatch }
        guard let code = q.first(where: { $0.name == "code" })?.value else { throw WhoopError.noAuthorizationCode }

        try await exchangeCode(
            code: code,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectURI: redirect
        )
    }

    static func disconnect() {
        KeychainCredentialStore.delete(.whoopAccessToken)
        KeychainCredentialStore.delete(.whoopRefreshToken)
        KeychainCredentialStore.delete(.whoopExpiryEpoch)
    }

    /// Refreshes the access token when missing or near expiry (requires `offline` scope during sign-in).
    static func refreshAccessTokenIfNeeded() async throws {
        guard KeychainCredentialStore.string(for: .whoopAccessToken) != nil else { return }
        if let exp = KeychainCredentialStore.whoopExpiry(), exp > Date().addingTimeInterval(120) {
            return
        }
        guard let refreshToken = KeychainCredentialStore.string(for: .whoopRefreshToken),
              let clientId = StrideCheckSecrets.whoopClientId,
              let clientSecret = StrideCheckSecrets.whoopClientSecret else {
            return
        }
        try await exchangeRefreshToken(refreshToken: refreshToken, clientId: clientId, clientSecret: clientSecret)
    }

    private static func exchangeCode(code: String, clientId: String, clientSecret: String, redirectURI: String) async throws {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WhoopError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(WhoopTokenResponse.self, from: data)
        store(decoded)
    }

    private static func exchangeRefreshToken(refreshToken: String, clientId: String, clientSecret: String) async throws {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret,
            "scope": "offline"
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WhoopError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(WhoopTokenResponse.self, from: data)
        store(decoded)
    }

    private static func store(_ t: WhoopTokenResponse) {
        KeychainCredentialStore.set(t.accessToken, for: .whoopAccessToken)
        if let r = t.refreshToken {
            KeychainCredentialStore.set(r, for: .whoopRefreshToken)
        }
        let exp = Date().addingTimeInterval(TimeInterval(t.expiresIn))
        KeychainCredentialStore.setWhoopExpiry(exp)
    }
}

private final class WhoopOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WhoopOAuthPresenter()

    /// Strong reference until Whoop redirects back (required by `ASWebAuthenticationSession`).
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
