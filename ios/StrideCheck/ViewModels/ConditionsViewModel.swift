import CoreLocation
import Foundation

@MainActor
final class ConditionsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var snapshot: ConditionsSnapshot?
    @Published var zipInput = ""

    private let service = ConditionsService()

    func loadForCurrentLocation(_ coordinate: CLLocationCoordinate2D) async {
        await load {
            try await service.fetchByCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    func loadForZip() async {
        await load {
            try await service.fetchByZip(zipInput.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func load(fetch: () async throws -> ConditionsSnapshot) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try await fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
