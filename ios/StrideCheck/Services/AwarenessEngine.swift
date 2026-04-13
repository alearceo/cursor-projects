import Foundation

enum AwarenessEngine {
    static func compute(
        isDay: Int?,
        apparentF: Double?,
        gustMph: Double?,
        weatherCode: Int?,
        usAQI: Double?,
        alerts: [NWSAlert],
        crime: CrimeIncidentsService.Summary?
    ) -> (score: Int, verdict: String, bullets: [String]) {
        var score = 100
        var bullets: [String] = []

        let night = (isDay == 0)
        if night {
            score -= 18
            bullets.append("After dark, visibility and surface cues drop; favor lit, familiar streets.")
        }

        if let code = weatherCode {
            if code == 45 || code == 48 {
                score -= 14
                bullets.append("Fog or low cloud base cuts sightlines; stay wider from traffic.")
            }
            if code >= 95 {
                score -= 28
                bullets.append("Storm conditions; postpone or shorten outdoor segments.")
            } else if isWet(code) {
                score -= 12
                bullets.append("Wet surfaces reduce grip; slow for paint, metal plates, and leaves.")
                if night {
                    score -= 10
                    bullets.append("Wet plus low light compounds crossing risk; use marked crosswalks.")
                }
            }
        }

        if let gust = gustMph, gust >= 36 {
            score -= 10
            bullets.append("Strong wind on open blocks can feel exposed; consider sheltered corridors.")
        }

        if let aqi = usAQI, aqi >= 151 {
            score -= 12
            bullets.append("Unhealthy air near traffic; shorten time on busy arterials.")
        }

        if let f = apparentF {
            if f >= 92 {
                score -= 8
                bullets.append("High heat load builds quickly; hydrate and pick shade.")
            } else if f <= 20 {
                score -= 8
                bullets.append("Cold stress; cover skin and watch for ice on bridges.")
            }
        }

        let severeAlert = alerts.contains { alert in
            let s = (alert.severity ?? "").lowercased()
            return s.contains("extreme") || s.contains("severe")
        }
        if severeAlert {
            score -= 12
            bullets.append("High-severity weather alerts are active; confirm timing before you leave.")
        } else if !alerts.isEmpty {
            score -= 4
            bullets.append("Weather alerts in effect; skim details before locking a route.")
        }

        if let crime {
            let n = crime.incidentCount
            if n >= 90 {
                score -= 30
                bullets.append(
                    "Crime feed: very high reported incident volume within ~\(Int(crime.radiusMiles)) mi over \(crime.windowDays) days; favor busier, well-lit routes you know."
                )
            } else if n >= 50 {
                score -= 22
                bullets.append(
                    "Crime feed: elevated reported incidents (~\(n) in ~\(Int(crime.radiusMiles)) mi / \(crime.windowDays) d); add daylight or a buddy if you feel unsure."
                )
            } else if n >= 25 {
                score -= 14
                bullets.append(
                    "Crime feed: moderate reported incidents (~\(n) nearby); stay aware at crossings and parking exits."
                )
            } else if n > 0 {
                score -= 6
                bullets.append(
                    "Crime feed: \(n) reported incidents in the search radius; cross-check local police or neighborhood sources."
                )
            } else {
                bullets.append(
                    "Crime feed: no incidents returned for this window — reporting may be sparse or filtered."
                )
            }
            bullets.append(
                "Reported incidents are incomplete, delayed, and vary by agency coverage — not a real-time personal safety guarantee."
            )
        }

        if bullets.isEmpty {
            bullets.append("Environmental cues look ordinary; still share plans if running solo.")
        }

        let finalScore = max(0, min(100, score))
        let verdict: String
        switch finalScore {
        case 80...100: verdict = "Environment favors confident pacing."
        case 60..<80: verdict = "Runnable with a few visibility or comfort cautions."
        case 40..<60: verdict = "More environmental friction; shorten or reroute."
        default: verdict = "Harsh conditions outdoors; delay or move inside."
        }
        return (finalScore, verdict, bullets)
    }

    private static func isWet(_ code: Int) -> Bool {
        (51...67).contains(code) || (71...77).contains(code) || (80...82).contains(code) || (85...99).contains(code)
    }
}
