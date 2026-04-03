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
        return try await fetchByCoordinate(latitude: lat, longitude: lon, fallbackName: name)
    }

    func fetchByCoordinate(latitude: Double, longitude: Double, fallbackName: String? = nil) async throws -> ConditionsSnapshot {
        let placeName = try await reverseGeocodeName(latitude: latitude, longitude: longitude) ?? fallbackName ?? "Current area"

        async let weather = fetchWeather(latitude: latitude, longitude: longitude)
        async let air = fetchAir(latitude: latitude, longitude: longitude)
        async let alerts = fetchAlerts(latitude: latitude, longitude: longitude)

        let weatherResult = try await weather
        let airResult = try await air
        let alertsResult = await alerts

        let score = ScoreEngine.compute(
            apparentF: weatherResult.current.apparentTemperature,
            gustMph: weatherResult.current.windGusts10m,
            weatherCode: weatherResult.current.weatherCode,
            usAQI: airResult?.current?.usAQI
        )
        let verdict = ScoreEngine.verdict(for: score.score)

        let currentRows = currentRows(from: weatherResult.current)
        let airRows = airRows(from: airResult?.current)
        let hourly = makeHourlyStrip(from: weatherResult.hourly)

        return ConditionsSnapshot(
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            score: score.score,
            verdict: verdict,
            bullets: score.bullets,
            currentRows: currentRows,
            airRows: airRows,
            hourly: hourly,
            alerts: alertsResult
        )
    }

    private func fetchWeather(latitude: Double, longitude: Double) async throws -> ForecastResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_gusts_10m"),
            .init(name: "hourly", value: "weather_code,precipitation_probability"),
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
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let decoded = try decoder.decode(NWSAlertsResponse.self, from: data)
            return Array(decoded.features.map(\.properties).prefix(6))
        } catch {
            return []
        }
    }

    private func reverseGeocodeName(latitude: Double, longitude: Double) async throws -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return nil }

        let city = placemark.locality ?? placemark.subAdministrativeArea
        let state = placemark.administrativeArea
        if let city, let state {
            return "\(city), \(state)"
        }
        return city ?? state
    }

    private func load(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
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

private enum ScoreEngine {
    static func compute(apparentF: Double?, gustMph: Double?, weatherCode: Int?, usAQI: Double?) -> (score: Int, bullets: [String]) {
        var score = 100
        var bullets: [String] = []

        if let f = apparentF {
            if f >= 95 {
                score -= 30
                bullets.append("Very hot feels-like; hydrate and reduce effort.")
            } else if f >= 88 {
                score -= 22
                bullets.append("High heat load; prioritize shade and fluids.")
            } else if f <= 14 {
                score -= 28
                bullets.append("Bitter cold; cover skin and watch for slick surfaces.")
            } else if f <= 28 {
                score -= 16
                bullets.append("Freezing possible; be careful on bridges and painted lines.")
            }
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
