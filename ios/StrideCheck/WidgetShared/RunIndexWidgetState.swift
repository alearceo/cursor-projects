import Foundation

/// Persisted UI mode for the Run Index home-screen widget (App Group).
enum RunIndexWidgetState {
    private static let detailModeKey = "runIndexWidget.showDetailPages"
    private static let detailPageKey  = "runIndexWidget.detailPageIndex"

    static let detailPageCount = 4  // summary, wearables, right-now, air

    static var isDetailModeActive: Bool {
        guard let d = UserDefaults(suiteName: AppGroup.suiteName) else { return false }
        return d.bool(forKey: detailModeKey)
    }

    static func setDetailModeActive(_ active: Bool) {
        guard let d = UserDefaults(suiteName: AppGroup.suiteName) else { return }
        d.set(active, forKey: detailModeKey)
        if !active { d.set(0, forKey: detailPageKey) }
    }

    /// 0-based index into the four detail pages.
    static var detailPageIndex: Int {
        guard let d = UserDefaults(suiteName: AppGroup.suiteName) else { return 0 }
        return d.integer(forKey: detailPageKey)
    }

    static func setDetailPageIndex(_ index: Int) {
        guard let d = UserDefaults(suiteName: AppGroup.suiteName) else { return }
        d.set(max(0, min(index, detailPageCount - 1)), forKey: detailPageKey)
    }
}
