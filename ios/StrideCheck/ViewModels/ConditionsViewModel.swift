import CoreLocation
import Foundation

@MainActor
final class ConditionsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var snapshot: ConditionsSnapshot?
    @Published var zipInput = ""

    private let service = ConditionsService()

    init() {
        snapshot = SnapshotCache.load()
    }

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
            let next = try await fetch()
            snapshot = next
            SnapshotCache.save(next)
            await RunWindowNotifier.considerNotifyIfStrongRun(score: next.score)
        } catch {
            errorMessage = error.localizedDescription
            if snapshot == nil {
                snapshot = SnapshotCache.load()
            }
        }
    }
}
