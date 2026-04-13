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
