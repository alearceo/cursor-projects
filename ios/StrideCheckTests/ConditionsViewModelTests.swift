import CoreLocation
import XCTest
@testable import StrideCheck

/// First coordinate fetch sleeps, then returns `slow`; subsequent fetches return `fast` immediately.
private actor StaggeredCoordinateMock: ConditionsFetching {
    private var callCount = 0
    private let slow: ConditionsSnapshot
    private let fast: ConditionsSnapshot
    private let firstDelayNanoseconds: UInt64

    init(slow: ConditionsSnapshot, fast: ConditionsSnapshot, firstDelayNanoseconds: UInt64) {
        self.slow = slow
        self.fast = fast
        self.firstDelayNanoseconds = firstDelayNanoseconds
    }

    func fetchByZip(_ zip: String) async throws -> ConditionsSnapshot {
        throw ConditionsError.invalidZip
    }

    func fetchByCoordinate(
        latitude: Double,
        longitude: Double,
        fallbackName: String?,
        stateAbbrev: String?
    ) async throws -> ConditionsSnapshot {
        callCount += 1
        if callCount == 1 {
            try await Task.sleep(nanoseconds: firstDelayNanoseconds)
            return slow
        }
        return fast
    }
}

private actor CoordinateErrorMock: ConditionsFetching {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func fetchByZip(_ zip: String) async throws -> ConditionsSnapshot {
        throw ConditionsError.invalidZip
    }

    func fetchByCoordinate(
        latitude: Double,
        longitude: Double,
        fallbackName: String?,
        stateAbbrev: String?
    ) async throws -> ConditionsSnapshot {
        throw error
    }
}

private actor ZipErrorMock: ConditionsFetching {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func fetchByZip(_ zip: String) async throws -> ConditionsSnapshot {
        throw error
    }

    func fetchByCoordinate(
        latitude: Double,
        longitude: Double,
        fallbackName: String?,
        stateAbbrev: String?
    ) async throws -> ConditionsSnapshot {
        XCTFail("fetchByCoordinate should not be called")
        throw ConditionsError.invalidResponse
    }
}

@MainActor
final class ConditionsViewModelTests: XCTestCase {

    func testOverlappingLoadsKeepLatestCompletedResult() async {
        let slow = makeSnapshot(placeName: "First")
        let fast = makeSnapshot(placeName: "Second")
        let mock = await StaggeredCoordinateMock(
            slow: slow,
            fast: fast,
            firstDelayNanoseconds: 400_000_000
        )
        let vm = ConditionsViewModel(conditionsService: mock)
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -86.0)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await vm.loadForCurrentLocation(coord) }
            group.addTask { await vm.loadForCurrentLocation(coord) }
        }
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.snapshot?.placeName, "Second")
        XCTAssertNil(vm.errorMessage)
    }

    func testURLErrorCancelledDoesNotSetErrorMessage() async {
        let mock = await CoordinateErrorMock(error: URLError(.cancelled))
        let vm = ConditionsViewModel(conditionsService: mock)
        let coord = CLLocationCoordinate2D(latitude: 41.0, longitude: -87.0)
        await vm.loadForCurrentLocation(coord)
        XCTAssertNil(vm.errorMessage)
    }

    func testConditionsErrorInvalidZipMapsToDescription() async {
        let mock = await ZipErrorMock(error: ConditionsError.invalidZip)
        let vm = ConditionsViewModel(conditionsService: mock)
        vm.zipInput = "12345"
        await vm.loadForZip()
        XCTAssertEqual(vm.errorMessage, "Zip code is invalid.")
    }

    func testUnknownNSErrorMapsToGenericMessage() async {
        let mock = await ZipErrorMock(error: NSError(domain: "TestDomain", code: 42))
        let vm = ConditionsViewModel(conditionsService: mock)
        vm.zipInput = "12345"
        await vm.loadForZip()
        XCTAssertEqual(
            vm.errorMessage,
            "Couldn’t refresh conditions. Check your connection and try again."
        )
    }

    private func makeSnapshot(placeName: String) -> ConditionsSnapshot {
        ConditionsSnapshot(
            placeName: placeName,
            latitude: 39.165,
            longitude: -86.526,
            stateAbbrev: "IN",
            score: 70,
            verdict: "Good conditions",
            bullets: ["Low wind"],
            wearableRows: [],
            awarenessScore: 70,
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
