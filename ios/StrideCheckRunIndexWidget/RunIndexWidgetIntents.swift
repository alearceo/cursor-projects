import AppIntents
import WidgetKit

/// Opens detail mode at page 0 (Summary).
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

/// Advances to the next detail page (wraps around).
struct RunIndexWidgetNextPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Next widget detail page"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let next = (RunIndexWidgetState.detailPageIndex + 1) % RunIndexWidgetState.detailPageCount
        RunIndexWidgetState.setDetailPageIndex(next)
        WidgetCenter.shared.reloadTimelines(ofKind: "RunIndexNow")
        return .result()
    }
}

/// Returns to the previous detail page (wraps around).
struct RunIndexWidgetPrevPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous widget detail page"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let prev = (RunIndexWidgetState.detailPageIndex + RunIndexWidgetState.detailPageCount - 1) % RunIndexWidgetState.detailPageCount
        RunIndexWidgetState.setDetailPageIndex(prev)
        WidgetCenter.shared.reloadTimelines(ofKind: "RunIndexNow")
        return .result()
    }
}

/// Returns the widget to the main run index face.
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
