import Foundation
import Combine
import CoreLocation

/// Centralizes all app state: persisted preferences, live weather/location, and the
/// services that produce them. Views observe this via @ObservedObject; it's the single
/// source of truth referenced in section 3.2 of the brief.
@MainActor
final class AppState: ObservableObject {
    // MARK: Persisted user preferences (the 6 sliders + location override)
    @Published var preferences: UserPreferences {
        didSet { persistenceService.save(preferences) }
    }

    // MARK: Live data
    @Published var weatherData: WeatherData = .fallback
    @Published var currentLocationName: String = "Locating…"
    @Published var isOffline: Bool = false
    @Published var isControlPanelOpen: Bool = false

    let persistenceService: PersistenceService
    let weatherService: WeatherService
    let locationService: LocationService
    let audioSynthesizer: AudioSynthesizer

    private var cancellables = Set<AnyCancellable>()

    init(
        persistenceService: PersistenceService = PersistenceService(),
        weatherService: WeatherService = WeatherService(),
        locationService: LocationService = LocationService(),
        audioSynthesizer: AudioSynthesizer = AudioSynthesizer()
    ) {
        self.persistenceService = persistenceService
        self.weatherService = weatherService
        self.locationService = locationService
        self.audioSynthesizer = audioSynthesizer
        self.preferences = persistenceService.loadPreferences() ?? .neutral

        observeLocation()

        $preferences
            .sink { [weak self] prefs in
                guard let self else { return }
                self.audioSynthesizer.update(preferences: prefs, weather: self.weatherData)
            }
            .store(in: &cancellables)
    }

    /// Kicks off audio + location/weather fetching. Call once from the root view's `.task`.
    func start() {
        audioSynthesizer.start()
        if let lat = preferences.overrideLatitude, let lon = preferences.overrideLongitude {
            currentLocationName = preferences.overrideLocationName ?? "Saved location"
            Task { await refreshWeather(latitude: lat, longitude: lon) }
        } else {
            locationService.requestLocation()
        }
    }

    private func observeLocation() {
        locationService.onLocationUpdate = { [weak self] coordinate, placeName in
            guard let self else { return }
            // A manual override always wins over GPS updates.
            guard self.preferences.overrideLatitude == nil else { return }
            self.currentLocationName = placeName
            Task { await self.refreshWeather(latitude: coordinate.latitude, longitude: coordinate.longitude) }
        }
        locationService.onLocationFailure = { [weak self] in
            guard let self else { return }
            if let lat = self.preferences.overrideLatitude, let lon = self.preferences.overrideLongitude {
                Task { await self.refreshWeather(latitude: lat, longitude: lon) }
            } else {
                self.currentLocationName = "Location unavailable"
                self.weatherData = self.weatherService.loadCache() ?? .fallback
                self.isOffline = true
            }
        }
    }

    func refreshWeather(latitude: Double, longitude: Double) async {
        let result = await weatherService.fetchWeather(latitude: latitude, longitude: longitude)
        self.weatherData = result.data
        self.isOffline = result.isOfflineFallback
        audioSynthesizer.update(preferences: preferences, weather: result.data)
    }

    /// Called from the "Sync" button in the control panel.
    func manualWeatherSync() {
        if let lat = preferences.overrideLatitude, let lon = preferences.overrideLongitude {
            Task { await refreshWeather(latitude: lat, longitude: lon) }
        } else {
            locationService.requestLocation()
        }
    }

    /// Applies a manually searched location as an override (from LocationOverrideView).
    func applyLocationOverride(name: String, latitude: Double, longitude: Double) {
        preferences.overrideLatitude = latitude
        preferences.overrideLongitude = longitude
        preferences.overrideLocationName = name
        currentLocationName = name
        Task { await refreshWeather(latitude: latitude, longitude: longitude) }
    }

    /// Clears the manual override and returns to GPS-based location.
    func clearLocationOverride() {
        preferences.overrideLatitude = nil
        preferences.overrideLongitude = nil
        preferences.overrideLocationName = nil
        currentLocationName = "Locating…"
        locationService.requestLocation()
    }

    /// Resets the 6 sliders to neutral. Per the brief: does NOT clear location or cached weather.
    func resetAllSliders() {
        var prefs = preferences
        prefs.volume = 0.5
        prefs.energy = 0.5
        prefs.hueOffset = 0
        prefs.saturation = 0.5
        prefs.brightness = 0.5
        prefs.flowDirection = .cw
        preferences = prefs
    }

    // MARK: Derived values consumed by the visual layer

    var baseHue: Double {
        ColorCalculator.hueFromTimeOfDay()
    }

    var weatherSaturation: Double {
        ColorCalculator.saturation(for: weatherData.todayForecast?.condition ?? .cloudy)
    }

    var weatherBrightness: Double {
        ColorCalculator.brightness(for: weatherData.todayForecast?.condition ?? .cloudy)
    }
}
