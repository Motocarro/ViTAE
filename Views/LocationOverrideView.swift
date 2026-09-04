import SwiftUI
import CoreLocation

/// Manual location search sheet, opened from the control panel's location button.
struct LocationOverrideView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [(name: String, coordinate: CLLocationCoordinate2D)] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            VStack {
                if let searchError {
                    Text(searchError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                List(results, id: \.name) { result in
                    Button {
                        appState.applyLocationOverride(
                            name: result.name,
                            latitude: result.coordinate.latitude,
                            longitude: result.coordinate.longitude
                        )
                        dismiss()
                    } label: {
                        Text(result.name)
                    }
                }
                .overlay {
                    if isSearching {
                        ProgressView()
                    }
                }
            }
            .searchable(text: $query, prompt: "Search for a city")
            .onSubmit(of: .search, performSearch)
            .navigationTitle("Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use current location") {
                        appState.clearLocationOverride()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchError = nil
        Task {
            do {
                results = try await appState.locationService.searchLocation(query)
                if results.isEmpty { searchError = "No matches found." }
            } catch {
                searchError = "Couldn't search that location."
            }
            isSearching = false
        }
    }
}
