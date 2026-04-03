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
            guard !isBenignCancellation(error) else { return }
            errorMessage = error.localizedDescription
            if snapshot == nil {
                snapshot = SnapshotCache.load()
            }
        }
    }

    /// Pull-to-refresh and overlapping loads cancel the previous task; that must not surface as a user-visible error.
    private func isBenignCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}
