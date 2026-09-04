import SwiftUI

extension Double {
    /// Clamps a value between a lower and upper bound.
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// Wraps a hue-like value into the 0..<360 range.
    func wrappedHue() -> Double {
        var value = self.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }
}

extension CGFloat {
    // NOTE: fully-qualified Swift.min/Swift.max — plain min/max was resolving
    // ambiguously against CGFloat on some setups (reported issue, confirmed fix).
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Date {
    /// A short "HH:mm" string for the clock readout.
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

extension Color {
    /// Convenience initializer that takes hue in degrees (0-360) instead of SwiftUI's native 0-1.
    init(hueDegrees: Double, saturation: Double, brightness: Double) {
        self.init(
            hue: hueDegrees.wrappedHue() / 360.0,
            saturation: saturation.clamped(to: 0...1),
            brightness: brightness.clamped(to: 0...1)
        )
    }
}
