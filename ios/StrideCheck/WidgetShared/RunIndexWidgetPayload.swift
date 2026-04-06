import Foundation

/// Key/value row mirrored from `ConditionsSnapshot` for widget detail pages.
struct WidgetRowPair: Codable, Equatable, Hashable, Sendable {
    let key: String
    let value: String
}

/// Run-index state written by the app and read by the widget extension (includes paged detail rows).
struct RunIndexWidgetPayload: Codable, Equatable, Sendable {
    var score: Int
    var verdict: String
    var tierLabel: String
    /// Matches `RunIndexTier` cases for widget-side styling without duplicating score bands.
    var tier: RunIndexTierKind
    var contextLine: String
    var placeName: String
    var updatedAt: Date
    var bullets: [String]
    var wearableRows: [WidgetRowPair]
    var currentRows: [WidgetRowPair]
    var airRows: [WidgetRowPair]
    /// Route awareness score (0–100) and tier label (same bands as run index).
    var awarenessScore: Int
    var awarenessTierLabel: String

    enum CodingKeys: String, CodingKey {
        case score, verdict, tierLabel, tier, contextLine, placeName, updatedAt
        case bullets, wearableRows, currentRows, airRows
        case awarenessScore, awarenessTierLabel
    }

    init(
        score: Int,
        verdict: String,
        tierLabel: String,
        tier: RunIndexTierKind,
        contextLine: String,
        placeName: String,
        updatedAt: Date,
        bullets: [String] = [],
        wearableRows: [WidgetRowPair] = [],
        currentRows: [WidgetRowPair] = [],
        airRows: [WidgetRowPair] = [],
        awarenessScore: Int = 0,
        awarenessTierLabel: String = "—"
    ) {
        self.score = score
        self.verdict = verdict
        self.tierLabel = tierLabel
        self.tier = tier
        self.contextLine = contextLine
        self.placeName = placeName
        self.updatedAt = updatedAt
        self.bullets = bullets
        self.wearableRows = wearableRows
        self.currentRows = currentRows
        self.airRows = airRows
        self.awarenessScore = awarenessScore
        self.awarenessTierLabel = awarenessTierLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = try c.decode(Int.self, forKey: .score)
        verdict = try c.decode(String.self, forKey: .verdict)
        tierLabel = try c.decode(String.self, forKey: .tierLabel)
        tier = try c.decode(RunIndexTierKind.self, forKey: .tier)
        contextLine = try c.decode(String.self, forKey: .contextLine)
        placeName = try c.decode(String.self, forKey: .placeName)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        bullets = try c.decodeIfPresent([String].self, forKey: .bullets) ?? []
        wearableRows = try c.decodeIfPresent([WidgetRowPair].self, forKey: .wearableRows) ?? []
        currentRows = try c.decodeIfPresent([WidgetRowPair].self, forKey: .currentRows) ?? []
        airRows = try c.decodeIfPresent([WidgetRowPair].self, forKey: .airRows) ?? []
        awarenessScore = try c.decodeIfPresent(Int.self, forKey: .awarenessScore) ?? 0
        awarenessTierLabel = try c.decodeIfPresent(String.self, forKey: .awarenessTierLabel) ?? "—"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(score, forKey: .score)
        try c.encode(verdict, forKey: .verdict)
        try c.encode(tierLabel, forKey: .tierLabel)
        try c.encode(tier, forKey: .tier)
        try c.encode(contextLine, forKey: .contextLine)
        try c.encode(placeName, forKey: .placeName)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(bullets, forKey: .bullets)
        try c.encode(wearableRows, forKey: .wearableRows)
        try c.encode(currentRows, forKey: .currentRows)
        try c.encode(airRows, forKey: .airRows)
        try c.encode(awarenessScore, forKey: .awarenessScore)
        try c.encode(awarenessTierLabel, forKey: .awarenessTierLabel)
    }

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
            contextLine: "Cool & dry\nWhoop",
            placeName: "—",
            updatedAt: Date(),
            bullets: ["Good window to run.", "Breezy — dress for wind."],
            wearableRows: [
                WidgetRowPair(key: "Data source", value: "Whoop"),
                WidgetRowPair(key: "Recovery score", value: "68")
            ],
            currentRows: [
                WidgetRowPair(key: "Feels Like", value: "50°F"),
                WidgetRowPair(key: "Conditions", value: "Clear")
            ],
            airRows: [
                WidgetRowPair(key: "US AQI", value: "32")
            ],
            awarenessScore: 72,
            awarenessTierLabel: "Mixed"
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
