import Combine
import CoreLocation
import Foundation
import GooglePlaces

final class HomeLocationViewModel: NSObject, ObservableObject {
    @Published var addressQuery: String = ""
    @Published var suggestions: [LocationSearchResult] = []
    @Published var selectedTitle: String = ""
    @Published var selectedSubtitle: String = ""
    @Published var selectedLatitude: Double?
    @Published var selectedLongitude: Double?
    @Published var mapRegion: CoordinateRegionDegrees
    @Published var isResolvingCurrentLocation = false

    private var fetcher: GMSAutocompleteFetcher?
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        self.mapRegion = CoordinateRegionDegrees(
            center: CLLocationCoordinate2D(latitude: -17.8252, longitude: 31.0335),
            latitudeDelta: 0.03,
            longitudeDelta: 0.03
        )
        super.init()
        rebuildFetcher()
        locationManager.delegate = self
    }

    private func rebuildFetcher() {
        let filter = GMSAutocompleteFilter()
        filter.types = ["address"]
        let newFetcher = GMSAutocompleteFetcher(filter: filter)
        newFetcher.delegate = self
        fetcher = newFetcher
    }

    func setInitialAddress(_ value: String) {
        if addressQuery.isEmpty {
            addressQuery = value
        }
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        addressQuery = query
        if trimmed.count < 2 {
            suggestions = []
            fetcher?.sourceTextHasChanged("")
            return
        }
        fetcher?.sourceTextHasChanged(trimmed)
    }

    func selectSuggestion(_ result: LocationSearchResult) {
        guard let placeId = result.placeId else { return }
        GMSPlacesClient.shared().fetchPlace(fromPlaceID: placeId, placeFields: [.name, .formattedAddress, .coordinate], sessionToken: nil) { [weak self] place, _ in
            guard let self, let place else { return }
            let coordinate = place.coordinate
            let title = (place.name ?? result.title).trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = result.subtitle
            let fullAddress = (place.formattedAddress ?? result.fullAddress).trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                self.selectedTitle = title
                self.selectedSubtitle = subtitle
                self.selectedLatitude = coordinate.latitude
                self.selectedLongitude = coordinate.longitude
                self.addressQuery = fullAddress.isEmpty ? "\(title), \(subtitle)" : fullAddress
                self.suggestions = []
                self.mapRegion = CoordinateRegionDegrees(
                    center: coordinate,
                    latitudeDelta: 0.012,
                    longitudeDelta: 0.012
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
                self.mapRegion = CoordinateRegionDegrees(
                    center: location.coordinate,
                    latitudeDelta: 0.012,
                    longitudeDelta: 0.012
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

extension HomeLocationViewModel: GMSAutocompleteFetcherDelegate {
    func didAutocomplete(with predictions: [GMSAutocompletePrediction]) {
        DispatchQueue.main.async {
            self.suggestions = predictions.prefix(6).map { prediction in
                let title = prediction.attributedPrimaryText.string.trimmingCharacters(in: .whitespacesAndNewlines)
                let subtitle = prediction.attributedSecondaryText?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fullAddress = subtitle.isEmpty ? title : "\(title), \(subtitle)"
                return LocationSearchResult(
                    title: title,
                    subtitle: subtitle,
                    fullAddress: fullAddress,
                    placeId: prediction.placeID
                )
            }
        }
    }

    func didFailAutocompleteWithError(_ error: Error) {
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

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isResolvingCurrentLocation = false
        }
    }
}
