import AppIntents
import WidgetKit

/// Switches the widget to the swipeable detail section (pages 2–5).
struct OpenRunIndexWidgetDetailIntent: AppIntent {
    static var title: LocalizedStringResource = "Show widget details"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        RunIndexWidgetState.setDetailModeActive(true)
        WidgetCenter.shared.reloadTimelines(ofKind: "RunIndexNow")
        return .result()
    }
}

/// Returns the widget to the main run index face (page 1).
struct CloseRunIndexWidgetDetailIntent: AppIntent {
    static var title: LocalizedStringResource = "Back to run index"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        RunIndexWidgetState.setDetailModeActive(false)
        WidgetCenter.shared.reloadTimelines(ofKind: "RunIndexNow")
        return .result()
    }
}
