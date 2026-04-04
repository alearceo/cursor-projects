import Foundation

/// NWS **heat index** and **wind chill** layered on Open-Meteo’s `apparent_temperature` for run-index scoring.
enum HeatColdStress {
    /// Rothfusz regression (°F), valid for T ≥ 80°F; returns nil outside a typical range.
    static func nwsHeatIndexF(dryBulbF: Double, relativeHumidityPercent: Double) -> Double? {
        guard dryBulbF >= 80, relativeHumidityPercent >= 0, relativeHumidityPercent <= 100 else { return nil }
        let T = dryBulbF
        let R = relativeHumidityPercent
        guard T <= 140 else { return nil }

        let c1: Double = -42.379
        let c2: Double = 2.04901523 * T
        let c3: Double = 10.14333127 * R
        let c4: Double = -0.22475541 * T * R
        let c5: Double = -6.83783e-3 * T * T
        let c6: Double = -5.481717e-2 * R * R
        let c7: Double = 1.22874e-3 * T * T * R
        let c8: Double = 8.5282e-4 * T * R * R
        let c9: Double = -1.99e-6 * T * T * R * R
        let hi = c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9
        guard hi.isFinite else { return nil }
        return hi
    }

    /// NWS wind chill (°F) for T ≤ 50°F and wind ≥ 3 mph.
    static func nwsWindChillF(dryBulbF: Double, windSpeedMph: Double) -> Double? {
        guard dryBulbF <= 50, windSpeedMph >= 3 else { return nil }
        let V = pow(windSpeedMph, 0.16)
        let wc = 35.74 + 0.6215 * dryBulbF - 35.75 * V + 0.4275 * dryBulbF * V
        guard wc.isFinite else { return nil }
        return wc
    }

    /// Effective “how it feels” for **run index** math: start from Open-Meteo feels-like, then use the **more stressful** of heat index (humid heat) or wind chill (cold wind) when applicable.
    static func effectiveFeelsLikeForRunIndex(
        apparentF: Double?,
        dryBulbF: Double?,
        relativeHumidityPercent: Double?,
        windSpeedMph: Double?
    ) -> (effectiveF: Double, comfortRows: [(String, String)]) {
        guard let tDry = dryBulbF else {
            let v = apparentF ?? 60
            return (v, [("Heat/cold (run index)", String(format: "%.0f°F effective (feels-like only)", v))])
        }

        var effective = apparentF ?? tDry
        var parts: [String] = []

        if let a = apparentF {
            parts.append(String(format: "feels-like %.0f°F", a))
        } else {
            parts.append(String(format: "air %.0f°F", tDry))
        }

        if let rh = relativeHumidityPercent, let hi = nwsHeatIndexF(dryBulbF: tDry, relativeHumidityPercent: rh) {
            parts.append(String(format: "HI %.0f°F", hi))
            if hi > effective {
                effective = hi
            }
        }

        if let wind = windSpeedMph, let wc = nwsWindChillF(dryBulbF: tDry, windSpeedMph: wind) {
            parts.append(String(format: "wind chill %.0f°F", wc))
            if wc < effective {
                effective = wc
            }
        }

        let summary = parts.joined(separator: " · ")
        let rows: [(String, String)] = [
            ("Heat/cold (run index)", String(format: "%.0f°F effective", effective)),
            ("Heat/cold detail", summary)
        ]
        return (effective, rows)
    }
}
