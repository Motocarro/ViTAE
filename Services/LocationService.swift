import CoreLocation
import Foundation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Called with the resolved coordinate and a human-readable place name.
    var onLocationUpdate: ((CLLocationCoordinate2D, String) -> Void)?
    /// Called when a location can't be determined (permission denied, no signal, etc).
    var onLocationFailure: (() -> Void)?

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced // Coarse accuracy is plenty for weather.
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        authorizationStatus = status
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            onLocationFailure?()
        @unknown default:
            onLocationFailure?()
        }
    }

    /// Forward-geocodes a free-text search string for the manual location override UI.
    func searchLocation(_ query: String) async throws -> [(name: String, coordinate: CLLocationCoordinate2D)] {
        let placemarks = try await geocoder.geocodeAddressString(query)
        return placemarks.compactMap { placemark in
            guard let coordinate = placemark.location?.coordinate else { return nil }
            let name = [placemark.locality, placemark.administrativeArea, placemark.country]
                .compactMap { $0 }
                .joined(separator: ", ")
            return (name.isEmpty ? query : name, coordinate)
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onLocationFailure?()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let name = placemarks?.first?.locality ?? "Current location"
            self?.onLocationUpdate?(location.coordinate, name)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onLocationFailure?()
    }
}
