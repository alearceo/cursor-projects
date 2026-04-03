import Foundation

@MainActor
final class StravaLinkViewModel: ObservableObject {
    @Published private(set) var isConnected = false
    @Published var isBusy = false
    @Published var lastError: String?
    /// Bumps when the user requests a fresh polyline fetch (Route tab or Map data sources).
    @Published private(set) var mapDataRefreshGeneration = 0

    func refreshConnectionState() {
        isConnected = KeychainCredentialStore.string(for: .stravaAccessToken) != nil
    }

    func connect() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await StravaOAuthService.signInInteractively()
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        StravaOAuthService.disconnect()
        isConnected = false
        lastError = nil
    }

    func requestMapDataRefresh() {
        mapDataRefreshGeneration += 1
    }
}
