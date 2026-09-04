import Foundation

/// Pure functions mapping time-of-day and weather into *base* color values.
/// Hue follows a continuous curve anchored to real sunrise/sunset moods — warm at
/// sunrise, warm through the day, a warm/cool "mixed" tone at sunset (magenta, where
/// the orange horizon meets the darkening blue sky), and cold blue-indigo through the
/// night — interpolated smoothly rather than jumping between hard-coded buckets.
enum ColorCalculator {

    /// (hour-of-day, hue-in-degrees) anchor points. Hours may be fractional (6.5 = 6:30am).
    private static let hueAnchors: [(hour: Double, hue: Double)] = [
        (0,    235), // Midnight: deep cold indigo/blue
        (5,    250), // Just before dawn: coldest point of the night
        (6.5,   25), // Sunrise: warm orange/red
        (9,     45), // Morning: warm gold
        (12,    50), // Midday: bright warm yellow
        (15,    40), // Afternoon: soft warm gold
        (18,    15), // Sunset: deep warm red/orange
        (19.5, 300), // Dusk: warm/cool mix (magenta)
        (21,   265), // Evening: cooling toward blue/purple
        (24,   235), // Back to midnight — closes the loop
    ]

    /// Returns a base hue (0-360) representing the "mood" of the current time of day,
    /// smoothly interpolated between anchor points.
    static func hueFromTimeOfDay(_ date: Date = Date(), calendar: Calendar = .current) -> Double {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let fractionalHour = Double(hour) + Double(minute) / 60.0
        return hue(at: fractionalHour)
    }

    private static func hue(at fractionalHour: Double) -> Double {
        for i in 0..<(hueAnchors.count - 1) {
            let current = hueAnchors[i]
            let next = hueAnchors[i + 1]
            if fractionalHour >= current.hour && fractionalHour <= next.hour {
                let t = (fractionalHour - current.hour) / (next.hour - current.hour)
                return lerpHue(current.hue, next.hue, t)
            }
        }
        return hueAnchors[0].hue // Unreachable given the 0...24 anchor range; safe fallback.
    }

    /// Interpolates between two hues along the shortest angular path, so e.g. a
    /// 15°→300° transition sweeps *backward* through red/magenta (75° of travel)
    /// instead of the long way around through the whole spectrum.
    private static func lerpHue(_ from: Double, _ to: Double, _ t: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return (from + delta * t).wrappedHue()
    }

    static func saturation(for condition: WeatherCondition) -> Double {
        switch condition {
        case .sunny:  return 0.85
        case .cloudy: return 0.60
        case .rainy:  return 0.50
        case .stormy: return 0.70
        }
    }

    static func brightness(for condition: WeatherCondition) -> Double {
        switch condition {
        case .sunny:  return 0.90
        case .cloudy: return 0.70
        case .rainy:  return 0.60
        case .stormy: return 0.40
        }
    }
}
