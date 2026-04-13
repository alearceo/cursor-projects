import SwiftUI
import UIKit

// MARK: - Brand palette (editorial athletic)

/// Central design tokens and reusable chrome. Uses dynamic `UIColor` so light/dark stay coherent.
enum AppTheme {

    enum Spacing {
        static let screenHorizontal: CGFloat = 20
        static let section: CGFloat = 20
        static let cardPadding: CGFloat = 18
        static let tight: CGFloat = 10
    }

    enum Corner {
        static let card: CGFloat = 20
        static let pill: CGFloat = 12
        static let chip: CGFloat = 10
    }

    /// Chartreuse-lime accent (not stock teal).
    static let accent = Color(red: 0.72, green: 0.93, blue: 0.22)
    static let accentMuted = Color(red: 0.72, green: 0.93, blue: 0.22).opacity(0.35)
}

extension Color {

    /// Warm paper (light) / deep ink (dark) canvas.
    static var strideCanvas: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
            }
            return UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1)
        })
    }

    /// Elevated card surface.
    static var strideSurface: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
            }
            return UIColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 0.94)
        })
    }

    /// Secondary blocks inside a card.
    static var strideSurfaceSecondary: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1)
            }
            return UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1)
        })
    }

    static var strideInk: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(white: 0.94, alpha: 1)
            }
            return UIColor(red: 0.12, green: 0.11, blue: 0.14, alpha: 1)
        })
    }

    static var strideInkSecondary: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(white: 0.68, alpha: 1)
            }
            return UIColor(red: 0.38, green: 0.36, blue: 0.4, alpha: 1)
        })
    }

    static var strideWarningFill: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.95, green: 0.55, blue: 0.12, alpha: 0.18)
            }
            return UIColor(red: 0.98, green: 0.72, blue: 0.28, alpha: 0.22)
        })
    }

    static var strideDangerFill: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.95, green: 0.28, blue: 0.32, alpha: 0.2)
            }
            return UIColor(red: 0.95, green: 0.32, blue: 0.35, alpha: 0.14)
        })
    }

    static var strideInfoFill: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.2, green: 0.45, blue: 0.95, alpha: 0.22)
            }
            return UIColor(red: 0.2, green: 0.45, blue: 0.95, alpha: 0.1)
        })
    }

    static var strideRouteAwarenessTint: Color {
        Color(uiColor: UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.55, green: 0.48, blue: 0.98, alpha: 0.22)
            }
            return UIColor(red: 0.45, green: 0.4, blue: 0.95, alpha: 0.12)
        })
    }
}

// MARK: - Typography (SF Rounded — add bundled fonts + UIAppFonts later if desired)

enum StrideFont {
    static var heroTitle: Font { .system(size: 34, weight: .heavy, design: .rounded) }
    static var brandSubtitle: Font { .system(.subheadline, design: .rounded).weight(.medium) }
    static var sectionTitle: Font { .system(.headline, design: .rounded).weight(.semibold) }
    static var cardTitle: Font { .system(.subheadline, design: .rounded).weight(.semibold) }
    static func scoreLarge(_ points: CGFloat) -> Font { .system(size: points, weight: .bold, design: .rounded) }
}

// MARK: - Mesh-style background (iOS 17–safe linear stack)

struct StrideMeshBackground: View {
    var body: some View {
        ZStack {
            Color.strideCanvas
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.14),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.85, y: 0.45)
                    )
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.55, blue: 0.95).opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .topTrailing,
                        endPoint: UnitPoint(x: 0.15, y: 0.55)
                    )
                    RadialGradient(
                        colors: [Color.white.opacity(0.07), Color.clear],
                        center: UnitPoint(x: 0.2, y: 0.85),
                        startRadius: 0,
                        endRadius: min(w, h) * 0.55
                    )
                }
                .frame(width: w, height: h)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card chrome

private struct StrideCardModifier: ViewModifier {
    var strokeOpacity: Double = 0.22
    var shadowOpacity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .background(Color.strideSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous)
                    .strokeBorder(Color.strideInk.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 14, y: 6)
    }
}

extension View {
    /// Editorial card: elevated surface, hairline border, soft shadow.
    func strideCard(strokeOpacity: Double = 0.22, shadowOpacity: Double = 0.12) -> some View {
        modifier(StrideCardModifier(strokeOpacity: strokeOpacity, shadowOpacity: shadowOpacity))
    }

    /// List / form screens pushed from Conditions: hide default list background and paint mesh.
    func strideListScreenChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(StrideMeshBackground())
    }
}

// MARK: - Tab bar

enum StrideCheckAppearance {
    static func configureTabBarAccent() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let lime = UIColor(red: 0.72, green: 0.93, blue: 0.22, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = lime
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: lime]
        appearance.inlineLayoutAppearance.selected.iconColor = lime
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: lime]
        appearance.compactInlineLayoutAppearance.selected.iconColor = lime
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: lime]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
