import Foundation
import Security

/// Small Keychain wrapper for OAuth tokens and optional third-party API secrets (never commit real values in plist).
enum KeychainCredentialStore {
    private static let service = "com.alearceo.StrideCheck.credentials"

    enum Key: String {
        case whoopAccessToken = "whoop.access"
        case whoopRefreshToken = "whoop.refresh"
        case whoopExpiryEpoch = "whoop.expiry"
        case ouraPersonalAccessToken = "oura.pat"
        case crimeometerAPIKey = "crimeometer.key"
        case stravaAccessToken = "strava.access"
        case stravaRefreshToken = "strava.refresh"
        case stravaExpiryEpoch = "strava.expiry"
    }

    static func set(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func string(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func whoopExpiry() -> Date? {
        guard let s = string(for: .whoopExpiryEpoch), let t = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    static func setWhoopExpiry(_ date: Date?) {
        guard let date else {
            delete(.whoopExpiryEpoch)
            return
        }
        set(String(date.timeIntervalSince1970), for: .whoopExpiryEpoch)
    }

    static func stravaExpiry() -> Date? {
        guard let s = string(for: .stravaExpiryEpoch), let t = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    static func setStravaExpiry(_ date: Date?) {
        guard let date else {
            delete(.stravaExpiryEpoch)
            return
        }
        set(String(date.timeIntervalSince1970), for: .stravaExpiryEpoch)
    }
}
