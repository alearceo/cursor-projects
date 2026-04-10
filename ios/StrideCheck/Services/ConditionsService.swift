import CoreLocation
import Foundation

enum ConditionsError: LocalizedError {
    case invalidZip
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidZip:
            return "Zip code is invalid."
        case .invalidResponse:
            return "Could not decode conditions response."
        }
    }
}

struct ConditionsService {
    private let decoder = JSONDecoder()

    func fetchByZip(_ zip: String) async throws -> ConditionsSnapshot {
        guard zip.range(of: #"^\d{5}$"#, options: .regularExpression) != nil else {
            throw ConditionsError.invalidZip
        }

        let zipURL = URL(string: "https://api.zippopotam.us/us/\(zip)")!
        let zipData = try await load(url: zipURL)
        let zipResponse = try decoder.decode(ZipLookupResponse.self, from: zipData)
        guard let first = zipResponse.places.first,
              let lat = Double(first.latitude),
              let lon = Double(first.longitude) else {
            throw ConditionsError.invalidResponse
        }

        let name = "\(first.placeName), \(first.stateAbbreviation)"
        let state = first.stateAbbreviation.uppercased()
        return try await fetchByCoordinate(
            latitude: lat,
            longitude: lon,
            fallbackName: name,
            stateAbbrev: state.count == 2 ? state : nil
        )
    }

    func fetchByCoordinate(
        latitude: Double,
        longitude: Double,
        fallbackName: String? = nil,
        stateAbbrev: String? = nil
    ) async throws -> ConditionsSnapshot {
        let place = try await reverseGeocodePlace(latitude: latitude, longitude: longitude)
        let placeName = place?.name ?? fallbackName ?? "Current area"
        let resolvedState = place?.stateAbbrev ?? stateAbbrev?.uppercased()

        async let weather = fetchWeather(latitude: latitude, longitude: longitude)
        async let air = fetchAir(latitude: latitude, longitude: longitude)
        async let alerts = fetchAlerts(latitude: latitude, longitude: longitude)

        async let crimeSummary = CrimeIncidentsService.fetchSummary(latitude: latitude, longitude: longitude)
        async let wearable = WearableReadinessAggregator.loadWearableRunReadiness()

        let weatherResult = try await weather
        let airResult = try await air
        let alertsResult = await alerts
        let crimeResult = await crimeSummary
        let wearableResult = await wearable

        // Run index = ScoreEngine (+ wearables) only; AwarenessEngine below adds a separate score from night, NWS alerts, and crime—those do not change the run index.
        let envScore = ScoreEngine.compute(
            apparentF: weatherResult.current.apparentTemperature,
            dryBulbF: weatherResult.current.temperature2m,
            relativeHumidity: weatherResult.current.relativeHumidity2m,
            windSpeedMph: weatherResult.current.windSpeed10m,
            gustMph: weatherResult.current.windGusts10m,
            weatherCode: weatherResult.current.weatherCode,
            usAQI: airResult?.current?.usAQI
        )
        let merged = ScoreEngine.applyWearable(
            baseScore: envScore.score,
            bullets: envScore.bullets,
            wearable: wearableResult
        )
        let verdict = ScoreEngine.verdict(for: merged.score)

        let noThirdPartyForRunIndex = !WearableRunIndexPreferences.includeWhoopInRunIndex
            && !WearableRunIndexPreferences.includeOuraInRunIndex
            && !WearableRunIndexPreferences.includeGarminInRunIndex
        let showRunIndexDataSourcesHint = noThirdPartyForRunIndex
            && wearableResult.sourceLabel == WearableReadinessAggregator.noWearableSignalSourceLabel

        let awareness = AwarenessEngine.compute(
            isDay: weatherResult.current.isDay,
            apparentF: weatherResult.current.apparentTemperature,
            gustMph: weatherResult.current.windGusts10m,
            weatherCode: weatherResult.current.weatherCode,
            usAQI: airResult?.current?.usAQI,
            alerts: alertsResult,
            crime: crimeResult
        )

        let currentRows = currentRows(from: weatherResult.current)
        let airRows = airRows(from: airResult?.current)
        let hourly = makeHourlyStrip(from: weatherResult.hourly)

        return ConditionsSnapshot(
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            stateAbbrev: resolvedState,
            score: merged.score,
            verdict: verdict,
            bullets: merged.bullets,
            wearableRows: merged.rows,
            awarenessScore: awareness.score,
            awarenessVerdict: awareness.verdict,
            awarenessBullets: awareness.bullets,
            currentRows: currentRows,
            airRows: airRows,
            hourly: hourly,
            alerts: alertsResult,
            cachedAt: nil,
            showRunIndexDataSourcesHint: showRunIndexDataSourcesHint
        )
    }

