import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ColorFlowOrbView(appState: appState)

            VStack {
                TopBarView(appState: appState)
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    ClockView()
                    Spacer()
                }
            }
            .padding(20)

            if appState.isControlPanelOpen {
                // Nearly-invisible full-screen scrim: tap anywhere outside the panel
                // to dismiss it. Sits below the panel in z-order, so taps on the panel
                // itself are handled by the panel (see its .onTapGesture {} swallow).
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            appState.isControlPanelOpen = false
                        }
                    }

                ControlPanelView(appState: appState)
                    .padding(20)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .task {
            appState.start()
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
