import CoreLocation
import Foundation

/// Samples terrain height for route scoring. Public Open-Elevation API (HTTPS, no key).
enum OpenElevationClient {
    private static let endpoint = URL(string: "https://api.open-elevation.com/api/v1/lookup")!

    private struct LookupRequest: Encodable {
        struct Loc: Encodable {
            let latitude: Double
            let longitude: Double
        }
        let locations: [Loc]
    }

    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let elevation: Double
        }
        let results: [Result]
    }

    /// Returns elevations in the same order as `coordinates`, or throws.
    static func elevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        let body = LookupRequest(locations: coordinates.map {
            LookupRequest.Loc(latitude: $0.latitude, longitude: $0.longitude)
        })
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard decoded.results.count == coordinates.count else {
            throw URLError(.badServerResponse)
        }
        return decoded.results.map(\.elevation)
    }
}
