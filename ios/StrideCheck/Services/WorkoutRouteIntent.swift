import Foundation

/// User workout goal for rule-based route suggestions (MVP — no LLM).
enum WorkoutRouteIntent: String, CaseIterable, Identifiable {
    case easy
    case intervals
    case longRun

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .easy: return "Easy"
        case .intervals: return "Intervals"
        case .longRun: return "Long run"
        }
    }

    var summary: String {
        switch self {
        case .easy: return "Moderate distance, mixed gentle hills"
        case .intervals: return "Shorter, flat — good for repeats"
        case .longRun: return "Longer distance, varied elevation"
        }
    }

    /// Target **round-trip** distance along roads (Apple walking directions × 2).
    var targetRoundTripMeters: ClosedRange<Double> {
        switch self {
        case .easy: return 5000...13_000
        case .intervals: return 4000...10_000
        case .longRun: return 10_000...26_000
        }
    }

    /// Rough distance toward which we aim for the **out** leg (half of round-trip).
    var halfLegTargetMeters: Double {
        switch self {
        case .easy: return 3200
        case .intervals: return 2800
        case .longRun: return 5200
        }
    }

    /// Numeric constraints for filtering candidates after elevation sampling.
    func scoringConstraints() -> RouteScoringConstraints {
        switch self {
        case .intervals:
            return RouteScoringConstraints(
                targetDistanceMeters: targetRoundTripMeters,
                minTotalAscentMeters: nil,
                maxTotalAscentMeters: 45,
                maxGradePercent: 5.0
            )
        case .easy:
            return RouteScoringConstraints(
                targetDistanceMeters: targetRoundTripMeters,
                minTotalAscentMeters: 20,
                maxTotalAscentMeters: 280,
                maxGradePercent: 8.0
            )
        case .longRun:
            return RouteScoringConstraints(
                targetDistanceMeters: targetRoundTripMeters,
                minTotalAscentMeters: 70,
                maxTotalAscentMeters: 750,
                maxGradePercent: 12.0
            )
        }
    }
}

struct RouteScoringConstraints {
    let targetDistanceMeters: ClosedRange<Double>
    let minTotalAscentMeters: Double?
    let maxTotalAscentMeters: Double?
    let maxGradePercent: Double
}
