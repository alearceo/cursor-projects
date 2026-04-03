import SwiftUI
import UIKit

@main
struct StrideCheckApp: App {
    init() {
        WearableRunIndexPreferences.applyMigrationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}
