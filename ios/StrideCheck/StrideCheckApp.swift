import SwiftUI
import UIKit

@main
struct StrideCheckApp: App {
    init() {
        WearableRunIndexPreferences.applyMigrationIfNeeded()
        WearableRunIndexPreferences.applyGarminToggleMigrationIfNeeded()
        StravaMapOverlayPreferences.applyMigrationIfNeeded()
        StrideCheckAppearance.configureTabBarAccent()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
