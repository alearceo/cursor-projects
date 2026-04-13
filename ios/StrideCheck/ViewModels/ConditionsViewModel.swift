import CoreLocation
import Foundation

@MainActor
final class ConditionsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var snapshot: ConditionsSnapshot?
    @Published var zipInput = ""

    private let service: any ConditionsFetching
    /// Supersedes in-flight loads when pull-to-refresh overlaps location updates (or vice versa).
    private var loadSequence = 0

    init(conditionsService: any ConditionsFetching = ConditionsService()) {
        self.service = conditionsService
        snapshot = SnapshotCache.load()
        if let snap = snapshot {
            RunIndexWidgetExporter.publish(snap)
        }
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
        loadSequence += 1
        let seq = loadSequence

        isLoading = true
        errorMessage = nil
        defer {
            if loadSequence == seq {
                isLoading = false
            }
        }

        do {
            let next = try await fetch()
            guard seq == loadSequence else { return }
            snapshot = next
            SnapshotCache.save(next)
            RunIndexWidgetExporter.publish(next)
            await RunWindowNotifier.considerNotifyIfStrongRun(score: next.score)
        } catch {
            guard seq == loadSequence else { return }
            guard !isBenignCancellation(error) else { return }
            errorMessage = Self.userFacingLoadError(error)
            if snapshot == nil {
                snapshot = SnapshotCache.load()
            }
        }
    }

    private static func userFacingLoadError(_ error: Error) -> String {
        if let conditions = error as? ConditionsError {
            return conditions.errorDescription ?? "Couldn’t refresh conditions. Check your connection and try again."
        }
        if error is CancellationError {
            return "Request was cancelled."
        }
        if let url = error as? URLError, url.code == .cancelled {
            return "Request was cancelled."
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
            return "Request was cancelled."
        }
        return "Couldn’t refresh conditions. Check your connection and try again."
    }

    /// Pull-to-refresh and overlapping loads cancel the previous task; that must not surface as a user-visible error.
    private func isBenignCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}
