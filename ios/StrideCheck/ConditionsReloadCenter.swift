import Combine
import Foundation

/// Central place to request a conditions snapshot refetch after wearable credentials, toggles, or similar change.
/// `ContentView` observes `token` and reloads when it advances.
@MainActor
final class ConditionsReloadCenter: ObservableObject {
    static let shared = ConditionsReloadCenter()

    @Published private(set) var token: UInt = 0

    private init() {}

    func requestReload() {
        token &+= 1
    }
}
