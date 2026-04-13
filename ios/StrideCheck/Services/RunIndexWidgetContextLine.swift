import Foundation

/// Short summary for the Run Index widget (environment + wearable hint). Uses a newline between clauses so the widget wraps on a predictable break instead of mid-phrase.
enum RunIndexWidgetContextLine {
    static func build(from snap: ConditionsSnapshot) -> String {
        let env = environmentClause(snap)
        let body = bodyClause(snap)
        if body.isEmpty { return env }
        return "\(env)\n\(body)"
    }

    private static func environmentClause(_ snap: ConditionsSnapshot) -> String {
        let feelsRaw = snap.currentRows.first { $0.0 == "Feels Like" }?.1 ?? ""
        let feels = parseFeelsLikeF(feelsRaw)
        let condRaw = snap.currentRows.first { $0.0 == "Conditions" }?.1 ?? ""
        let cond = condRaw.trimmingCharacters(in: .whitespaces)
        let condText: String = {
            guard let i = cond.firstIndex(where: { $0.isLetter || $0.isNumber }) else { return cond }
            return String(cond[i...])
        }()
        let humidityRaw = snap.currentRows.first { $0.0 == "Humidity" }?.1 ?? ""
        let humidity = parseHumidityPercent(humidityRaw)

        let thermal: String
        if let f = feels {
            switch f {
            case ..<36: thermal = "Frigid"
            case ..<46: thermal = "Cold"
            case ..<55: thermal = "Cool"
            case ..<65: thermal = "Mild"
            case ..<76: thermal = "Warm"
            case ..<88: thermal = "Hot"
            default: thermal = "Very hot"
            }
        } else {
            thermal = "Conditions"
        }

        let moisture: String
        let lower = condText.lowercased()
        if lower.contains("thunder") || lower.contains("storm") {
            moisture = "storms"
        } else if lower.contains("snow") || lower.contains("ice") {
            moisture = "wintry"
        } else if lower.contains("rain") || lower.contains("drizzle") || lower.contains("shower") {
            moisture = "wet"
        } else if lower.contains("fog") {
            moisture = "foggy"
        } else if let h = humidity, h >= 72 {
            moisture = "humid"
        } else {
            moisture = "dry"
        }

        return "\(thermal) & \(moisture)"
    }

    private static func bodyClause(_ snap: ConditionsSnapshot) -> String {
        let sourceRow = snap.wearableRows.first { $0.0 == "Data source" }?.1 ?? ""
        if sourceRow.contains("No wearable signal") {
            return "Open app for readiness"
        }

        let shortBrand = shortSourceLabel(sourceRow)
        if let rec = recoveryScore(from: snap.wearableRows) {
            let tag: String
            if rec >= 72 {
                tag = "recovery OK"
            } else if rec >= 55 {
                tag = "recovery fair"
            } else {
                tag = "recovery low"
            }
            if shortBrand.isEmpty { return tag }
            return "\(shortBrand) \(tag)"
        }

        if snap.wearableRows.contains(where: { $0.0 == "Recent sleep" }) {
            return shortBrand.isEmpty ? "Sleep on file" : "\(shortBrand) sleep"
        }

        return shortBrand.isEmpty ? "" : "\(shortBrand) linked"
    }

    private static func recoveryScore(from rows: [(String, String)]) -> Int? {
        guard let raw = rows.first(where: { $0.0 == "Recovery score" })?.1 else { return nil }
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty, let v = Int(digits) else { return nil }
        return v
    }

    /// Primary source for a short widget phrase (matches comma-separated `WearableReadinessAggregator` labels).
    private static func shortSourceLabel(_ label: String) -> String {
        let t = label.trimmingCharacters(in: .whitespaces)
        if t.lowercased().hasPrefix("no wearable signal") { return "" }
        guard let first = t.split(separator: ",").first else { return t }
        return first.trimmingCharacters(in: .whitespaces)
    }

    private static func parseFeelsLikeF(_ s: String) -> Int? {
        let digits = s.prefix { $0.isNumber || $0 == "-" }
        return Int(digits)
    }

    private static func parseHumidityPercent(_ s: String) -> Int? {
        let digits = s.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }
}
