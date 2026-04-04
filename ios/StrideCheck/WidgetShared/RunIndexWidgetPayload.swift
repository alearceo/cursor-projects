import Foundation

/// Minimal run-index state written by the app and read by the widget extension.
struct RunIndexWidgetPayload: Codable, Equatable, Sendable {
    var score: Int
    var verdict: String
    var tierLabel: String
    /// Matches `RunIndexTier` cases for widget-side styling without duplicating score bands.
    var tier: RunIndexTierKind
    var contextLine: String
    var placeName: String
    var updatedAt: Date

    static let storageKey = "runIndexWidget.payload.v1"

    static func load() -> RunIndexWidgetPayload? {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return nil }
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(RunIndexWidgetPayload.self, from: data)
    }

    static func save(_ payload: RunIndexWidgetPayload) {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static var placeholder: RunIndexWidgetPayload {
        RunIndexWidgetPayload(
            score: 82,
            verdict: "Open StrideCheck to refresh.",
            tierLabel: "Strong",
            tier: .good,
            contextLine: "Open app to load conditions",
            placeName: "—",
            updatedAt: Date()
        )
    }
}

enum RunIndexTierKind: String, Codable, Sendable {
    case good
    case moderate
    case poor

    init(score: Int) {
        switch score {
        case 80...100: self = .good
        case 60..<80: self = .moderate
        default: self = .poor
        }
    }
}
