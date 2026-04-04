import Foundation

/// User opt-in for third-party APIs affecting the run index. Apple Health is always read when authorized (baseline).
enum WearableRunIndexPreferences {
    private static let migratedKey = "stridecheck.wearableRunIndexPrefsMigrated"
    private static let garminToggleMigratedKey = "stridecheck.garminRunIndexToggleMigrated"
    private static let includeWhoopKey = "stridecheck.includeWhoopInRunIndex"
    private static let includeOuraKey = "stridecheck.includeOuraInRunIndex"
    private static let includeGarminKey = "stridecheck.includeGarminInRunIndex"

    /// One-time migration: if credentials already exist, default toggles **on** so behavior matches pre–data-sources builds.
    static func applyMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        var includeWhoop = false
        if KeychainCredentialStore.string(for: .whoopAccessToken) != nil {
            includeWhoop = true
        }

        var includeOura = false
        if KeychainCredentialStore.string(for: .ouraPersonalAccessToken) != nil {
            includeOura = true
        } else if let plist = Bundle.main.object(forInfoDictionaryKey: "OuraPersonalAccessToken") as? String,
                  !plist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !plist.hasPrefix("$(") {
            includeOura = true
        }

        UserDefaults.standard.set(includeWhoop, forKey: includeWhoopKey)
        UserDefaults.standard.set(includeOura, forKey: includeOuraKey)
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    /// One-time: if a Garmin token already exists, turn **Use for run index** on (separate from the original Whoop/Oura migration).
    static func applyGarminToggleMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: garminToggleMigratedKey) else { return }
        if KeychainCredentialStore.string(for: .garminAccessToken) != nil {
            UserDefaults.standard.set(true, forKey: includeGarminKey)
        }
        UserDefaults.standard.set(true, forKey: garminToggleMigratedKey)
    }

    static var includeWhoopInRunIndex: Bool {
        get { UserDefaults.standard.bool(forKey: includeWhoopKey) }
        set { UserDefaults.standard.set(newValue, forKey: includeWhoopKey) }
    }

    static var includeOuraInRunIndex: Bool {
        get { UserDefaults.standard.bool(forKey: includeOuraKey) }
        set { UserDefaults.standard.set(newValue, forKey: includeOuraKey) }
    }

    static var includeGarminInRunIndex: Bool {
        get { UserDefaults.standard.bool(forKey: includeGarminKey) }
        set { UserDefaults.standard.set(newValue, forKey: includeGarminKey) }
    }
}
