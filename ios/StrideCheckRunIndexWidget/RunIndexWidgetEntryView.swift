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
        /// Omit the deep link while the home widget is in detail mode so `widgetURL` does not fight
        /// interactive `Button(intent:)` / layout (avoids the yellow “forbidden” render failure).
        .strideCheckWidgetDeepLink(entry: entry, family: family, url: Self.deepLink)
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

    /// Page 1 only until the user taps the info control; then Carrot-style horizontal pages (2–5) with system page dots.
    private var smallHomeContent: some View {
        Group {
            if entry.showDetailPages {
                detailPagesContent
            } else {
                homeFaceContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(EdgeInsets(top: 5, leading: 6, bottom: 2, trailing: 4))
    }

    private var homeFaceContent: some View {
        ZStack(alignment: .topTrailing) {
            widgetMainPage
                .padding(.trailing, 20)

            Button(intent: OpenRunIndexWidgetDetailIntent()) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show details")
        }
    }

    /// Pages 2–5: horizontal paging like Carrot (system `TabView` page style + dots). Close stays top-trailing.
    /// Avoid `ScrollView` / `indexViewStyle(.page)` here — those contributed to WidgetKit’s yellow failure overlay.
    private var detailPagesContent: some View {
        TabView {
            detailSummaryPage
            detailWearablesPage
            detailRightNowPage
            detailAirPage
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(intent: CloseRunIndexWidgetDetailIntent()) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to run index")
            .padding(.trailing, 2)
            .padding(.top, 0)
        }
    }

    /// Page 2 — Summary
    private var detailSummaryPage: some View {
        widgetSummaryPage
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.trailing, 22)
    }

    /// Page 3 — Wearables
    private var detailWearablesPage: some View {
        widgetRowsSection(
            title: "Wearables & readiness",
            rows: Array(entry.payload.wearableRows.prefix(detailRowLimit))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.trailing, 22)
    }

    /// Page 4 — Right now
    private var detailRightNowPage: some View {
        widgetRowsSection(
            title: "Right Now",
            rows: Array(entry.payload.currentRows.prefix(detailRowLimit))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.trailing, 22)
    }

    /// Page 5 — Air
    private var detailAirPage: some View {
        widgetRowsSection(
            title: "Air & Comfort",
            rows: Array(entry.payload.airRows.prefix(detailRowLimit))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.trailing, 22)
    }

    private var detailRowLimit: Int {
        family == .systemSmall ? 4 : 8
    }

    /// Page 0: score, Run Index, tier, location (no in-widget link to the app info sheet).
    private var widgetMainPage: some View {
        Group {
            switch family {
            case .systemSmall:
                smallHomeVerticalStack
            default:
                smallHomeTwoColumnTop
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var widgetSummaryPage: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetSectionHeader("Summary")
            if !entry.payload.contextLine.isEmpty {
                Text(entry.payload.contextLine)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(family == .systemSmall ? 3 : 6)
                    .minimumScaleFactor(0.78)
            }
            if !entry.payload.verdict.isEmpty {
                Text(entry.payload.verdict)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.85)
            }
            ForEach(Array(entry.payload.bullets.prefix(family == .systemSmall ? 3 : 6).enumerated()), id: \.offset) { _, bullet in
                Text("• \(bullet)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func widgetRowsSection(title: String, rows: [WidgetRowPair]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetSectionHeader(title)
            if rows.isEmpty {
                Text("Open StrideCheck to refresh.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.key)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: 4)
                        Text(row.value)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func widgetSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var runIndexLabelAndTier: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Run Index")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(entry.payload.tierLabel)
                .font(.callout.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accent.opacity(colorScheme == .dark ? 0.25 : 0.2))
                .foregroundStyle(accent)
                .clipShape(Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Tight home-screen square: one column avoids horizontal compression.
    private var smallHomeVerticalStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(entry.payload.score)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)

            runIndexLabelAndTier

            Spacer(minLength: 4)

            Text(entry.payload.placeName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Medium+ : score left, Run Index + tier right; score keeps intrinsic width so it won’t ellipsize.
    private var smallHomeTwoColumnTop: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(entry.payload.score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .layoutPriority(2)
                    .fixedSize(horizontal: true, vertical: false)

                runIndexLabelAndTier
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 6)

            Text(entry.payload.placeName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

private extension View {
    /// Skips `widgetURL` on the home-screen widget while detail mode is active so taps don’t conflict with intents.
    @ViewBuilder
    func strideCheckWidgetDeepLink(entry: RunIndexEntry, family: WidgetFamily, url: URL) -> some View {
        let isAccessoryFamily: Bool = {
            switch family {
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                return true
            default:
                return false
            }
        }()
        if entry.showDetailPages && !isAccessoryFamily {
            self
        } else {
            self.widgetURL(url)
        }
    }
}
