import Foundation

/// Fetches latest Whoop recovery, cycle strain, and sleep duration using a Keychain-stored OAuth token.
enum WhoopAPIClient {
    private static let apiRoot = "https://api.prod.whoop.com/developer"

    struct ReadinessSlice: Sendable {
        let recoveryScore: Int?
        let hrvRmssdMilli: Double?
        let cycleStrain: Double?
        let sleepHours: Double?
    }

    static func fetchLatestSlice() async throws -> ReadinessSlice? {
        guard KeychainCredentialStore.string(for: .whoopAccessToken) != nil else { return nil }
        try await WhoopOAuthService.refreshAccessTokenIfNeeded()
        guard let token = KeychainCredentialStore.string(for: .whoopAccessToken) else { return nil }

        async let recovery = fetchRecovery(token: token)
        async let cycleStrain = fetchCycleStrain(token: token)
        async let sleepMilli = fetchSleepInBedMilli(token: token)

        let r = await recovery
        let cStrain = await cycleStrain
        let sm = await sleepMilli

        let sleepHours = sm.map { Double($0) / 3_600_000.0 }

        return ReadinessSlice(
            recoveryScore: r?.recoveryScore,
            hrvRmssdMilli: r?.hrvRmssdMilli,
            cycleStrain: cStrain,
            sleepHours: sleepHours
        )
    }

    private struct RecoveryEnvelope: Decodable {
        struct Record: Decodable {
            struct Score: Decodable {
                let recoveryScore: Int?
                let hrvRmssdMilli: Double?
            }
            let score: Score?
        }
        let records: [Record]
    }

    private struct CycleEnvelope: Decodable {
        struct Record: Decodable {
            struct Score: Decodable {
                let strain: Double?
            }
            let score: Score?
        }
        let records: [Record]
    }

    private struct SleepEnvelope: Decodable {
        struct Record: Decodable {
            struct Score: Decodable {
                struct StageSummary: Decodable {
                    let totalInBedTimeMilli: Int?
                }
                let stageSummary: StageSummary?
            }
            let score: Score?
        }
        let records: [Record]
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private static func fetchRecovery(token: String) async -> (recoveryScore: Int?, hrvRmssdMilli: Double?)? {
        guard let data = await get(path: "/v2/recovery?limit=1", token: token),
              let env = try? makeDecoder().decode(RecoveryEnvelope.self, from: data),
              let first = env.records.first else { return nil }
        return (first.score?.recoveryScore, first.score?.hrvRmssdMilli)
    }

    private static func fetchCycleStrain(token: String) async -> Double? {
        guard let data = await get(path: "/v2/cycle?limit=1", token: token),
              let env = try? makeDecoder().decode(CycleEnvelope.self, from: data),
              let first = env.records.first else { return nil }
        return first.score?.strain
    }

    private static func fetchSleepInBedMilli(token: String) async -> Int? {
        guard let data = await get(path: "/v2/activity/sleep?limit=1", token: token),
              let env = try? makeDecoder().decode(SleepEnvelope.self, from: data),
              let first = env.records.first else { return nil }
        return first.score?.stageSummary?.totalInBedTimeMilli
    }

    private static func get(path: String, token: String) async -> Data? {
        guard let url = URL(string: apiRoot + path) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
