import XCTest
@testable import StrideCheck

/// Tests for SnapshotCache encode/decode round-trip and freshness timestamp.
///
/// To run these tests:
/// 1. In Xcode, add a new Unit Test target named `StrideCheckTests`.
/// 2. Add this file and all other files in `ios/StrideCheckTests/` to the target.
/// 3. Set the Host Application to `StrideCheck`.
/// 4. Run with Cmd+U or via the CI workflow.
final class SnapshotCacheTests: XCTestCase {

    func testSaveAndLoadRoundTrip() throws {
        let snapshot = makeSnapshot(score: 81, awarenessScore: 74, placeName: "Test City, IN")

        SnapshotCache.save(snapshot)
        let loaded = SnapshotCache.load()

        XCTAssertNotNil(loaded, "Loaded snapshot should not be nil after save")
        XCTAssertEqual(loaded?.score, 81)
        XCTAssertEqual(loaded?.awarenessScore, 74)
        XCTAssertEqual(loaded?.placeName, "Test City, IN")
    }

    func testCachedAtIsSetAfterSave() throws {
        let before = Date()
        let snapshot = makeSnapshot(score: 50, awarenessScore: 60, placeName: "Somewhere")
        SnapshotCache.save(snapshot)
        let after = Date()

        let loaded = SnapshotCache.load()
        XCTAssertNotNil(loaded?.cachedAt)
        if let cachedAt = loaded?.cachedAt {
            XCTAssertTrue(cachedAt >= before && cachedAt <= after,
                          "cachedAt should be set to approximately the save time")
        }
    }

    func testFormattedSavedAtIsNonEmpty() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let formatted = SnapshotCache.formattedSavedAt(date)
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Helpers

    private func makeSnapshot(score: Int, awarenessScore: Int, placeName: String) -> ConditionsSnapshot {
        ConditionsSnapshot(
            placeName: placeName,
            latitude: 39.165,
            longitude: -86.526,
            stateAbbrev: "IN",
            score: score,
            verdict: "Good conditions",
            bullets: ["Low wind", "Clear skies"],
            wearableRows: [],
            awarenessScore: awarenessScore,
            awarenessVerdict: "Route looks clear",
            awarenessBullets: [],
            currentRows: [("Feels Like", "62°F")],
            airRows: [("US AQI", "28")],
            hourly: [],
            alerts: [],
            cachedAt: nil,
            showRunIndexDataSourcesHint: false
        )
    }
}
