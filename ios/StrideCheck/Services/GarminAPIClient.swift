import Foundation

/// Pulls recent **dailies** from the Garmin Health / wellness REST API (developer-program access).
@MainActor
enum GarminAPIClient {
    struct ReadinessSlice: Sendable {
        let sleepHours: Double?
        let readinessScore0to100: Int?
        let hrvSDNNMs: Double?
    }

    static func fetchLatestReadinessSlice() async -> ReadinessSlice? {
        try? await GarminOAuthService.refreshAccessTokenIfNeeded()
        guard let token = KeychainCredentialStore.string(for: .garminAccessToken) else { return nil }

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -10, to: end) ?? end
        let startSec = Int(start.timeIntervalSince1970)
        let endSec = Int(end.timeIntervalSince1970)

        var comp = URLComponents(string: "https://apis.garmin.com/wellness-api/rest/dailies")!
        comp.queryItems = [
            URLQueryItem(name: "uploadStartTimeInSeconds", value: String(startSec)),
            URLQueryItem(name: "uploadEndTimeInSeconds", value: String(endSec))
        ]
        guard let url = comp.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
        } catch {
            return nil
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        guard let slice = parseDailiesPayload(data),
              slice.sleepHours != nil || slice.readinessScore0to100 != nil || slice.hrvSDNNMs != nil else {
            return nil
        }
        return slice
    }

    private static func parseDailiesPayload(_ data: Data) -> ReadinessSlice? {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([GarminDailyDTO].self, from: data) {
            return bestSlice(from: list)
        }
        if let env = try? decoder.decode(GarminDailyListEnvelope.self, from: data) {
            return bestSlice(from: env.dailyDTOs ?? env.dailies ?? [])
        }
        return nil
    }

    private static func bestSlice(from list: [GarminDailyDTO]) -> ReadinessSlice? {
        guard !list.isEmpty else { return nil }
        let sorted = list.sorted { ($0.calendarDate ?? "") > ($1.calendarDate ?? "") }
        guard let d = sorted.first else { return nil }

        let sleepSec = d.sleepTimeInSeconds ?? d.sleepTimeSeconds ?? d.totalSleepTimeInSeconds ?? d.durationInSeconds
        let sleepH = sleepSec.map { Double($0) / 3600.0 }

        let stress = d.averageStressLevel ?? d.avgStressLevel ?? d.allDayStress?.average
        let readiness: Int? = stress.map { s in
            max(0, min(100, 100 - (s * 90) / 100))
        }

        let hrvMs = d.lastNightAvgHrv ?? d.hrvSummary?.lastNightAvg
        return ReadinessSlice(
            sleepHours: sleepH,
            readinessScore0to100: readiness,
            hrvSDNNMs: hrvMs
        )
    }
}

private struct GarminDailyListEnvelope: Decodable {
    let dailyDTOs: [GarminDailyDTO]?
    let dailies: [GarminDailyDTO]?
}

private struct GarminDailyDTO: Decodable {
    let calendarDate: String?
    let sleepTimeInSeconds: Int?
    let sleepTimeSeconds: Int?
    let totalSleepTimeInSeconds: Int?
    let durationInSeconds: Int?
    let averageStressLevel: Int?
    let avgStressLevel: Int?
    let lastNightAvgHrv: Double?
    let hrvSummary: GarminHrvSummaryDTO?
    let allDayStress: GarminAllDayStressDTO?

    struct GarminHrvSummaryDTO: Decodable {
        let lastNightAvg: Double?
    }

    struct GarminAllDayStressDTO: Decodable {
        let average: Int?
    }
}
