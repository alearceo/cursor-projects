import Foundation

enum ScoreEngine {
    static func compute(
        apparentF: Double?,
        dryBulbF: Double?,
        relativeHumidity: Double?,
        windSpeedMph: Double?,
        gustMph: Double?,
        weatherCode: Int?,
        usAQI: Double?
    ) -> (score: Int, bullets: [String]) {
        var score = 100
        var bullets: [String] = []

        let stress = HeatColdStress.effectiveFeelsLikeForRunIndex(
            apparentF: apparentF,
            dryBulbF: dryBulbF,
            relativeHumidityPercent: relativeHumidity,
            windSpeedMph: windSpeedMph
        )
        let f = stress.effectiveF

        if f >= 100 {
            score -= 34
            bullets.append("Extreme effective heat; avoid hard efforts and seek shade.")
        } else if f >= 95 {
            score -= 30
            bullets.append("Very hot effective temperature; hydrate and reduce effort.")
        } else if f >= 90 {
            score -= 26
            bullets.append("Strong heat stress; slow pace and carry fluids.")
        } else if f >= 88 {
            score -= 22
            bullets.append("High heat load; prioritize shade and fluids.")
        } else if f >= 82 {
            score -= 12
            bullets.append("Warm/humid effective conditions; expect higher perceived effort.")
        } else if f >= 75 {
            score -= 4
            bullets.append("Mild warmth; still monitor hydration on long runs.")
        } else if f <= 0 {
            score -= 34
            bullets.append("Dangerous cold effective temperature; limit exposed skin.")
        } else if f <= 10 {
            score -= 30
            bullets.append("Severe cold stress; bundle and watch footing.")
        } else if f <= 14 {
            score -= 28
            bullets.append("Bitter cold; cover skin and watch for slick surfaces.")
        } else if f <= 28 {
            score -= 16
            bullets.append("Freezing possible; be careful on bridges and painted lines.")
        } else if f <= 40 {
            score -= 8
            bullets.append("Cool effective air; gloves or layers may help.")
        }

        if let gust = gustMph {
            if gust >= 40 {
                score -= 24
                bullets.append("Strong gusts; route away from exposed corridors.")
            } else if gust >= 32 {
                score -= 14
                bullets.append("Gusty winds; expect unstable footing in open blocks.")
            } else if gust >= 25 {
                score -= 8
                bullets.append("Breezy conditions may affect pace consistency.")
            }
        }

        if let code = weatherCode {
            if code >= 95 {
                score -= 35
                bullets.append("Thunderstorm risk; postpone if lightning is nearby.")
            } else if [65, 75, 82, 86].contains(code) {
                score -= 28
                bullets.append("Heavy precipitation; slippery surfaces likely.")
            } else if isWet(code) {
                score -= 18
                bullets.append("Wet roads; increase caution at crossings and turns.")
            } else if code == 45 || code == 48 {
                score -= 10
                bullets.append("Low visibility; choose well-lit, lower-traffic routes.")
            }
        }

        if let aqi = usAQI {
            if aqi >= 151 {
                score -= 30
                bullets.append("Unhealthy AQI; shorten run or move indoors.")
            } else if aqi >= 101 {
                score -= 18
                bullets.append("Sensitive groups should limit prolonged effort.")
            } else if aqi >= 51 {
                score -= 6
                bullets.append("Moderate AQI; monitor effort near heavy traffic.")
            }
        }

        if bullets.isEmpty {
            bullets.append("Conditions look favorable for a city run.")
        }

        return (max(0, min(100, score)), bullets)
    }

    static func applyWearable(
        baseScore: Int,
        bullets: [String],
        wearable: WearableRunReadiness
    ) -> (score: Int, bullets: [String], rows: [(String, String)]) {
        var score = baseScore
        var b = bullets
        var rows: [(String, String)] = [("Data source", wearable.sourceLabel)]

        let hasSignal = wearable.readinessScore0to100 != nil
            || wearable.sleepHours != nil
            || wearable.hrvSDNNMs != nil
            || wearable.hrvRmssdMilli != nil
            || wearable.strainProxy0to21 != nil
            || wearable.whoopCycleStrain != nil

        guard hasSignal else {
            return (score, b, rows)
        }

        var delta = 0

        if let r = wearable.readinessScore0to100 {
            rows.append(("Recovery score", "\(r)"))
            if r < 55 {
                delta -= 14
                b.append("Wearables: readiness is low; shorten intensity until you rebound.")
            } else if r < 72 {
                delta -= 7
                b.append("Wearables: readiness is middling; cap hard intervals.")
            }
        }

        if let h = wearable.sleepHours {
            rows.append(("Recent sleep", String(format: "%.1f h", h)))
            if h < 5 {
                delta -= 12
                b.append("Wearables: sleep looks short; prioritize easy effort.")
            } else if h < 6.2 {
                delta -= 6
                b.append("Wearables: lighter sleep; keep the run conversational.")
            }
        }

        if let rm = wearable.hrvRmssdMilli {
            rows.append(("HRV (Whoop RMSSD)", String(format: "%.0f ms", rm)))
            if rm < 20 {
                delta -= 8
                b.append("Wearables: HRV (RMSSD) looks low; favor recovery pacing.")
            } else if rm < 30 {
                delta -= 4
            }
        } else if let hrv = wearable.hrvSDNNMs {
            rows.append(("HRV (SDNN)", String(format: "%.0f ms", hrv)))
            if hrv < 22 {
                delta -= 8
                b.append("Wearables: HRV looks suppressed; favor recovery pacing.")
            } else if hrv < 32 {
                delta -= 4
            }
        }

        if let ws = wearable.whoopCycleStrain {
            rows.append(("Whoop strain", String(format: "%.1f / 21", min(21, ws))))
            if ws >= 16 {
                delta -= 8
                b.append("Wearables: prior-day strain is high; ease today’s training.")
            } else if ws >= 12 {
                delta -= 4
            }
        } else if let s = wearable.strainProxy0to21 {
            rows.append(("Strain proxy", String(format: "%.0f / 21", min(21, s))))
            if s >= 16 {
                delta -= 8
                b.append("Wearables: prior-day load looks high; ease today’s training.")
            } else if s >= 12 {
                delta -= 4
            }
        }

        score = max(0, min(100, score + delta))
        return (score, b, rows)
    }

    static func verdict(for score: Int) -> String {
        switch score {
        case 80...100: return "Good window to run."
        case 60..<80: return "Runnable; adjust pace and gear."
        case 40..<60: return "Challenging; choose safer routes."
        default: return "Rough conditions; consider indoor backup."
        }
    }

    private static func isWet(_ code: Int) -> Bool {
        return (51...67).contains(code) || (71...77).contains(code) || (80...82).contains(code) || (85...99).contains(code)
    }
}

