import Foundation

/// Thin wrapper around UserDefaults for saving/loading Codable preferences.
final class PersistenceService {
    private let defaults: UserDefaults
    private let key = Constants.userDefaultsPreferencesKey

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPreferences() -> UserPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserPreferences.self, from: data)
    }

    func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
