import Foundation
import HealthKit

/// Reads recent HRV, last-night sleep, and prior-day activity from Apple Health (Oura / Whoop / Apple Watch often write here).
@MainActor
final class HealthKitReadinessFetcher {
    static let shared = HealthKitReadinessFetcher()

    private let store = HKHealthStore()
    private var didRequestAuth = false

    struct Sample: Sendable {
        let hrvSDNN: Double?
        let sleepHoursLastNight: Double?
        let activeEnergyKcalYesterday: Double?
        let exerciseMinutesYesterday: Double?
    }

    /// Human-readable status for Settings / Data sources (read access is coarse on iOS).
    static func authorizationSummary() async -> String {
        guard HKHealthStore.isHealthDataAvailable() else {
            return "Health data not available on this device."
        }
        let store = HKHealthStore()
        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
        ]
        let writeTypes = Set<HKSampleType>()
        return await withCheckedContinuation { cont in
            store.getRequestStatusForAuthorization(toShare: writeTypes, read: types) { status, error in
                if let error {
                    cont.resume(returning: "Could not determine Health access (\(error.localizedDescription)).")
                    return
                }
                switch status {
                case .shouldRequest:
                    cont.resume(returning: "Access not requested yet — open the Conditions tab and load a location to grant read access.")
                case .unnecessary:
                    cont.resume(returning: "Read access was requested. StrideCheck uses HRV, sleep, and activity when present in Health.")
                @unknown default:
                    cont.resume(returning: "Unknown authorization state.")
                }
            }
        }
    }

    func loadSample() async -> Sample {
        guard HKHealthStore.isHealthDataAvailable() else {
            return Sample(hrvSDNN: nil, sleepHoursLastNight: nil, activeEnergyKcalYesterday: nil, exerciseMinutesYesterday: nil)
        }

        await requestAuthorizationIfNeeded()

        let hrv = await latestHRVSDNN()
        let sleep = await sleepHoursLastMainSleepSession()
        let (energy, exercise) = await yesterdayActivityTotals()

        return Sample(
            hrvSDNN: hrv,
            sleepHoursLastNight: sleep,
            activeEnergyKcalYesterday: energy,
            exerciseMinutesYesterday: exercise
        )
    }

    private func requestAuthorizationIfNeeded() async {
        guard !didRequestAuth else { return }
        didRequestAuth = true

        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: types)
        } catch {
            // User denied or Health unavailable
        }
    }

    private func latestHRVSDNN() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let since = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let q = samples?.first as? HKQuantitySample else {
                    cont.resume(returning: nil)
                    return
                }
                let ms = q.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                cont.resume(returning: ms)
            }
            store.execute(q)
        }
    }

    private func sleepHoursLastMainSleepSession() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .hour, value: -40, to: end) else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    cont.resume(returning: nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                var total: TimeInterval = 0
                for s in samples where asleepValues.contains(s.value) {
                    total += s.endDate.timeIntervalSince(s.startDate)
                }
                let hours = total >= 2700 ? total / 3600.0 : nil
                cont.resume(returning: hours)
            }
            store.execute(q)
        }
    }

    private func yesterdayActivityTotals() async -> (Double?, Double?) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -1, to: end) else { return (nil, nil) }

        async let energy: Double? = sumQuantity(
            identifier: .activeEnergyBurned,
            unit: HKUnit.kilocalorie(),
            start: start,
            end: end
        )
        async let exercise: Double? = sumQuantity(
            identifier: .appleExerciseTime,
            unit: HKUnit.minute(),
            start: start,
            end: end
        )
        return await (energy, exercise)
    }

    private func sumQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                let v = stats?.sumQuantity()?.doubleValue(for: unit)
                cont.resume(returning: v)
            }
            store.execute(q)
        }
    }
}
