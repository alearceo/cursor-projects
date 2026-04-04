import SwiftUI

/// Run index color bands (Conditions tab + widget).
enum RunIndexTier {
    case good
    case moderate
    case poor

    init(score: Int) {
        switch score {
        case 80...100: self = .good
        case 60..<80: self = .moderate
        default: self = .poor
        }
    }

    var accentColor: Color {
        switch self {
        case .good: return Color(red: 0.2, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor: return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    var gradient: [Color] {
        switch self {
        case .good:
            return [
                Color(red: 0.12, green: 0.55, blue: 0.32).opacity(0.35),
                Color(red: 0.2, green: 0.72, blue: 0.38).opacity(0.12)
            ]
        case .moderate:
            return [
                Color(red: 0.75, green: 0.55, blue: 0.1).opacity(0.35),
                Color(red: 0.95, green: 0.76, blue: 0.2).opacity(0.12)
            ]
        case .poor:
            return [
                Color(red: 0.65, green: 0.15, blue: 0.12).opacity(0.35),
                Color(red: 0.92, green: 0.32, blue: 0.28).opacity(0.12)
            ]
        }
    }

    var label: String {
        switch self {
        case .good: return "Strong"
        case .moderate: return "Mixed"
        case .poor: return "Tough"
        }
    }
}
