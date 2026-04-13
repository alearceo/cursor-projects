import Foundation

/// Resolves API secrets: **Keychain first** (runtime / user flows), then **Info.plist** (build-time `$(VAR)` substitution from xcconfig).
enum StrideCheckSecrets {
    static var ouraPersonalAccessToken: String? {
        trimmed(KeychainCredentialStore.string(for: .ouraPersonalAccessToken))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "OuraPersonalAccessToken") as? String)
    }

    static var crimeometerAPIKey: String? {
        trimmed(KeychainCredentialStore.string(for: .crimeometerAPIKey))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "CrimeometerAPIKey") as? String)
    }

    static var whoopClientId: String? {
        trimmed(KeychainCredentialStore.string(for: .whoopOAuthClientId))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "WhoopClientId") as? String)
    }

    static var whoopClientSecret: String? {
        trimmed(KeychainCredentialStore.string(for: .whoopOAuthClientSecret))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "WhoopClientSecret") as? String)
    }

    /// Must match Whoop Developer Dashboard and `CFBundleURLTypes` (e.g. `stridecheck://whoop-oauth`).
    static var whoopRedirectURI: String {
        (Bundle.main.object(forInfoDictionaryKey: "WhoopRedirectURI") as? String)
            .flatMap(trimmed) ?? "stridecheck://whoop-oauth"
    }

    static var stravaClientId: String? {
        trimmed(KeychainCredentialStore.string(for: .stravaOAuthClientId))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "StravaClientId") as? String)
    }

    static var stravaClientSecret: String? {
        trimmed(KeychainCredentialStore.string(for: .stravaOAuthClientSecret))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "StravaClientSecret") as? String)
    }

    /// Must match Strava **My API Application**: use **Authorization Callback Domain** `localhost` and this full URI as the OAuth `redirect_uri`.
    /// Custom scheme + `localhost` host satisfies Strava’s domain rules; `ASWebAuthenticationSession` still uses callback scheme `stridecheck` only.
    static var stravaRedirectURI: String {
        (Bundle.main.object(forInfoDictionaryKey: "StravaRedirectURI") as? String)
            .flatMap(trimmed) ?? "stridecheck://localhost/strava-oauth"
    }

    static var garminConsumerKey: String? {
        trimmed(KeychainCredentialStore.string(for: .garminOAuthConsumerKey))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "GarminConsumerKey") as? String)
    }

    static var garminConsumerSecret: String? {
        trimmed(KeychainCredentialStore.string(for: .garminOAuthConsumerSecret))
            ?? trimmed(Bundle.main.object(forInfoDictionaryKey: "GarminConsumerSecret") as? String)
    }

    /// Must match the Garmin Connect Developer app (scheme `stridecheck`, path `garmin-oauth`).
    static var garminRedirectURI: String {
        (Bundle.main.object(forInfoDictionaryKey: "GarminRedirectURI") as? String)
            .flatMap(trimmed) ?? "stridecheck://garmin-oauth"
    }

    private static func trimmed(_ s: String?) -> String? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }
}
