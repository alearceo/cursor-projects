import CoreLocation
import Foundation

/// One suggested out-and-back route (real road geometry from MapKit).
struct SuggestedRouteRun: Identifiable {
    let id: UUID
    /// Full route: center → waypoint → center along same path.
    let coordinates: [CLLocationCoordinate2D]
    /// Walking distance (round trip), meters.
    let distanceMeters: Double
    let totalAscentMeters: Double
    let maxGradePercent: Double
    let compassLabel: String
    /// Whether elevation came from Open-Elevation (false = distance-only fallback).
    let hasElevationProfile: Bool

    var distanceKmString: String {
        String(format: "%.1f km", distanceMeters / 1000)
    }

    var ascentString: String {
        if hasElevationProfile {
            return String(format: "%.0f m ↑", totalAscentMeters)
        }
        return "Elevation n/a"
    }

    var gradeString: String {
        if hasElevationProfile {
            return String(format: "max %.0f%% grade", maxGradePercent)
        }
        return ""
    }
}
