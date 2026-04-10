import Foundation

/// Abstraction over [`ConditionsService`](ConditionsService.swift) for tests and previews.
protocol ConditionsFetching: Sendable {
    func fetchByZip(_ zip: String) async throws -> ConditionsSnapshot
    func fetchByCoordinate(
        latitude: Double,
        longitude: Double,
        fallbackName: String?,
        stateAbbrev: String?
    ) async throws -> ConditionsSnapshot
}

extension ConditionsFetching {
    func fetchByCoordinate(latitude: Double, longitude: Double) async throws -> ConditionsSnapshot {
        try await fetchByCoordinate(latitude: latitude, longitude: longitude, fallbackName: nil, stateAbbrev: nil)
    }
}

extension ConditionsService: ConditionsFetching {}
