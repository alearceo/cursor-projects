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
        trimmed(Bundle.main.object(forInfoDictionaryKey: "WhoopClientId") as? String)
    }

    static var whoopClientSecret: String? {
        trimmed(Bundle.main.object(forInfoDictionaryKey: "WhoopClientSecret") as? String)
    }

    /// Must match Whoop Developer Dashboard and `CFBundleURLTypes` (e.g. `stridecheck://whoop-oauth`).
    static var whoopRedirectURI: String {
        (Bundle.main.object(forInfoDictionaryKey: "WhoopRedirectURI") as? String)
            .flatMap(trimmed) ?? "stridecheck://whoop-oauth"
    }

    static var stravaClientId: String? {
        trimmed(Bundle.main.object(forInfoDictionaryKey: "StravaClientId") as? String)
    }

    static var stravaClientSecret: String? {
        trimmed(Bundle.main.object(forInfoDictionaryKey: "StravaClientSecret") as? String)
    }

    /// Must match Strava application settings and `CFBundleURLTypes` (e.g. `stridecheck://strava-oauth`).
    static var stravaRedirectURI: String {
        (Bundle.main.object(forInfoDictionaryKey: "StravaRedirectURI") as? String)
            .flatMap(trimmed) ?? "stridecheck://strava-oauth"
    }

    private static func trimmed(_ s: String?) -> String? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }
}
