import CoreLocation
import Foundation
import MapKit

/// Builds nearby **out-and-back** road routes with MapKit walking directions, scores them with elevation sampling (no LLM).
enum RouteSuggestionService {

    private static let bearingsDegrees: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]

    /// Up to three suggestions that best match `intent` constraints.
    static func suggestRoutes(
        center: CLLocationCoordinate2D,
        intent: WorkoutRouteIntent
    ) async throws -> [SuggestedRouteRun] {
        let constraints = intent.scoringConstraints()
        var built: [(route: MKRoute, bearing: Double)] = []

        for deg in bearingsDegrees {
            try Task.checkCancellation()
            let dest = coordinate(from: center, distanceMeters: intent.halfLegTargetMeters, bearingDegrees: deg)
            guard let mkRoute = try await walkingRoute(from: center, to: dest) else { continue }
            built.append((mkRoute, deg))
        }

        var scored: [SuggestedRouteRun] = []
        for item in built {
            try Task.checkCancellation()
            if let run = await buildSuggestedRun(route: item.route, compassDegrees: item.bearing) {
                scored.append(run)
            }
        }

        let strict = filterAndRank(scored, constraints: constraints)
        if !strict.isEmpty { return Array(strict.prefix(3)) }

        let relaxed = filterAndRank(scored, constraints: constraints.relaxed())
        if !relaxed.isEmpty { return Array(relaxed.prefix(3)) }

        let distanceFit = scored
            .filter { constraints.targetDistanceMeters.contains($0.distanceMeters) }
            .sorted { distanceScore($0.distanceMeters, range: constraints.targetDistanceMeters) < distanceScore($1.distanceMeters, range: constraints.targetDistanceMeters) }
        if !distanceFit.isEmpty { return Array(distanceFit.prefix(3)) }

        return Array(
            scored
                .sorted { distanceScore($0.distanceMeters, range: constraints.targetDistanceMeters) < distanceScore($1.distanceMeters, range: constraints.targetDistanceMeters) }
                .prefix(3)
        )
    }

    // MARK: - MKDirections

    private static func walkingRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            return response.routes.first
        } catch {
            return nil
        }
    }

    // MARK: - Build polyline + metrics

    private static func buildSuggestedRun(route: MKRoute, compassDegrees: Double) async -> SuggestedRouteRun? {
        let forward = coordinates(from: route.polyline)
        guard forward.count >= 2 else { return nil }
        let back = forward.dropLast().reversed()
        let full = forward + back
        let distanceMeters = route.distance * 2

        let samples = sampleCoordinates(full, maxPoints: 72)
        var hasEl = false
        var ascent = 0.0
        var maxGrade = 0.0

        do {
            let elevs = try await OpenElevationClient.elevations(for: samples)
            hasEl = true
            (ascent, maxGrade) = ascentAndMaxGrade(elevations: elevs, coordinates: samples)
        } catch {
            hasEl = false
        }

        let label = compassLabel(degrees: compassDegrees)
        return SuggestedRouteRun(
            id: UUID(),
            coordinates: full,
            distanceMeters: distanceMeters,
            totalAscentMeters: ascent,
            maxGradePercent: maxGrade,
            compassLabel: label,
            hasElevationProfile: hasEl
        )
    }

    private static func filterAndRank(_ runs: [SuggestedRouteRun], constraints: RouteScoringConstraints) -> [SuggestedRouteRun] {
        let ok = runs.filter { constraints.matches($0) }
        guard !ok.isEmpty else { return [] }
        let range = constraints.targetDistanceMeters
        return ok.sorted { distanceScore($0.distanceMeters, range: range) < distanceScore($1.distanceMeters, range: range) }
    }

    private static func distanceScore(_ meters: Double, range: ClosedRange<Double>) -> Double {
        let mid = (range.lowerBound + range.upperBound) / 2
        return abs(meters - mid)
    }

    // MARK: - Geometry

    private static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords.filter { CLLocationCoordinate2DIsValid($0) }
    }

    private static func sampleCoordinates(_ coords: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coords.count > maxPoints else { return coords }
        let step = max(1, coords.count / maxPoints)
        var out: [CLLocationCoordinate2D] = []
        var i = 0
        while i < coords.count {
            out.append(coords[i])
            i += step
        }
        if let last = coords.last, let o = out.last {
            if abs(o.latitude - last.latitude) > 1e-7 || abs(o.longitude - last.longitude) > 1e-7 {
                out.append(last)
            }
        }
        return out
    }

    private static func ascentAndMaxGrade(elevations: [Double], coordinates: [CLLocationCoordinate2D]) -> (Double, Double) {
        guard elevations.count == coordinates.count, elevations.count >= 2 else { return (0, 0) }
        var ascent = 0.0
        var maxGrade = 0.0
        for i in 1..<elevations.count {
            let dh = elevations[i] - elevations[i - 1]
            if dh > 0 { ascent += dh }
            let dist = horizontalDistanceMeters(coordinates[i - 1], coordinates[i])
            guard dist > 2 else { continue }
            let grade = abs(dh) / dist * 100
            if grade > maxGrade { maxGrade = grade }
        }
        return (ascent, maxGrade)
    }

    private static func horizontalDistanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func coordinate(from start: CLLocationCoordinate2D, distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6_378_137.0
        let br = bearingDegrees * .pi / 180
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let angular = distanceMeters / earthRadius
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(br))
        let lon2 = lon1 + atan2(sin(br) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    private static func compassLabel(degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var idx = Int((degrees + 22.5) / 45.0) % 8
        if idx < 0 { idx += 8 }
        return names[idx]
    }
}

private extension RouteScoringConstraints {
    func matches(_ run: SuggestedRouteRun) -> Bool {
        guard targetDistanceMeters.contains(run.distanceMeters) else { return false }
        guard run.hasElevationProfile else { return false }
        if let minA = minTotalAscentMeters, run.totalAscentMeters < minA { return false }
        if let maxA = maxTotalAscentMeters, run.totalAscentMeters > maxA { return false }
        if run.maxGradePercent > maxGradePercent { return false }
        return true
    }

    func relaxed() -> RouteScoringConstraints {
        RouteScoringConstraints(
            targetDistanceMeters: targetDistanceMeters,
            minTotalAscentMeters: minTotalAscentMeters.map { $0 * 0.55 },
            maxTotalAscentMeters: maxTotalAscentMeters.map { $0 * 1.4 },
            maxGradePercent: maxGradePercent * 1.35
        )
    }
}
