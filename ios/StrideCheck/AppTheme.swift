import SwiftUI
import UIKit

// MARK: - Brand palette (race telemetry / instrument panel)

/// Central design tokens and reusable chrome. Dynamic UIColor keeps light/dark coherent.
enum AppTheme {

    enum Spacing {
        static let screenHorizontal: CGFloat = 20
        static let section: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let tight: CGFloat = 10
    }

    enum Corner {
        static let card: CGFloat = 12
        static let pill: CGFloat = 8
        static let chip: CGFloat = 6
    }

    /// Electric amber — the sole accent; used for CTAs, score ring, tab tint.
    static let accent = Color(red: 0.961, green: 0.718, blue: 0.0)
}

// MARK: - Semantic palette

extension Color {

    /// Near-black (dark) / cool off-white (light) page canvas.
    static var strideCanvas: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.047, green: 0.047, blue: 0.059, alpha: 1)   // #0C0C0F
                : UIColor(red: 0.949, green: 0.941, blue: 0.922, alpha: 1)   // #F2F0EB
        })
    }

    /// Card surface.
    static var strideSurface: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.078, green: 0.078, blue: 0.094, alpha: 1)   // #141418
                : UIColor(red: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1)
        })
    }

    /// Nested blocks within a card (hourly chips, inner rows).
    static var strideSurfaceSecondary: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.110, blue: 0.133, alpha: 1)   // #1C1C22
                : UIColor(red: 0.929, green: 0.922, blue: 0.902, alpha: 1)   // #EDEBE6
        })
    }

    /// Primary body text / icons.
    static var strideInk: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.929, green: 0.929, blue: 0.914, alpha: 1)   // #EDEDE9
                : UIColor(red: 0.094, green: 0.086, blue: 0.094, alpha: 1)   // #181618
        })
    }

    /// Secondary labels, captions.
    static var strideInkSecondary: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.533, green: 0.533, blue: 0.596, alpha: 1)   // #888898
                : UIColor(red: 0.369, green: 0.361, blue: 0.392, alpha: 1)   // #5E5C64
        })
    }

    /// Route awareness card background tint.
    static var strideRouteAwarenessTint: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.2, green: 0.3, blue: 0.9, alpha: 0.20)
                : UIColor(red: 0.2, green: 0.35, blue: 0.9, alpha: 0.10)
        })
    }
}

// MARK: - Typography (instrument-grade — no SF Rounded)

enum StrideFont {
    /// App title / brand header — black, telemetry panel header (size matches spec).
    static var heroTitle: Font {
        .system(size: 28, weight: .black)
    }
    static var brandSubtitle: Font {
        .system(.subheadline, design: .default).weight(.regular)
    }
    static var sectionTitle: Font {
        .system(.headline, design: .default).weight(.semibold)
    }
    static var cardTitle: Font {
        .system(.subheadline, design: .default).weight(.medium)
    }
    /// Monospaced for all numeric score displays.
    static func scoreLarge(_ points: CGFloat) -> Font {
        .system(size: points, weight: .heavy, design: .monospaced)
    }
    /// Monospaced for data-table value cells.
    static var dataValue: Font {
        .system(.subheadline, design: .monospaced).weight(.semibold)
    }
}

// MARK: - Dot-grid background (telemetry graph paper)

struct StrideTelemetryBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.strideCanvas
            GeometryReader { geo in
                Canvas { ctx, size in
                    let spacing: CGFloat = 18
                    // ~0.5pt diameter dots per telemetry spec
                    let dotRadius: CGFloat = 0.25
                    let dotOpacity = scheme == .dark ? 0.045 : 0.065
                    let dotColor = Color.strideInk.opacity(dotOpacity)
                    var col = spacing
                    while col < size.width {
                        var row = spacing
                        while row < size.height {
                            let rect = CGRect(
                                x: col - dotRadius,
                                y: row - dotRadius,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            )
                            ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
                            row += spacing
                        }
                        col += spacing
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Flatten static grid to reduce overdraw while scrolling content above.
                .drawingGroup()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Instrument-panel card

private struct StrideInstrumentCardModifier: ViewModifier {
    var strokeOpacity: Double = 0.10

    func body(content: Content) -> some View {
        content
            .background(Color.strideSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous)
                    .strokeBorder(Color.strideInk.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

extension View {
    /// Instrument-panel card: flat surface, hairline border, sharp corners, no shadow.
    func strideInstrumentCard(strokeOpacity: Double = 0.10) -> some View {
        modifier(StrideInstrumentCardModifier(strokeOpacity: strokeOpacity))
    }

    /// Legacy alias — prefer `strideInstrumentCard`.
    func strideCard(strokeOpacity: Double = 0.10, shadowOpacity: Double = 0) -> some View {
        strideInstrumentCard(strokeOpacity: strokeOpacity)
    }

    /// List / form screens: hide default List background, apply dot-grid canvas.
    func strideListScreenChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(StrideTelemetryBackground())
    }
}

// MARK: - Left-bar banner (log-terminal style)

/// Inline banner with a colored left bar — no filled rounded rectangle.
struct StrideLeftBarBanner<Content: View>: View {
    var barColor: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(barColor)
                .frame(width: 3)
                .clipShape(Capsule())
            content()
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 12)
        .padding(.trailing, 12)
    }
}

// MARK: - Tab bar

enum StrideCheckAppearance {
    static func configureTabBarAccent() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let amber = UIColor(red: 0.961, green: 0.718, blue: 0.0, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = amber
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: amber]
        appearance.inlineLayoutAppearance.selected.iconColor = amber
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: amber]
        appearance.compactInlineLayoutAppearance.selected.iconColor = amber
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: amber]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
