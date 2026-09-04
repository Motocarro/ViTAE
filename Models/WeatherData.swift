import Foundation

enum WeatherCondition: String, Codable, CaseIterable {
    case sunny, cloudy, rainy, stormy

    /// Maps a raw OpenWeatherMap "main" condition string to our simplified enum.
    static func from(openWeatherMain: String) -> WeatherCondition {
        switch openWeatherMain.lowercased() {
        case "clear":
            return .sunny
        case "clouds", "mist", "haze", "fog":
            return .cloudy
        case "rain", "drizzle":
            return .rainy
        case "thunderstorm", "tornado", "squall":
            return .stormy
        case "snow":
            return .cloudy // Treated as soft, diffuse light for now.
        default:
            return .cloudy
        }
    }
}

struct WeatherData: Codable {
    struct Forecast: Codable, Identifiable {
        var id: Date { date }
        let date: Date
        let condition: WeatherCondition
        let temperature: Double // Celsius
        let humidity: Double // 0-100
        let windSpeed: Double // m/s
    }

    let location: String
    let forecasts: [Forecast] // Up to ~10 entries.
    let lastUpdated: Date

    /// The forecast entry that best represents "today", or the first available entry.
    var todayForecast: Forecast? {
        let calendar = Calendar.current
        return forecasts.first { calendar.isDateInToday($0.date) } ?? forecasts.first
    }

    /// A safe, generic fallback used when no cache exists and the network is unavailable.
    static var fallback: WeatherData {
        WeatherData(
            location: "Unknown",
            forecasts: [
                Forecast(date: Date(), condition: .cloudy, temperature: 20, humidity: 50, windSpeed: 2)
            ],
            lastUpdated: .distantPast
        )
    }
}
