import SwiftUI
import WidgetKit

struct RunIndexWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RunIndexEntry

    private static let deepLink = URL(string: "stridecheck://run-index")!

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularContent
            case .accessoryRectangular:
                rectangularContent
            case .accessoryInline:
                inlineContent
            default:
                smallHomeContent
            }
        }
        .widgetURL(Self.deepLink)
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                AccessoryWidgetBackground()
            default:
                ContainerRelativeShape()
                    .fill(.background)
            }
        }
    }

    private var accent: Color {
        switch entry.payload.tier {
        case .good: return Color(red: 0.2, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor: return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    private var smallHomeContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(entry.payload.score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(1)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Run Index")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(entry.payload.tierLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.2))
                        .foregroundStyle(accent)
                        .clipShape(Capsule())
                }
            }
            Text(entry.payload.contextLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.payload.placeName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
    }

    private var circularContent: some View {
        VStack(spacing: 0) {
            Text("\(entry.payload.score)")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text(String(entry.payload.tierLabel.prefix(1)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private var rectangularContent: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(entry.payload.score)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Run Index · \(entry.payload.tierLabel)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.payload.contextLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inlineContent: some View {
        Text("Run \(entry.payload.score) · \(entry.payload.tierLabel)")
    }
}
