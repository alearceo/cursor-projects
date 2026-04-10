import SwiftUI
import UIKit

enum TopEdgeFrostFadeStyle {
    /// Scroll content under status bar: tint with grouped background then frosted mask.
    case groupedScroll
    /// Map under status bar: frost only (same material as `route511Card`).
    case map
}

/// Gradient-style transition so content sliding under the status bar / Dynamic Island softens like the bottom sheet.
/// Vertical extent is tuned to approximate the Route tab bottom `ultraThinMaterial` card so status-bar chrome stays readable.
struct TopEdgeFrostFade: View {
    var style: TopEdgeFrostFadeStyle

    var body: some View {
        GeometryReader { geo in
            let fadeHeight = geo.safeAreaInsets.top + 56
            let materialTail: CGFloat = 40
            let groupedTintTail: CGFloat = 18
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    if style == .groupedScroll {
                        LinearGradient(
                            colors: [
                                Color(uiColor: .systemGroupedBackground),
                                Color(uiColor: .systemGroupedBackground).opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeHeight + groupedTintTail)
                    }

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: fadeHeight + materialTail)
                        .mask(
                            LinearGradient(
                                colors: [.black, .black.opacity(0.92), .black.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: fadeHeight + materialTail)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
    }
}
