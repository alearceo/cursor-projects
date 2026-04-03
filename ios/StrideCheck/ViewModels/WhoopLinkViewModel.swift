import Foundation

@MainActor
final class WhoopLinkViewModel: ObservableObject {
    @Published private(set) var isConnected = false
    @Published var isBusy = false
    @Published var lastError: String?

    func refreshConnectionState() {
        isConnected = KeychainCredentialStore.string(for: .whoopAccessToken) != nil
    }

    func connect() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await WhoopOAuthService.signInInteractively()
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        WhoopOAuthService.disconnect()
        isConnected = false
        lastError = nil
    }
}
