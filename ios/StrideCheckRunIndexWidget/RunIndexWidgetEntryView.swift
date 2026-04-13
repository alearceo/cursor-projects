import SwiftUI
import WidgetKit

struct RunIndexWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    var entry: RunIndexEntry

    private static let deepLink = URL(string: "stridecheck://run-index")!

    // Route Awareness uses a fixed purple accent; Run Index uses a tier-responsive color.
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
            case .systemMedium:
                mediumHomeContent
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

    /// Home-screen widget base matches in-app `Color.strideCanvas` (telemetry).
    private var smallWidgetBackground: some View {
        let base = colorScheme == .dark
            ? Color(red: 0.047, green: 0.047, blue: 0.059)
            : Color(red: 0.949, green: 0.941, blue: 0.922)
        let wash = runIndexAccent.opacity(colorScheme == .dark ? 0.12 : 0.08)
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

    private var runIndexAccent: Color { tierAccent(entry.payload.tier) }

    private func tierAccent(_ tier: RunIndexTierKind) -> Color {
        switch tier {
        case .good:     return Color(red: 0.2,  green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor:     return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    // MARK: - Small home face

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
                .accessibilityLabel("Location: \(entry.payload.placeName)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(smallAccessibilityLabel)
    }

    private var smallAccessibilityLabel: String {
        "Run Index \(entry.payload.score), \(entry.payload.tierLabel). " +
        "Route \(entry.payload.awarenessScore), \(entry.payload.awarenessTierLabel). " +
        entry.payload.placeName
    }

    // MARK: - Medium home face

    private var mediumHomeContent: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: Run Index hero (takes ~58% width)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(runIndexAccent)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(entry.payload.score)")
                            .font(.system(size: 38, weight: .heavy, design: .monospaced))
                            .foregroundStyle(runIndexAccent)
                            .lineLimit(1)
                            .accessibilityLabel("Run Index score \(entry.payload.score)")

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
                }

                if !entry.payload.contextLine.isEmpty {
                    Text(entry.payload.contextLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text(entry.payload.placeName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel("Location: \(entry.payload.placeName)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Vertical divider
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)

            // Right: Route Awareness secondary column (~36% width)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(routeAccent)
                        .frame(width: 3, height: 14)

                    Text("\(entry.payload.awarenessScore)")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundStyle(routeAccent)
                        .lineLimit(1)
                        .accessibilityLabel("Route score \(entry.payload.awarenessScore)")
                }
                Text("Route awareness")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                tierPill(text: entry.payload.awarenessTierLabel, color: routeAccent)
                Spacer(minLength: 0)
            }
            .frame(width: 110, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumAccessibilityLabel)
    }

    private var mediumAccessibilityLabel: String {
        "Run Index \(entry.payload.score), \(entry.payload.tierLabel). " +
        "\(entry.payload.contextLine.isEmpty ? "" : entry.payload.contextLine + ". ")" +
        "Route awareness \(entry.payload.awarenessScore), \(entry.payload.awarenessTierLabel). " +
        entry.payload.placeName
    }

    // MARK: - Shared sub-views

    /// Primary hero block for small widget: tall bar, large score, label + pill on second line.
    private var runIndexHero: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(runIndexAccent)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(entry.payload.score)")
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
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

    /// Compact Route Awareness row for small widget.
    private var routeStrip: some View {
        HStack(alignment: .center, spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(routeAccent)
                .frame(width: 3, height: 14)
                .accessibilityHidden(true)

            Text("\(entry.payload.awarenessScore)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
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
            .accessibilityHidden(true)
    }

    // MARK: - Accessory / lock-screen variants

    private var circularContent: some View {
        VStack(spacing: 0) {
            Text("\(entry.payload.score)")
                .font(.system(.title2, design: .monospaced).weight(.heavy))
            Text(String(entry.payload.tierLabel.prefix(1)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Run Index \(entry.payload.score), \(entry.payload.tierLabel)")
    }

    private var rectangularContent: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(entry.payload.score)")
                .font(.system(.title, design: .monospaced).weight(.heavy))
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
        .accessibilityLabel("Run Index \(entry.payload.score), \(entry.payload.tierLabel). \(entry.payload.contextLine)")
    }

    private var inlineContent: some View {
        Text("Run \(entry.payload.score) · \(entry.payload.tierLabel)")
            .accessibilityLabel("Run Index \(entry.payload.score), \(entry.payload.tierLabel)")
    }
}
