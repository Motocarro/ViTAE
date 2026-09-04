import Foundation

/// Fetches and caches weather data, with a silent offline fallback.
///
/// This is the piece the original brief cut off mid-function — completed below,
/// following the caching strategy described in section 6.1:
///   1. Fetch once per day (on launch, or via manual "Sync").
///   2. If offline, fall back to the cache silently (surface a small indicator instead).
///   3. If there's no cache AND we're offline, fall back to a generic default.
final class WeatherService {
    private let apiKey = Constants.weatherAPIKey
    private let cacheURL: URL

    struct FetchResult {
        let data: WeatherData
        /// True only when we could NOT reach the network and served cache/fallback instead.
        let isOfflineFallback: Bool
    }

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TemporalAmbientEngine", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.cacheURL = appSupport.appendingPathComponent(Constants.weatherCacheFilename)
    }

    /// Returns fresh weather if the cache is stale or missing; otherwise returns the cache
    /// as-is. Falls back silently to cached (or generic) data if the network request fails.
    func fetchWeather(latitude: Double, longitude: Double) async -> FetchResult {
        if let cached = loadCache(), isRecentEnough(cached.lastUpdated) {
            return FetchResult(data: cached, isOfflineFallback: false)
        }

        do {
            let fresh = try await requestWeather(latitude: latitude, longitude: longitude)
            saveCache(fresh)
            return FetchResult(data: fresh, isOfflineFallback: false)
        } catch {
            if let cached = loadCache() {
                return FetchResult(data: cached, isOfflineFallback: true)
            }
            return FetchResult(data: .fallback, isOfflineFallback: true)
        }
    }

    // MARK: Networking

    private func requestWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        var components = URLComponents(string: Constants.weatherAPIBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "cnt", value: "10")
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try Self.parse(data, fallbackLocationName: "\(latitude), \(longitude)")
    }

    /// Parses OpenWeatherMap's "5 day / 3 hour" forecast JSON into our simplified model.
    /// NOTE: each `list` entry is a 3-hour step, not a calendar day. If you upgrade to the
    /// One Call API 3.0 `daily` endpoint, swap the RawResponse/Entry shape below to match
    /// its schema (fields like `temp.day`, `weather[0].main`, etc.) for true daily entries.
    private static func parse(_ data: Data, fallbackLocationName: String) throws -> WeatherData {
        struct RawResponse: Decodable {
            struct City: Decodable { let name: String }
            struct Entry: Decodable {
                struct Weather: Decodable { let main: String }
                struct Main: Decodable { let temp: Double; let humidity: Double }
                struct Wind: Decodable { let speed: Double }
                let dt: TimeInterval
                let weather: [Weather]
                let main: Main
                let wind: Wind
            }
            let city: City?
            let list: [Entry]
        }

        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        let forecasts = raw.list.map { entry in
            WeatherData.Forecast(
                date: Date(timeIntervalSince1970: entry.dt),
                condition: WeatherCondition.from(openWeatherMain: entry.weather.first?.main ?? "Clouds"),
                temperature: entry.main.temp,
                humidity: entry.main.humidity,
                windSpeed: entry.wind.speed
            )
        }

        return WeatherData(
            location: raw.city?.name ?? fallbackLocationName,
            forecasts: forecasts,
            lastUpdated: Date()
        )
    }

    // MARK: Caching

    func loadCache() -> WeatherData? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(WeatherData.self, from: data)
    }

    private func saveCache(_ weather: WeatherData) {
        guard let data = try? JSONEncoder().encode(weather) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func isRecentEnough(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < Constants.weatherCacheMaxAgeSeconds
    }
}
