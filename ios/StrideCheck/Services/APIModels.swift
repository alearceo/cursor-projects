import Foundation

struct ZipLookupResponse: Decodable {
    let postCode: String
    let country: String
    let countryAbbreviation: String
    let places: [ZipPlace]

    enum CodingKeys: String, CodingKey {
        case postCode = "post code"
        case country
        case countryAbbreviation = "country abbreviation"
        case places
    }
}

struct ZipPlace: Decodable {
    let placeName: String
    let longitude: String
    let state: String
    let stateAbbreviation: String
    let latitude: String

    enum CodingKeys: String, CodingKey {
        case placeName = "place name"
        case longitude
        case state
        case stateAbbreviation = "state abbreviation"
        case latitude
    }
}

struct ForecastResponse: Decodable {
    let current: CurrentForecast
    let hourly: HourlyForecast
    let daily: DailyForecast?
}

struct DailyForecast: Decodable {
    let sunrise: [String]?
    let sunset: [String]?
}

struct CurrentForecast: Decodable {
    let temperature2m: Double?
    let relativeHumidity2m: Double?
    let apparentTemperature: Double?
    let precipitation: Double?
    let weatherCode: Int?
    let windSpeed10m: Double?
    let windGusts10m: Double?
    let isDay: Int?

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitation
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case windGusts10m = "wind_gusts_10m"
        case isDay = "is_day"
    }
}

struct HourlyForecast: Decodable {
    let time: [String]
    let weatherCode: [Int]
    let precipitationProbability: [Int]?

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case precipitationProbability = "precipitation_probability"
    }
}

struct AirQualityResponse: Decodable {
    let current: CurrentAirQuality?
}

struct CurrentAirQuality: Decodable {
    let usAQI: Double?
    let pm25: Double?

    enum CodingKeys: String, CodingKey {
        case usAQI = "us_aqi"
        case pm25 = "pm2_5"
    }
}

struct NWSAlertsResponse: Decodable {
    let features: [NWSFeature]
}

struct NWSFeature: Decodable {
    let properties: NWSAlert
}

struct NWSAlert: Decodable, Identifiable {
    var id: String { headline + (severity ?? "") }
    let headline: String
    let description: String?
    let severity: String?

    init(headline: String, description: String?, severity: String?) {
        self.headline = headline
        self.description = description
        self.severity = severity
    }
}

struct HourlyDisplay: Identifiable {
    let id = UUID()
    let timeLabel: String
    let icon: String
    let rainChanceLabel: String
}

struct WearableRunReadiness: Sendable {
    /// Apple Health / other sources (SDNN, ms).
    let hrvSDNNMs: Double?
    /// Whoop recovery HRV (RMSSD, ms) when using OAuth.
    let hrvRmssdMilli: Double?
    let sleepHours: Double?
    /// Heuristic 0–21 when inferred from Health/Oura MET or kcal.
    let strainProxy0to21: Double?
    /// Native Whoop day strain (0–21) when OAuth connected.
    let whoopCycleStrain: Double?
    let readinessScore0to100: Int?
    let sourceLabel: String
}

struct ConditionsSnapshot {
    let placeName: String
    let latitude: Double
    let longitude: Double
    let stateAbbrev: String?
    let score: Int
    let verdict: String
    let bullets: [String]
    let wearableRows: [(String, String)]
    let awarenessScore: Int
    let awarenessVerdict: String
    let awarenessBullets: [String]
    let currentRows: [(String, String)]
    let airRows: [(String, String)]
    let hourly: [HourlyDisplay]
    let alerts: [NWSAlert]
    let cachedAt: Date?
}
