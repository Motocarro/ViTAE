import SwiftUI

/// The full-screen flowing color background from section 4.
///
/// v2: the discrete center "orb" shape has been removed per feedback — this now just
/// renders a single soft, full-bleed radial wash using two closely related (analogous)
/// hues instead of the old triadic split, so it reads as one coherent color instead of
/// a rainbow. (Kept the file/type name ColorFlowOrbView for continuity with the
/// existing Xcode project — rename via Xcode's refactor tool later if you'd like.)
struct ColorFlowOrbView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Constants.canvasFrameRate)) { timeline in
            Canvas { context, size in
                let state = ColorFlowState.compute(
                    baseHue: appState.baseHue,
                    weatherSaturation: appState.weatherSaturation,
                    weatherBrightness: appState.weatherBrightness,
                    preferences: appState.preferences,
                    at: timeline.date
                )
                draw(state, in: &context, size: size)
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }

    private func draw(_ state: ColorFlowState, in context: inout GraphicsContext, size: CGSize) {
        let gradient = Gradient(stops: [
            .init(color: Color(hueDegrees: state.animatedHue, saturation: state.saturation * 0.75, brightness: state.brightness * 0.65), location: 0),
            .init(color: Color(hueDegrees: state.secondaryHue, saturation: state.saturation * 0.55, brightness: state.brightness * 0.30), location: 1)
        ])

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = hypot(size.width, size.height) / 1.4 // reaches the corners smoothly

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
        )
    }
}
