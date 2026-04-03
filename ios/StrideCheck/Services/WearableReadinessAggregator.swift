import Foundation

/// Combines **Whoop OAuth**, **Oura** PAT, and **Apple Health** per `WearableRunIndexPreferences` (third-party opt-in).
@MainActor
enum WearableReadinessAggregator {
    /// Shown in the run-index pipeline when Apple Health has no usable samples and no third-party slice is active.
    static let noWearableSignalSourceLabel = "No wearable signal — enable Health or Data sources"

    static func loadWearableRunReadiness() async -> WearableRunReadiness {
        let hk = await HealthKitReadinessFetcher.shared.loadSample()

        let useWhoop = WearableRunIndexPreferences.includeWhoopInRunIndex
        let useOura = WearableRunIndexPreferences.includeOuraInRunIndex

        var whoopSlice: WhoopAPIClient.ReadinessSlice?
        if useWhoop, KeychainCredentialStore.string(for: .whoopAccessToken) != nil {
            whoopSlice = try? await WhoopAPIClient.fetchLatestSlice()
        } else {
            whoopSlice = nil
        }

        var ouraSlice: OuraPersonalAPIClient.DailySlice?
        if useOura, let token = StrideCheckSecrets.ouraPersonalAccessToken {
            ouraSlice = await OuraPersonalAPIClient.fetchLatestSlice(token: token)
        } else {
            ouraSlice = nil
        }

        if let w = whoopSlice {
            let sleepHours = w.sleepHours ?? ouraSlice?.sleepHours ?? hk.sleepHoursLastNight
            let readiness = w.recoveryScore ?? ouraSlice?.readinessScore
            let strainProxy: Double?
            if w.cycleStrain != nil {
                strainProxy = nil
            } else if let met = ouraSlice?.highActivityMetMinutes {
                strainProxy = min(21, met / 18.0)
            } else if let kcal = hk.activeEnergyKcalYesterday {
                strainProxy = min(21, kcal / 280.0)
            } else if let ex = hk.exerciseMinutesYesterday {
                strainProxy = min(21, ex / 45.0)
            } else {
                strainProxy = nil
            }

            var parts: [String] = ["Whoop API"]
            if hk.hrvSDNN != nil { parts.append("Apple Health HRV") }
            if useOura, ouraSlice != nil { parts.append("Oura") }

            return WearableRunReadiness(
                hrvSDNNMs: hk.hrvSDNN,
                hrvRmssdMilli: w.hrvRmssdMilli,
                sleepHours: sleepHours,
                strainProxy0to21: strainProxy,
                whoopCycleStrain: w.cycleStrain,
                readinessScore0to100: readiness,
                sourceLabel: parts.joined(separator: " + ")
            )
        }

        if let ouraSlice {
            let sleepHours = ouraSlice.sleepHours ?? hk.sleepHoursLastNight
            let readinessScore = ouraSlice.readinessScore
            let strainProxy: Double?
            if let met = ouraSlice.highActivityMetMinutes {
                strainProxy = min(21, met / 18.0)
            } else if let kcal = hk.activeEnergyKcalYesterday {
                strainProxy = min(21, kcal / 280.0)
            } else if let ex = hk.exerciseMinutesYesterday {
                strainProxy = min(21, ex / 45.0)
            } else {
                strainProxy = nil
            }

            let sourceLabel: String
            if hk.hrvSDNN != nil {
                sourceLabel = "Oura API + Apple Health"
            } else {
                sourceLabel = "Oura API"
            }

            return WearableRunReadiness(
                hrvSDNNMs: hk.hrvSDNN,
                hrvRmssdMilli: nil,
                sleepHours: sleepHours,
                strainProxy0to21: strainProxy,
                whoopCycleStrain: nil,
                readinessScore0to100: readinessScore,
                sourceLabel: sourceLabel
            )
        }

        let strainProxy: Double?
        if let kcal = hk.activeEnergyKcalYesterday {
            strainProxy = min(21, kcal / 280.0)
        } else if let ex = hk.exerciseMinutesYesterday {
            strainProxy = min(21, ex / 45.0)
        } else {
            strainProxy = nil
        }

        let sourceLabel: String
        if hk.hrvSDNN != nil || hk.sleepHoursLastNight != nil || hk.activeEnergyKcalYesterday != nil {
            sourceLabel = "Apple Health"
        } else {
            sourceLabel = Self.noWearableSignalSourceLabel
        }

        return WearableRunReadiness(
            hrvSDNNMs: hk.hrvSDNN,
            hrvRmssdMilli: nil,
            sleepHours: hk.sleepHoursLastNight,
            strainProxy0to21: strainProxy,
            whoopCycleStrain: nil,
            readinessScore0to100: nil,
            sourceLabel: sourceLabel
        )
    }
}
