import Foundation

@MainActor
final class GarminLinkViewModel: ObservableObject {
    @Published private(set) var isConnected = false
    @Published var isBusy = false
    @Published var lastError: String?

    func refreshConnectionState() {
        isConnected = KeychainCredentialStore.string(for: .garminAccessToken) != nil
    }

    func connect() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await GarminOAuthService.signInInteractively()
            isConnected = true
            WearableRunIndexPreferences.includeGarminInRunIndex = true
            ConditionsSnapshotReload.request()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        GarminOAuthService.disconnect()
        WearableRunIndexPreferences.includeGarminInRunIndex = false
        isConnected = false
        lastError = nil
        ConditionsSnapshotReload.request()
    }
}
