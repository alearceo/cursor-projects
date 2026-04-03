import Foundation

/// Fetches yesterday's Oura summaries when a [personal access token](https://cloud.ouraring.com/personal-access-tokens) is set in Info.plist under `OuraPersonalAccessToken`.
enum OuraPersonalAPIClient {
    private static let base = URL(string: "https://api.ouraring.com/v2/usercollection/")!

    struct DailySlice: Sendable {
        let readinessScore: Int?
        let sleepHours: Double?
        let highActivityMetMinutes: Double?
    }

    static func fetchLatestSlice(token: String) async -> DailySlice? {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -3, to: end) else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd"
        let startStr = fmt.string(from: start)
        let endStr = fmt.string(from: end)

        async let readiness = fetchReadiness(token: token, start: startStr, end: endStr)
        async let sleep = fetchSleep(token: token, start: startStr, end: endStr)
        async let activity = fetchActivity(token: token, start: startStr, end: endStr)

        let r = await readiness?.max(by: { $0.day < $1.day })
        let s = await sleep?.max(by: { $0.day < $1.day })
        let a = await activity?.max(by: { $0.day < $1.day })

        let sleepHours: Double?
        if let sec = s?.totalSleepDuration {
            sleepHours = Double(sec) / 3600.0
        } else {
            sleepHours = nil
        }

        return DailySlice(
            readinessScore: r?.score,
            sleepHours: sleepHours,
            highActivityMetMinutes: a.map { Double($0.highActivityMetMinutes ?? 0) }
        )
    }

    private struct ReadinessRow: Decodable {
        let day: String
        let score: Int?
    }

    private struct ReadinessEnvelope: Decodable {
        let data: [ReadinessRow]
    }

    private struct SleepRow: Decodable {
        let day: String
        let totalSleepDuration: Int?

        enum CodingKeys: String, CodingKey {
            case day
            case totalSleepDuration = "total_sleep_duration"
        }
    }

    private struct SleepEnvelope: Decodable {
        let data: [SleepRow]
    }

    private struct ActivityRow: Decodable {
        let day: String
        let highActivityMetMinutes: Int?

        enum CodingKeys: String, CodingKey {
            case day
            case highActivityMetMinutes = "high_activity_met_minutes"
        }
    }

    private struct ActivityEnvelope: Decodable {
        let data: [ActivityRow]
    }

    private static func fetchReadiness(token: String, start: String, end: String) async -> [ReadinessRow]? {
        await get(token: token, path: "daily_readiness", start: start, end: end, as: ReadinessEnvelope.self)?.data
    }

    private static func fetchSleep(token: String, start: String, end: String) async -> [SleepRow]? {
        await get(token: token, path: "daily_sleep", start: start, end: end, as: SleepEnvelope.self)?.data
    }

    private static func fetchActivity(token: String, start: String, end: String) async -> [ActivityRow]? {
        await get(token: token, path: "daily_activity", start: start, end: end, as: ActivityEnvelope.self)?.data
    }

    private static func get<T: Decodable>(token: String, path: String, start: String, end: String, as: T.Type) async -> T? {
        var c = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end)
        ]
        guard let url = c.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
