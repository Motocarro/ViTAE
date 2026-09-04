import SwiftUI

/// The slider drawer described in section 5.1 — 6 controls, no presets, everything
/// starts neutral. Sliders bind directly to `appState.preferences`, so every change
/// is both persisted (via AppState's didSet) and pushed to the audio engine live.
///
/// v2: renamed header to "Settings" to match how you're already referring to it, added
/// an explicit close button inside the panel's own header (the old design relied on
/// clicking the same top-bar button that the open panel visually covered — inaccessible),
/// and the panel now consumes its own taps so ContentView's "tap outside to dismiss"
/// scrim doesn't also fire when you're interacting with a control.
struct ControlPanelView: View {
    @ObservedObject var appState: AppState
    @State private var isShowingLocationSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    withAnimation(.easeInOut) {
                        appState.isControlPanelOpen = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            sliderRow(title: "Volume", value: $appState.preferences.volume)
            sliderRow(title: "Energy", value: $appState.preferences.energy)
            sliderRow(title: "Hue Offset", value: $appState.preferences.hueOffset, range: -180...180)
            sliderRow(title: "Saturation", value: $appState.preferences.saturation)
            sliderRow(title: "Brightness", value: $appState.preferences.brightness)

            flowDirectionPicker

            Divider().background(.white.opacity(0.2))

            HStack {
                Button {
                    isShowingLocationSearch = true
                } label: {
                    Label(appState.currentLocationName, systemImage: "location")
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    appState.manualWeatherSync()
                } label: {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white.opacity(0.85))

            if appState.isOffline {
                Text("Offline — showing cached weather")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Button(role: .destructive) {
                appState.resetAllSliders()
            } label: {
                Label("Reset all", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(24)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture { } // Swallow taps so they don't reach the outside-dismiss scrim.
        .sheet(isPresented: $isShowingLocationSearch) {
            LocationOverrideView(appState: appState)
        }
    }

    @ViewBuilder
    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue(value.wrappedValue, range: range))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(.subheadline)
            Slider(value: value, in: range)
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    private func displayValue(_ value: Double, range: ClosedRange<Double>) -> String {
        range.lowerBound < 0 ? "\(Int(value))°" : "\(Int(value * 100))%"
    }

    private var flowDirectionPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Flow Direction")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Picker("Flow Direction", selection: $appState.preferences.flowDirection) {
                ForEach(FlowDirection.allCases, id: \.self) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
