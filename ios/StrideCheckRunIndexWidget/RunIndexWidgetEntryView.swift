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
            metricRow(
                barColor: runIndexAccent,
                score: entry.payload.score,
                label: "Run Index",
                tierLabel: entry.payload.tierLabel
            )
            .padding(.bottom, 8)

            metricRow(
                barColor: routeAccent,
                score: entry.payload.awarenessScore,
                label: "Route",
                tierLabel: entry.payload.awarenessTierLabel
            )

            Spacer(minLength: 6)

            Text(entry.payload.placeName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }

    private func metricRow(
        barColor: Color,
        score: Int,
        label: String,
        tierLabel: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3, height: 34)

            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(barColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 42, alignment: .leading)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(tierLabel)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(barColor.opacity(colorScheme == .dark ? 0.28 : 0.16))
                .foregroundStyle(barColor)
                .clipShape(Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
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
