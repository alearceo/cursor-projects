import XCTest
@testable import StrideCheck

final class ConditionsScoringTests: XCTestCase {

    // MARK: - HeatColdStress

    func testHeatIndexNilBelow80F() {
        XCTAssertNil(HeatColdStress.nwsHeatIndexF(dryBulbF: 79, relativeHumidityPercent: 90))
    }

    func testHeatIndexComputedAt90F() {
        let hi = HeatColdStress.nwsHeatIndexF(dryBulbF: 90, relativeHumidityPercent: 60)
        XCTAssertNotNil(hi)
        XCTAssertGreaterThan(hi!, 90)
    }

    func testWindChillNilWhenWindTooLight() {
        XCTAssertNil(HeatColdStress.nwsWindChillF(dryBulbF: 30, windSpeedMph: 2))
    }

    func testWindChillComputedWhenColdAndWindy() {
        let wc = HeatColdStress.nwsWindChillF(dryBulbF: 20, windSpeedMph: 15)
        XCTAssertNotNil(wc)
        XCTAssertLessThan(wc!, 20)
    }

    func testEffectiveFeelsLikeUsesHotterOfApparentAndHeatIndex() {
        let (eff, rows) = HeatColdStress.effectiveFeelsLikeForRunIndex(
            apparentF: 85,
            dryBulbF: 88,
            relativeHumidityPercent: 70,
            windSpeedMph: 5
        )
        XCTAssertGreaterThanOrEqual(eff, 85)
        XCTAssertFalse(rows.isEmpty)
    }

    // MARK: - ScoreEngine

    func testScoreEnginePleasantDayHighScore() {
        let r = ScoreEngine.compute(
            apparentF: 72,
            dryBulbF: 72,
            relativeHumidity: 45,
            windSpeedMph: 6,
            gustMph: 10,
            weatherCode: 0,
            usAQI: 25
        )
        XCTAssertGreaterThanOrEqual(r.score, 90)
    }

    func testScoreEngineExtremeHeatPenalty() {
        let r = ScoreEngine.compute(
            apparentF: 102,
            dryBulbF: 98,
            relativeHumidity: 40,
            windSpeedMph: 4,
            gustMph: nil,
            weatherCode: 0,
            usAQI: nil
        )
        XCTAssertLessThan(r.score, 70)
        XCTAssertTrue(r.bullets.contains { $0.lowercased().contains("heat") })
    }

    func testScoreEngineVerdictBands() {
        XCTAssertEqual(ScoreEngine.verdict(for: 90), "Good window to run.")
        XCTAssertEqual(ScoreEngine.verdict(for: 70), "Runnable; adjust pace and gear.")
        XCTAssertEqual(ScoreEngine.verdict(for: 50), "Challenging; choose safer routes.")
        XCTAssertEqual(ScoreEngine.verdict(for: 20), "Rough conditions; consider indoor backup.")
    }

    func testApplyWearableNoSignalLeavesScore() {
        let base = ScoreEngine.compute(
            apparentF: 70,
            dryBulbF: 70,
            relativeHumidity: 50,
            windSpeedMph: 5,
            gustMph: nil,
            weatherCode: 1,
            usAQI: 30
        )
        let empty = WearableRunReadiness(
            hrvSDNNMs: nil,
            hrvRmssdMilli: nil,
            sleepHours: nil,
            strainProxy0to21: nil,
            whoopCycleStrain: nil,
            readinessScore0to100: nil,
            sourceLabel: "None"
        )
        let merged = ScoreEngine.applyWearable(baseScore: base.score, bullets: base.bullets, wearable: empty)
        XCTAssertEqual(merged.score, base.score)
    }

    func testApplyWearableLowReadinessReducesScore() {
        let base = ScoreEngine.compute(
            apparentF: 70,
            dryBulbF: 70,
            relativeHumidity: 50,
            windSpeedMph: 5,
            gustMph: nil,
            weatherCode: 1,
            usAQI: 30
        )
        let low = WearableRunReadiness(
            hrvSDNNMs: nil,
            hrvRmssdMilli: nil,
            sleepHours: nil,
            strainProxy0to21: nil,
            whoopCycleStrain: nil,
            readinessScore0to100: 50,
            sourceLabel: "Test"
        )
        let merged = ScoreEngine.applyWearable(baseScore: base.score, bullets: base.bullets, wearable: low)
        XCTAssertLessThan(merged.score, base.score)
    }

    // MARK: - AwarenessEngine

    func testAwarenessDaytimeBaseline() {
        let r = AwarenessEngine.compute(
            isDay: 1,
            apparentF: 65,
            gustMph: 8,
            weatherCode: 1,
            usAQI: 40,
            alerts: [],
            crime: nil
        )
        XCTAssertGreaterThanOrEqual(r.score, 90)
    }

    func testAwarenessNightPenalty() {
        let day = AwarenessEngine.compute(
            isDay: 1,
            apparentF: 65,
            gustMph: 8,
            weatherCode: 1,
            usAQI: 40,
            alerts: [],
            crime: nil
        )
        let night = AwarenessEngine.compute(
            isDay: 0,
            apparentF: 65,
            gustMph: 8,
            weatherCode: 1,
            usAQI: 40,
            alerts: [],
            crime: nil
        )
        XCTAssertLessThan(night.score, day.score)
    }

    func testAwarenessSevereAlertPenalty() {
        let none = AwarenessEngine.compute(
            isDay: 1,
            apparentF: 65,
            gustMph: 8,
            weatherCode: 1,
            usAQI: 40,
            alerts: [],
            crime: nil
        )
        let severe = AwarenessEngine.compute(
            isDay: 1,
            apparentF: 65,
            gustMph: 8,
            weatherCode: 1,
            usAQI: 40,
            alerts: [NWSAlert(headline: "Warning", description: nil, severity: "Severe Thunderstorm")],
            crime: nil
        )
        XCTAssertLessThan(severe.score, none.score)
    }

    // MARK: - ConditionsError

    func testFetchByZipInvalidThrowsInvalidZip() async {
        do {
            _ = try await ConditionsService().fetchByZip("123")
            XCTFail("expected ConditionsError.invalidZip")
        } catch ConditionsError.invalidZip {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
