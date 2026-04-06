import SwiftUI
import WidgetKit

struct RunIndexEntry: TimelineEntry {
    let date: Date
    let payload: RunIndexWidgetPayload
    /// `nil` = main run-index face; `0–3` = detail pages (summary / wearables / right-now / air).
    let detailPageIndex: Int?
}

struct RunIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunIndexEntry {
        RunIndexEntry(date: Date(), payload: .placeholder, detailPageIndex: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RunIndexEntry) -> Void) {
        let payload = RunIndexWidgetPayload.load() ?? .placeholder
        let index = RunIndexWidgetState.isDetailModeActive ? RunIndexWidgetState.detailPageIndex : nil
        completion(RunIndexEntry(date: Date(), payload: payload, detailPageIndex: index))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunIndexEntry>) -> Void) {
        let payload = RunIndexWidgetPayload.load() ?? .placeholder
        let index = RunIndexWidgetState.isDetailModeActive ? RunIndexWidgetState.detailPageIndex : nil
        let entry = RunIndexEntry(date: Date(), payload: payload, detailPageIndex: index)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RunIndexNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RunIndexNow", provider: RunIndexProvider()) { entry in
            RunIndexWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Run Index")
        .description("Run index face; tap info for summary, wearables, and conditions. Tap elsewhere to open the app.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct StrideCheckRunIndexWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunIndexNowWidget()
    }
}
