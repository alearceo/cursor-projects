import SwiftUI
import WidgetKit

struct RunIndexWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    var entry: RunIndexEntry

    private static let deepLink = URL(string: "stridecheck://run-index")!

    // Route Awareness always uses this fixed purple regardless of its tier score.
    private let routeAccent = Color(red: 0.60, green: 0.38, blue: 0.90)

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

    // MARK: - Background

    private var smallWidgetBackground: some View {
        let base = colorScheme == .dark
            ? Color(red: 0.11, green: 0.12, blue: 0.14)
            : Color(red: 0.97, green: 0.98, blue: 0.99)
        let wash = runIndexAccent.opacity(colorScheme == .dark ? 0.18 : 0.10)
        return ZStack {
            ContainerRelativeShape().fill(base)
            ContainerRelativeShape().fill(
                LinearGradient(
                    colors: [wash, wash.opacity(0.3), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    // MARK: - Tier accent (Run Index only)

    private var runIndexAccent: Color {
        tierAccent(entry.payload.tier)
    }

    private func tierAccent(_ tier: RunIndexTierKind) -> Color {
        switch tier {
        case .good:     return Color(red: 0.2, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor:     return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    // MARK: - Home face

    private var smallHomeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            runIndexHero

            Spacer(minLength: 6)

            routeStrip

            Spacer(minLength: 5)

            Text(entry.payload.placeName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
    }

    /// Primary hero block: tall bar, large score, then label + pill on the second line.
    private var runIndexHero: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(runIndexAccent)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(entry.payload.score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(runIndexAccent)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 6) {
                    Text("Run Index")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                    tierPill(text: entry.payload.tierLabel, color: runIndexAccent)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Secondary compact strip: bar · score · "Route" label · pill, all left-aligned.
    private var routeStrip: some View {
        HStack(alignment: .center, spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(routeAccent)
                .frame(width: 3, height: 14)

            Text("\(entry.payload.awarenessScore)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(routeAccent)
                .lineLimit(1)
                .layoutPriority(2)

            Text("Route")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(1)

            tierPill(text: entry.payload.awarenessTierLabel, color: routeAccent)

            Spacer(minLength: 0)
        }
    }

    private func tierPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(color.opacity(colorScheme == .dark ? 0.28 : 0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    // MARK: - Accessory / lock-screen variants

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
                .foregroundStyle(runIndexAccent)
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
