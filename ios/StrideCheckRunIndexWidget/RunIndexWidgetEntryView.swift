import SwiftUI
import WidgetKit

struct RunIndexWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
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
                smallWidgetBackground
            }
        }
    }

    /// Soft tier-tinted gradient so the widget isn’t flat white/black; text stays readable.
    private var smallWidgetBackground: some View {
        let base = colorScheme == .dark
            ? Color(red: 0.11, green: 0.12, blue: 0.14)
            : Color(red: 0.97, green: 0.98, blue: 0.99)
        let wash = accent.opacity(colorScheme == .dark ? 0.28 : 0.16)
        return ZStack {
            ContainerRelativeShape()
                .fill(base)
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [wash, wash.opacity(0.35), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var accent: Color {
        switch entry.payload.tier {
        case .good: return Color(red: 0.2, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor: return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    /// Small widget: score on its own row so “Run Index” + tier never compete with the number for width (avoids “Run In…” / “Stro…” truncation).
    private var smallHomeContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(entry.payload.score)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Run Index")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.payload.tierLabel)
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accent.opacity(colorScheme == .dark ? 0.25 : 0.2))
                    .foregroundStyle(accent)
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(entry.payload.contextLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(entry.payload.placeName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 10, leading: 11, bottom: 10, trailing: 11))
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
