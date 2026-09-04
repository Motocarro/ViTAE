import Foundation

enum FlowDirection: String, Codable, CaseIterable {
    case cw, ccw, oscillate

    /// User-facing label. Internal case names (cw/ccw/oscillate) are kept as-is for
    /// Codable/persistence compatibility — only the display text changed.
    var displayName: String {
        switch self {
        case .cw: return "Forward"
        case .ccw: return "Reverse"
        case .oscillate: return "Sway"
        }
    }
}

/// Everything that gets persisted to UserDefaults between launches.
/// All sliders start neutral (50%, or 0 for Hue Offset) — there are no presets.
struct UserPreferences: Codable, Equatable {
    var volume: Double = 0.5
    var energy: Double = 0.5
    var hueOffset: Double = 0 // -180...180
    var saturation: Double = 0.5
    var brightness: Double = 0.5
    var flowDirection: FlowDirection = .cw

    /// Manual location override, set when the user searches for a place instead of using GPS.
    var overrideLatitude: Double?
    var overrideLongitude: Double?
    var overrideLocationName: String?

    static let neutral = UserPreferences()
}
