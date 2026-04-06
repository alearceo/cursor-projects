import SwiftUI
import WidgetKit

struct RunIndexEntry: TimelineEntry {
    let date: Date
    let payload: RunIndexWidgetPayload
}

struct RunIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunIndexEntry {
        RunIndexEntry(date: Date(), payload: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RunIndexEntry) -> Void) {
        let payload = RunIndexWidgetPayload.load() ?? .placeholder
        completion(RunIndexEntry(date: Date(), payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunIndexEntry>) -> Void) {
        let payload = RunIndexWidgetPayload.load() ?? .placeholder
        let entry = RunIndexEntry(date: Date(), payload: payload)
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
        .description("Your run index and route awareness at a glance. Tap to open StrideCheck.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct StrideCheckRunIndexWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunIndexNowWidget()
    }
}
