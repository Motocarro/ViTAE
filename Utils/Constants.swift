import Foundation

enum Constants {
    /// TODO: Replace with your own OpenWeatherMap API key.
    /// Do not commit a real key to source control — load it from an .xcconfig
    /// or the Keychain in a production build.
    static let weatherAPIKey = "YOUR_OPENWEATHERMAP_KEY"

    /// Free-tier "5 day / 3 hour" forecast endpoint. Each entry is a 3-hour step,
    /// not a full day — see the parsing note in WeatherService for how this is
    /// collapsed into daily-ish forecasts. Swap for the One Call API 3.0 endpoint
    /// if you want true daily granularity.
    static let weatherAPIBaseURL = "https://api.openweathermap.org/data/2.5/forecast"

    static let weatherCacheFilename = "weather_cache.json"
    static let weatherCacheMaxAgeSeconds: TimeInterval = 24 * 60 * 60 // 24 hours

    static let userDefaultsPreferencesKey = "com.temporalambientengine.userPreferences"

    static let canvasFrameRate: Double = 30 // Hz
    static let orbBreatheDuration: Double = 4.0 // seconds for one full breathe cycle

    static let audioSampleRate: Double = 44100
}
