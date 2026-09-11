import Combine
import CoreLocation
import Foundation
import GooglePlaces

struct LocationSearchResult: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let fullAddress: String
    let latitude: Double?
    let longitude: Double?
    /// Google Place ID when the row came from Places Autocomplete.
    let placeId: String?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        fullAddress: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.fullAddress = fullAddress
        self.latitude = latitude
        self.longitude = longitude
        self.placeId = placeId
    }

    /// Display name for POI / place (after resolution equals `LocationSearchResult.title`).
    var placeName: String { title }
}

@MainActor
final class LocationSearchModel: NSObject, ObservableObject {
    enum CompleterMode: Sendable {
        /// Street-address oriented (e.g. tribe home field).
        case homeAddress
        /// Addresses, POIs, and free-text queries (e.g. "pharmacy", business names).
        case runStopSearch
    }

    @Published var query: String = ""
    @Published private(set) var results: [LocationSearchResult] = []
    @Published private(set) var selectedResult: LocationSearchResult?
    @Published private(set) var isSearching = false
    /// Biases autocomplete toward an area; `nil` is unrestricted.
    private(set) var regionBias: LocationSearchRegionBias?

    var hasVerifiedSelection: Bool {
        selectedResult != nil
    }

    var noMatchesFound: Bool {
        !isSearching
            && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && results.isEmpty
            && selectedResult == nil
    }

    private var fetcher: GMSAutocompleteFetcher?
    private var debounceTask: Task<Void, Never>?
    private let mode: CompleterMode

    override convenience init() {
        self.init(mode: .homeAddress)
    }

    init(mode: CompleterMode) {
        self.mode = mode
        super.init()
        rebuildFetcher()
    }

    func applyRegionBias(_ bias: LocationSearchRegionBias?) {
        regionBias = bias
        rebuildFetcher()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2 {
            fetcher?.sourceTextHasChanged(trimmed)
        }
    }

    private func rebuildFetcher() {
        let filter = GMSAutocompleteFilter()
        if let bias = regionBias {
            filter.locationBias = GMSPlaceCircularLocationOption(bias.center, bias.radiusMeters)
        }
        switch mode {
        case .homeAddress:
            filter.types = ["address"]
        case .runStopSearch:
            filter.types = []
        }
        let newFetcher = GMSAutocompleteFetcher(filter: filter)
        newFetcher.delegate = self
        fetcher = newFetcher
    }

    func setQuery(_ value: String) {
        query = value
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedResult?.fullAddress != trimmed {
            selectedResult = nil
        }
        scheduleAutocomplete(for: trimmed)
    }

    func applySelectedAddress(_ value: String) {
        query = value
    }

    func clearSelection() {
        selectedResult = nil
        query = ""
        results = []
        fetcher?.sourceTextHasChanged("")
    }

    func selectResult(_ result: LocationSearchResult) async -> LocationSearchResult {
        if let placeId = result.placeId {
            do {
                let resolved = try await GooglePlaceResolveService.fetchResolvedPlace(placeID: placeId)
                let merged = LocationSearchResult(
                    id: result.id,
                    title: resolved.name,
                    subtitle: result.subtitle,
                    fullAddress: resolved.formattedAddress,
                    latitude: resolved.latitude,
                    longitude: resolved.longitude,
                    placeId: placeId
                )
                selectedResult = merged
                query = merged.fullAddress
                results = []
                return merged
            } catch {
                let fallback = LocationSearchResult(
                    title: result.title,
                    subtitle: result.subtitle,
                    fullAddress: result.fullAddress,
                    placeId: result.placeId
                )
                selectedResult = fallback
                query = fallback.fullAddress
                results = []
                return fallback
            }
        }

        selectedResult = result
        query = result.fullAddress
        results = []
        return result
    }

    private func scheduleAutocomplete(for trimmedQuery: String) {
        debounceTask?.cancel()
        guard trimmedQuery.count >= 2 else {
            isSearching = false
            results = []
            fetcher?.sourceTextHasChanged("")
            return
        }
        isSearching = true
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.fetcher?.sourceTextHasChanged(trimmedQuery)
            }
        }
    }
}

extension LocationSearchModel: GMSAutocompleteFetcherDelegate {
    nonisolated func didAutocomplete(with predictions: [GMSAutocompletePrediction]) {
        Task { @MainActor in
            let mapped = predictions.prefix(12).map { prediction -> LocationSearchResult in
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
            self.results = Array(mapped)
            self.isSearching = false
        }
    }

    nonisolated func didFailAutocompleteWithError(_ error: Error) {
        Task { @MainActor in
            self.results = []
            self.isSearching = false
        }
    }
}

/// Circular bias for Google Places Autocomplete (replaces `MKCoordinateRegion` bias).
struct LocationSearchRegionBias: Equatable {
    var center: CLLocationCoordinate2D
    var radiusMeters: Double

    init(center: CLLocationCoordinate2D, radiusMeters: Double = 50_000) {
        self.center = center
        self.radiusMeters = radiusMeters
    }

    init(regionMetersCenter center: CLLocationCoordinate2D, latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) {
        self.center = center
        self.radiusMeters = max(latitudinalMeters, longitudinalMeters)
    }
}
