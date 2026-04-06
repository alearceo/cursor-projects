import SwiftUI
import WidgetKit

struct RunIndexEntry: TimelineEntry {
    let date: Date
    let payload: RunIndexWidgetPayload
    /// When `true`, show swipeable detail pages (2–5); when `false`, show the main run index face only.
    let showDetailPages: Bool
}

struct RunIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunIndexEntry {
        RunIndexEntry(date: Date(), payload: .placeholder, showDetailPages: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (RunIndexEntry) -> Void) {
        let payload = RunIndexWidgetPayload.load() ?? .placeholder
        let showDetail = RunIndexWidgetState.isDetailModeActive
        completion(RunIndexEntry(date: Date(), payload: payload, showDetailPages: showDetail))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunIndexEntry>) -> Void) {
        let payload = RunIndexWidgetPayload.load() ?? .placeholder
        let showDetail = RunIndexWidgetState.isDetailModeActive
        let entry = RunIndexEntry(date: Date(), payload: payload, showDetailPages: showDetail)
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
        .description("Run index on the first page; tap the info control for detail pages. Tap elsewhere to open the app.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct StrideCheckRunIndexWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunIndexNowWidget()
    }
}
