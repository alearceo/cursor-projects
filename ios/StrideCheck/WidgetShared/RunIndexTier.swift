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
        case .good: return Color(red: 0.32, green: 0.9, blue: 0.52)
        case .moderate: return Color(red: 0.98, green: 0.82, blue: 0.28)
        case .poor: return Color(red: 1.0, green: 0.45, blue: 0.4)
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
