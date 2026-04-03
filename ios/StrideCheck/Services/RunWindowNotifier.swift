import Foundation
import UserNotifications

/// Throttled local notification when the run index is strong (user opt-in via `stridecheck.notifyRunWindows` in `UserDefaults`).
enum RunWindowNotifier {
    private static let prefsKey = "stridecheck.notifyRunWindows"
    private static let lastNotifyKey = "stridecheck.lastGoodWindowNotify"
    private static let minScore = 78
    private static let throttleSeconds: TimeInterval = 12 * 3600

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    /// Call after a successful conditions refresh.
    static func considerNotifyIfStrongRun(score: Int) async {
        guard UserDefaults.standard.bool(forKey: prefsKey) else { return }
        guard score >= minScore else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let now = Date()
        if let last = UserDefaults.standard.object(forKey: lastNotifyKey) as? Date,
           now.timeIntervalSince(last) < throttleSeconds {
            return
        }

        UserDefaults.standard.set(now, forKey: lastNotifyKey)

        let content = UNMutableNotificationContent()
        content.title = "StrideCheck"
        content.body = "Run index is \(score) — conditions look strong. Open the app for details."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "stridecheck-good-window", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
