import SwiftUI

struct TopBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                if appState.isOffline {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                }
                Text(appState.currentLocationName)
                    .font(.subheadline)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut) {
                    appState.isControlPanelOpen.toggle()
                }
            } label: {
                Image(systemName: appState.isControlPanelOpen ? "xmark.circle" : "slider.horizontal.3")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}
