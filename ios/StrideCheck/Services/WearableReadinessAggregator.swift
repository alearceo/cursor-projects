import Foundation

/// Combines Oura Cloud (personal access token) with Apple Health samples for run readiness heuristics.
/// Whoop does not expose a simple PAT; when Whoop → Apple Health sync is enabled, the HealthKit path picks up strain/recovery proxies the same way.
@MainActor
enum WearableReadinessAggregator {
    static func loadWearableRunReadiness() async -> WearableRunReadiness {
        let token = (Bundle.main.object(forInfoDictionaryKey: "OuraPersonalAccessToken") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let ouraSlice: OuraPersonalAPIClient.DailySlice?
        if let token, !token.isEmpty {
            ouraSlice = await OuraPersonalAPIClient.fetchLatestSlice(token: token)
        } else {
            ouraSlice = nil
        }

        let hk = await HealthKitReadinessFetcher.shared.loadSample()

        let sleepHours = ouraSlice?.sleepHours ?? hk.sleepHoursLastNight
        let readinessScore = ouraSlice?.readinessScore

        let strainProxy: Double?
        if let met = ouraSlice?.highActivityMetMinutes {
            strainProxy = min(21, met / 18.0)
        } else if let kcal = hk.activeEnergyKcalYesterday {
            strainProxy = min(21, kcal / 280.0)
        } else if let ex = hk.exerciseMinutesYesterday {
            strainProxy = min(21, ex / 45.0)
        } else {
            strainProxy = nil
        }

        let sourceLabel: String
        if ouraSlice != nil, hk.hrvSDNN != nil {
            sourceLabel = "Oura API + Apple Health"
        } else if ouraSlice != nil {
            sourceLabel = "Oura API"
        } else if hk.hrvSDNN != nil || hk.sleepHoursLastNight != nil || hk.activeEnergyKcalYesterday != nil {
            sourceLabel = "Apple Health (sync Whoop/Oura/Watch)"
        } else {
            sourceLabel = "Not connected — enable Health or add Oura token"
        }

        return WearableRunReadiness(
            hrvSDNNMs: hk.hrvSDNN,
            sleepHours: sleepHours,
            strainProxy0to21: strainProxy,
            readinessScore0to100: readinessScore,
            sourceLabel: sourceLabel
        )
    }
}
