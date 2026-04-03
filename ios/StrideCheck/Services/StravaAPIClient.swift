import CoreLocation
import Foundation

private struct StravaActivityMap: Decodable {
    let summaryPolyline: String?

    enum CodingKeys: String, CodingKey {
        case summaryPolyline = "summary_polyline"
    }
}

private struct StravaActivitySummary: Decodable {
    let map: StravaActivityMap?
    let type: String?
}

/// Fetches recent activities and decodes run polylines for map overlays.
enum StravaAPIClient {
    private static let activitiesURL = URL(string: "https://www.strava.com/api/v3/athlete/activities")!

    private static let runTypes: Set<String> = ["Run", "TrailRun", "VirtualRun", "Walk"]

    /// Up to `perPage` activities are requested; returns decoded polylines for running-like activities (max `maxPolylines` lines).
    static func recentRunPolylines(perPage: Int = 30, maxPolylines: Int = 24) async throws -> [[CLLocationCoordinate2D]] {
        try await StravaOAuthService.refreshAccessTokenIfNeeded()
        guard let token = KeychainCredentialStore.string(for: .stravaAccessToken) else { return [] }

        var comp = URLComponents(url: activitiesURL, resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "page", value: "1")
        ]
        guard let url = comp.url else { return [] }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }

        let activities: [StravaActivitySummary]
        do {
            activities = try JSONDecoder().decode([StravaActivitySummary].self, from: data)
        } catch {
            return []
        }

        var lines: [[CLLocationCoordinate2D]] = []
        lines.reserveCapacity(min(maxPolylines, activities.count))

        for act in activities {
            guard lines.count < maxPolylines else { break }
            guard let t = act.type, runTypes.contains(t) else { continue }
            guard let encoded = act.map?.summaryPolyline, !encoded.isEmpty else { continue }
            let coords = EncodedPolylineDecoder.decode(encoded)
            guard coords.count >= 2 else { continue }
            lines.append(coords)
        }

        return lines
    }
}
