import CoreLocation
import Foundation
import MapKit
import Combine

final class HomeLocationViewModel: NSObject, ObservableObject {
    @Published var addressQuery: String = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var selectedTitle: String = ""
    @Published var selectedSubtitle: String = ""
    @Published var selectedLatitude: Double?
    @Published var selectedLongitude: Double?
    @Published var mapRegion: MKCoordinateRegion
    @Published var isResolvingCurrentLocation = false

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        self.mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -17.8252, longitude: 31.0335),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
        locationManager.delegate = self
    }

    func setInitialAddress(_ value: String) {
        if addressQuery.isEmpty {
            addressQuery = value
        }
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func selectSuggestion(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self else { return }
            guard let mapItem = response?.mapItems.first else { return }

            let coordinate = mapItem.placemark.coordinate
            let title = mapItem.name ?? completion.title
            let subtitle = completion.subtitle
            let fullAddress = subtitle.isEmpty ? title : "\(title), \(subtitle)"

            DispatchQueue.main.async {
                self.selectedTitle = title
                self.selectedSubtitle = subtitle
                self.selectedLatitude = coordinate.latitude
                self.selectedLongitude = coordinate.longitude
                self.addressQuery = fullAddress
                self.suggestions = []
                self.mapRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
            }
        }
    }

    func useCurrentLocation() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isResolvingCurrentLocation = true
            locationManager.requestLocation()
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    private func applyCurrentLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let placemark = placemarks?.first
            let title = placemark?.name ?? "Current Location"
            let subtitle = Self.subtitle(from: placemark)
            let fullAddress = subtitle.isEmpty ? title : "\(title), \(subtitle)"

            DispatchQueue.main.async {
                self.isResolvingCurrentLocation = false
                self.selectedTitle = title
                self.selectedSubtitle = subtitle
                self.selectedLatitude = location.coordinate.latitude
                self.selectedLongitude = location.coordinate.longitude
                self.addressQuery = fullAddress
                self.suggestions = []
                self.mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
            }
        }
    }

    private static func subtitle(from placemark: CLPlacemark?) -> String {
        guard let placemark else { return "" }
        let parts = [
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

extension HomeLocationViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = Array(completer.results.prefix(6))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }
}

extension HomeLocationViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            DispatchQueue.main.async {
                self.isResolvingCurrentLocation = true
            }
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            DispatchQueue.main.async {
                self.isResolvingCurrentLocation = false
            }
            return
        }
        applyCurrentLocation(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        DispatchQueue.main.async {
            self.isResolvingCurrentLocation = false
        }
    }
}
