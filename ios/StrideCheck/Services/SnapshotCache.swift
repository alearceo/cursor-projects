import Foundation

private struct StringPair: Codable {
    let key: String
    let value: String
}

private struct HourlyPersisted: Codable {
    let timeLabel: String
    let icon: String
    let rainChanceLabel: String
}

private struct AlertPersisted: Codable {
    let headline: String
    let description: String?
    let severity: String?
}

private struct PersistedConditionsSnapshot: Codable {
    let placeName: String
    let latitude: Double
    let longitude: Double
    let stateAbbrev: String?
    let score: Int
    let verdict: String
    let bullets: [String]
    let wearableRows: [StringPair]
    let awarenessScore: Int
    let awarenessVerdict: String
    let awarenessBullets: [String]
    let currentRows: [StringPair]
    let airRows: [StringPair]
    let hourly: [HourlyPersisted]
    let alerts: [AlertPersisted]
    let savedAt: Date
    let showRunIndexDataSourcesHint: Bool

    enum CodingKeys: String, CodingKey {
        case placeName, latitude, longitude, stateAbbrev, score, verdict, bullets, wearableRows
        case awarenessScore, awarenessVerdict, awarenessBullets
        case currentRows, airRows, hourly, alerts, savedAt
        case showRunIndexDataSourcesHint
    }

    init(
        placeName: String,
        latitude: Double,
        longitude: Double,
        stateAbbrev: String?,
        score: Int,
        verdict: String,
        bullets: [String],
        wearableRows: [StringPair],
        awarenessScore: Int,
        awarenessVerdict: String,
        awarenessBullets: [String],
        currentRows: [StringPair],
        airRows: [StringPair],
        hourly: [HourlyPersisted],
        alerts: [AlertPersisted],
        savedAt: Date,
        showRunIndexDataSourcesHint: Bool
    ) {
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.stateAbbrev = stateAbbrev
        self.score = score
        self.verdict = verdict
        self.bullets = bullets
        self.wearableRows = wearableRows
        self.awarenessScore = awarenessScore
        self.awarenessVerdict = awarenessVerdict
        self.awarenessBullets = awarenessBullets
        self.currentRows = currentRows
        self.airRows = airRows
        self.hourly = hourly
        self.alerts = alerts
        self.savedAt = savedAt
        self.showRunIndexDataSourcesHint = showRunIndexDataSourcesHint
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        placeName = try c.decode(String.self, forKey: .placeName)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        stateAbbrev = try c.decodeIfPresent(String.self, forKey: .stateAbbrev)
        score = try c.decode(Int.self, forKey: .score)
        verdict = try c.decode(String.self, forKey: .verdict)
        bullets = try c.decode([String].self, forKey: .bullets)
        wearableRows = try c.decodeIfPresent([StringPair].self, forKey: .wearableRows) ?? []
        awarenessScore = try c.decodeIfPresent(Int.self, forKey: .awarenessScore) ?? 70
        awarenessVerdict = try c.decodeIfPresent(String.self, forKey: .awarenessVerdict)
            ?? "Update for the latest awareness index."
        awarenessBullets = try c.decodeIfPresent([String].self, forKey: .awarenessBullets) ?? []
        currentRows = try c.decode([StringPair].self, forKey: .currentRows)
        airRows = try c.decode([StringPair].self, forKey: .airRows)
        hourly = try c.decode([HourlyPersisted].self, forKey: .hourly)
        alerts = try c.decode([AlertPersisted].self, forKey: .alerts)
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        showRunIndexDataSourcesHint = try c.decodeIfPresent(Bool.self, forKey: .showRunIndexDataSourcesHint) ?? false
    }
}

enum SnapshotCache {
    private static var fileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = dir.appendingPathComponent("StrideCheck", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("last-snapshot.json")
    }

    static func save(_ snapshot: ConditionsSnapshot) {
        guard let fileURL else { return }
        let persisted = PersistedConditionsSnapshot(
            placeName: snapshot.placeName,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            stateAbbrev: snapshot.stateAbbrev,
            score: snapshot.score,
            verdict: snapshot.verdict,
            bullets: snapshot.bullets,
            wearableRows: snapshot.wearableRows.map { StringPair(key: $0.0, value: $0.1) },
            awarenessScore: snapshot.awarenessScore,
            awarenessVerdict: snapshot.awarenessVerdict,
            awarenessBullets: snapshot.awarenessBullets,
            currentRows: snapshot.currentRows.map { StringPair(key: $0.0, value: $0.1) },
            airRows: snapshot.airRows.map { StringPair(key: $0.0, value: $0.1) },
            hourly: snapshot.hourly.map { HourlyPersisted(timeLabel: $0.timeLabel, icon: $0.icon, rainChanceLabel: $0.rainChanceLabel) },
            alerts: snapshot.alerts.map { AlertPersisted(headline: $0.headline, description: $0.description, severity: $0.severity) },
            savedAt: Date(),
            showRunIndexDataSourcesHint: snapshot.showRunIndexDataSourcesHint
        )
        do {
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort — failure is non-fatal
        }
    }

    static func load() -> ConditionsSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let p = try? JSONDecoder().decode(PersistedConditionsSnapshot.self, from: data) else { return nil }
        return ConditionsSnapshot(
            placeName: p.placeName,
            latitude: p.latitude,
            longitude: p.longitude,
            stateAbbrev: p.stateAbbrev,
            score: p.score,
            verdict: p.verdict,
            bullets: p.bullets,
            wearableRows: p.wearableRows.map { ($0.key, $0.value) },
            awarenessScore: p.awarenessScore,
            awarenessVerdict: p.awarenessVerdict,
            awarenessBullets: p.awarenessBullets,
            currentRows: p.currentRows.map { ($0.key, $0.value) },
            airRows: p.airRows.map { ($0.key, $0.value) },
            hourly: p.hourly.map { HourlyDisplay(timeLabel: $0.timeLabel, icon: $0.icon, rainChanceLabel: $0.rainChanceLabel) },
            alerts: p.alerts.map { NWSAlert(headline: $0.headline, description: $0.description, severity: $0.severity) },
            cachedAt: p.savedAt,
            showRunIndexDataSourcesHint: p.showRunIndexDataSourcesHint
        )
    }

    static func formattedSavedAt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
