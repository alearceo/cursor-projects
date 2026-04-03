import Foundation

/// Optional [Crimeometer](https://www.crimeometer.com/) incident counts near a coordinate (API key in Info.plist `CrimeometerAPIKey`).
enum CrimeIncidentsService {
    struct Summary: Sendable, Equatable {
        let incidentCount: Int
        let radiusMiles: Double
        let windowDays: Int
    }

    static func fetchSummary(latitude: Double, longitude: Double) async -> Summary? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "CrimeometerAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else { return nil }

        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -30, to: end) else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var c = URLComponents(string: "https://api.crimeometer.com/v2/crime-incidents")!
        c.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "distance", value: "1mi"),
            URLQueryItem(name: "datetime_ini", value: iso.string(from: start)),
            URLQueryItem(name: "datetime_end", value: iso.string(from: end))
        ]
        guard let url = c.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "x-api-key")

        do {
            let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let count = countIncidents(from: data)
            return Summary(incidentCount: count, radiusMiles: 1, windowDays: 30)
        } catch {
            return nil
        }
    }

    private static func countIncidents(from data: Data) -> Int {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return 0 }
        if let dict = obj as? [String: Any] {
            for key in ["incidents", "results", "data", "crime_incidents"] {
                if let arr = dict[key] as? [Any] { return arr.count }
            }
            if let total = dict["total_incidents"] as? Int { return total }
            if let total = dict["total"] as? Int { return total }
        }
        if let arr = obj as? [Any] { return arr.count }
        return 0
    }
}
