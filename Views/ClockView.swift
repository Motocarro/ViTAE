import SwiftUI

/// Small always-on-time readout, pinned to the bottom-left of the window.
struct ClockView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Text(timeline.date.shortTimeString)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
