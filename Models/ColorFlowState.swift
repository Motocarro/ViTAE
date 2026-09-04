import SwiftUI

/// A computed snapshot of everything the Canvas needs to draw one frame.
///
/// v2: the background now gently *sways* within a bounded range around the current
/// time-of-day hue, rather than sweeping through the full color wheel — keeps things
/// anchored (warm mornings, cold nights) instead of cycling through a rainbow. The
/// sway is also ~10x slower than before, and Energy now maps exponentially onto cycle
/// length so the low end of the slider feels meaningfully calmer, not just "a bit less."
struct ColorFlowState {
    let animatedHue: Double   // degrees
    let secondaryHue: Double  // degrees — a close, analogous hue for the second gradient stop
    let saturation: Double    // 0...1
    let brightness: Double    // 0...1

    /// Degrees either side of the base hue the color is allowed to sway.
    private static let swayDegrees: Double = 22

    /// Fastest full sway lap, in seconds, at Energy = 100%. (Old 50% speed × 10, per request.)
    private static let fastestCycleSeconds: Double = 27.5
    /// Slowest full sway lap, in seconds, at Energy = 0% — nearly static.
    private static let slowestCycleSeconds: Double = 600

    static func compute(
        baseHue: Double,
        weatherSaturation: Double,
        weatherBrightness: Double,
        preferences: UserPreferences,
        at date: Date
    ) -> ColorFlowState {
        let hueOffset = (baseHue + preferences.hueOffset).wrappedHue()

        // Exponential (not linear) mapping: a linear map spends most of the slider's
        // range feeling "about the same speed". This keeps low settings meaningfully
        // calmer while still reaching a lively (but still gentle) pace at 100%.
        let energy = preferences.energy.clamped(to: 0...1)
        let cycleSeconds = slowestCycleSeconds * pow(fastestCycleSeconds / slowestCycleSeconds, energy)

        let timestamp = date.timeIntervalSince1970
        let phase = (timestamp / cycleSeconds).truncatingRemainder(dividingBy: 1.0)
        let wave = sin(phase * 2 * .pi)

        let sway: Double
        switch preferences.flowDirection {
        case .cw:        sway = wave * swayDegrees          // "Forward"
        case .ccw:       sway = -wave * swayDegrees         // "Reverse"
        case .oscillate: sway = wave * swayDegrees * 0.6    // "Sway" — tighter, gentler drift
        }

        let animatedHue = (hueOffset + sway).wrappedHue()
        let secondaryHue = (animatedHue + 16).wrappedHue() // Close/analogous, not a rainbow jump.

        let saturation = (weatherSaturation * (0.4 + preferences.saturation)).clamped(to: 0...1)
        let brightness = (weatherBrightness * (0.4 + preferences.brightness)).clamped(to: 0...1)

        return ColorFlowState(
            animatedHue: animatedHue,
            secondaryHue: secondaryHue,
            saturation: saturation,
            brightness: brightness
        )
    }
}
