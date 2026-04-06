import Foundation

/// Persisted UI mode for the Run Index home-screen widget (App Group).
enum RunIndexWidgetState {
    /// When `true`, the widget shows detail pages (summary → air) instead of the main run index face.
    static let detailModeKey = "runIndexWidget.showDetailPages"

    static var isDetailModeActive: Bool {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return false }
        return defaults.bool(forKey: detailModeKey)
    }

    static func setDetailModeActive(_ active: Bool) {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
        defaults.set(active, forKey: detailModeKey)
    }
}
