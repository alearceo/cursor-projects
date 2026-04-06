import AppIntents
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
        // Only attach widgetURL on the main face; detail mode uses Button(intent:) exclusively.
        .strideCheckWidgetURL(entry: entry, family: family, url: Self.deepLink)
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                AccessoryWidgetBackground()
            default:
                smallWidgetBackground
            }
        }
    }

    // MARK: - Background / accent

    private var smallWidgetBackground: some View {
        let base = colorScheme == .dark
            ? Color(red: 0.11, green: 0.12, blue: 0.14)
            : Color(red: 0.97, green: 0.98, blue: 0.99)
        let wash = accent.opacity(colorScheme == .dark ? 0.28 : 0.16)
        return ZStack {
            ContainerRelativeShape().fill(base)
            ContainerRelativeShape().fill(
                LinearGradient(
                    colors: [wash, wash.opacity(0.35), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var accent: Color {
        tierAccent(entry.payload.tier)
    }

    private var awarenessTierKind: RunIndexTierKind {
        RunIndexTierKind(score: entry.payload.awarenessScore)
    }

    private var awarenessAccent: Color {
        tierAccent(awarenessTierKind)
    }

    private func tierAccent(_ tier: RunIndexTierKind) -> Color {
        switch tier {
        case .good:     return Color(red: 0.2, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor:     return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    // MARK: - Home content dispatcher

    private var smallHomeContent: some View {
        Group {
            if let page = entry.detailPageIndex {
                detailContent(page: page)
            } else {
                homeFaceContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 3, leading: 4, bottom: 3, trailing: 3))
    }

    // MARK: - Main face (page 1)

    /// Option A: dual columns — Run Index | Route awareness — with info top-trailing.
    private var homeFaceContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    homeRunIndexColumn
                    homeRouteColumn
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(intent: OpenRunIndexWidgetDetailIntent()) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -3)
                .accessibilityLabel("Show details")
            }
            Spacer(minLength: 4)
            Text(entry.payload.placeName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var homeRunIndexColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.payload.score)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("Run Index")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(entry.payload.tierLabel)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(accent.opacity(colorScheme == .dark ? 0.25 : 0.2))
                .foregroundStyle(accent)
                .clipShape(Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var homeRouteColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.payload.awarenessScore)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(awarenessAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("Route")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(entry.payload.awarenessTierLabel)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(awarenessAccent.opacity(colorScheme == .dark ? 0.25 : 0.2))
                .foregroundStyle(awarenessAccent)
                .clipShape(Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Detail mode (pages 2–5)
    // Tap anywhere on the page advances to the next page (ZStack: full-area button behind X close).

    private func detailContent(page: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            // Full-area tap advances to next page
            Button(intent: RunIndexWidgetNextPageIntent()) {
                VStack(alignment: .leading, spacing: 0) {
                    // Section title — leave gap on the right for the X
                    detailPageTitle(for: page)
                        .padding(.trailing, 14)
                        .padding(.bottom, 5)

                    detailPageBody(for: page)
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    Spacer(minLength: 0)

                    // Page dots (no chevrons)
                    HStack(spacing: 5) {
                        ForEach(0..<RunIndexWidgetState.detailPageCount, id: \.self) { i in
                            Circle()
                                .fill(i == page ? Color.primary.opacity(0.75) : Color.secondary.opacity(0.3))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // X close — flush to the top-trailing corner
            Button(intent: CloseRunIndexWidgetDetailIntent()) {
                Text("✕")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -3)
            .accessibilityLabel("Back to run index")
        }
    }

    @ViewBuilder
    private func detailPageTitle(for page: Int) -> some View {
        let titles = ["Summary", "Wearables & readiness", "Right Now", "Air & Comfort"]
        Text(titles[min(page, titles.count - 1)])
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func detailPageBody(for page: Int) -> some View {
        switch page {
        case 0: summaryBody
        case 1: rowsBody(rows: entry.payload.wearableRows)
        case 2: rowsBody(rows: entry.payload.currentRows)
        case 3: rowsBody(rows: entry.payload.airRows)
        default: summaryBody
        }
    }

    private var summaryBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entry.payload.contextLine.isEmpty {
                Text(entry.payload.contextLine)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            }
            if !entry.payload.verdict.isEmpty {
                Text(entry.payload.verdict)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
            }
            ForEach(Array(entry.payload.bullets.prefix(4).enumerated()), id: \.offset) { _, bullet in
                Text("• \(bullet)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func rowsBody(rows: [WidgetRowPair]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if rows.isEmpty {
                Text("Open StrideCheck to refresh.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.prefix(5).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.key)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 4)
                        Text(row.value)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
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

// MARK: - Conditional widgetURL helper

private extension View {
    @ViewBuilder
    func strideCheckWidgetURL(entry: RunIndexEntry, family: WidgetFamily, url: URL) -> some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            self.widgetURL(url)
        default:
            if entry.detailPageIndex == nil {
                self.widgetURL(url)
            } else {
                self
            }
        }
    }
}