    private func fetchWeather(latitude: Double, longitude: Double) async throws -> ForecastResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_gusts_10m,is_day"),
            .init(name: "hourly", value: "weather_code,precipitation_probability"),
            .init(name: "daily", value: "sunrise,sunset"),
            .init(name: "forecast_days", value: "2"),
            .init(name: "timezone", value: "auto"),
            .init(name: "wind_speed_unit", value: "mph"),
            .init(name: "temperature_unit", value: "fahrenheit")
        ]

        let data = try await load(url: components.url!)
        return try decoder.decode(ForecastResponse.self, from: data)
    }

    private func fetchAir(latitude: Double, longitude: Double) async throws -> AirQualityResponse? {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "us_aqi,pm2_5"),
            .init(name: "timezone", value: "auto")
        ]

        do {
            let data = try await load(url: components.url!)
            return try decoder.decode(AirQualityResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func fetchAlerts(latitude: Double, longitude: Double) async -> [NWSAlert] {
        var components = URLComponents(string: "https://api.weather.gov/alerts/active")!
        components.queryItems = [.init(name: "point", value: "\(latitude),\(longitude)")]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.setValue("StrideCheck iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await StrideCheckHTTPSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let decoded = try decoder.decode(NWSAlertsResponse.self, from: data)
            return Array(decoded.features.map(\.properties).prefix(6))
        } catch {
            return []
        }
    }

    private func reverseGeocodePlace(latitude: Double, longitude: Double) async throws -> (name: String, stateAbbrev: String?)? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return nil }

        let city = placemark.locality ?? placemark.subAdministrativeArea
        let state = placemark.administrativeArea
        let abbr = placemark.administrativeArea?.uppercased()
        let stateCode = (abbr?.count == 2) ? abbr : nil

        let name: String
        if let city, let state {
            name = "\(city), \(state)"
        } else if let city {
            name = city
        } else if let state {
            name = state
        } else {
            return nil
        }
        return (name, stateCode)
    }

    private func load(url: URL) async throws -> Data {
        let (data, response) = try await StrideCheckHTTPSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func currentRows(from current: CurrentForecast) -> [(String, String)] {
        let weatherText = WeatherCode.info(for: current.weatherCode).label
        let weatherEmoji = WeatherCode.info(for: current.weatherCode).emoji
        let wind = current.windSpeed10m != nil ? "\(Int((current.windSpeed10m ?? 0).rounded())) mph" : "—"
        let gust = current.windGusts10m != nil ? "\(Int((current.windGusts10m ?? 0).rounded())) mph" : "—"
        let humidity = current.relativeHumidity2m != nil ? "\(Int((current.relativeHumidity2m ?? 0).rounded()))%" : "—"

        return [
            ("Feels Like", current.apparentTemperature != nil ? "\(Int((current.apparentTemperature ?? 0).rounded()))°F" : "—"),
            ("Conditions", "\(weatherEmoji) \(weatherText)"),
            ("Wind", "\(wind) · gusts \(gust)"),
            ("Humidity", humidity)
        ]
    }

    private func airRows(from air: CurrentAirQuality?) -> [(String, String)] {
        guard let air else { return [("US AQI", "—"), ("PM2.5", "—")] }

        let aqi = air.usAQI != nil ? "\(Int((air.usAQI ?? 0).rounded()))" : "—"
        let pm = air.pm25 != nil ? String(format: "%.1f µg/m³", air.pm25 ?? 0) : "—"
        return [("US AQI", aqi), ("PM2.5", pm)]
    }

    private func makeHourlyStrip(from hourly: HourlyForecast) -> [HourlyDisplay] {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd'T'HH:mm"
        input.locale = Locale(identifier: "en_US_POSIX")
        let output = DateFormatter()
        output.dateFormat = "ha"

        let now = Date()
        var result: [HourlyDisplay] = []

        for idx in hourly.time.indices {
            let raw = hourly.time[idx]
            let date = input.date(from: raw)
            guard let date, date >= now else { continue }

            let code = idx < hourly.weatherCode.count ? hourly.weatherCode[idx] : 0
            let rain = idx < (hourly.precipitationProbability?.count ?? 0) ? hourly.precipitationProbability?[idx] ?? 0 : 0

            result.append(
                HourlyDisplay(
                    timeLabel: output.string(from: date).lowercased(),
                    icon: WeatherCode.info(for: code).emoji,
                    rainChanceLabel: "\(rain)% rain"
                )
            )

            if result.count >= 12 { break }
        }

        return result
    }
}

private enum WeatherCode {
    static func info(for code: Int?) -> (label: String, emoji: String) {
        switch code ?? -1 {
        case 0: return ("Clear", "☀️")
        case 1: return ("Mostly clear", "🌤️")
        case 2: return ("Partly cloudy", "⛅")
        case 3: return ("Overcast", "☁️")
        case 45, 48: return ("Fog", "🌫️")
        case 51...55: return ("Drizzle", "🌦️")
        case 61...67: return ("Rain", "🌧️")
        case 71...77: return ("Snow", "❄️")
        case 80...82: return ("Showers", "🌦️")
        case 85, 86: return ("Snow showers", "🌨️")
        case 95...99: return ("Thunderstorm", "⛈️")
        default: return ("Mixed", "🌡️")
        }
    }
}

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

/// Environmental comfort, visibility, optional delayed crime-incident density (third-party API), and weather alerts.
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
