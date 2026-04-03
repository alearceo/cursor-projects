import Foundation

/// User opt-in for drawing Strava polylines on the Route map. OAuth tokens are separate from this flag.
enum StravaMapOverlayPreferences {
    private static let migratedKey = "stridecheck.stravaMapOverlayMigrated"
    static let showRoutesOnMapKey = "stridecheck.showStravaRoutesOnMap"

    /// One-time: if Strava was already linked, turn the map overlay on so behavior matches older builds.
    static func applyMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        if KeychainCredentialStore.string(for: .stravaAccessToken) != nil {
            UserDefaults.standard.set(true, forKey: showRoutesOnMapKey)
        }
        UserDefaults.standard.set(true, forKey: migratedKey)
    }
}
