import Foundation
import GooglePlaces

enum GooglePlaceResolveService {
    static func fetchResolvedPlace(placeID: String) async throws -> (
        name: String,
        formattedAddress: String,
        latitude: Double,
        longitude: Double
    ) {
        try await withCheckedThrowingContinuation { continuation in
            let fields: GMSPlaceField = [.placeID, .name, .formattedAddress, .coordinate]
            GMSPlacesClient.shared().fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { place, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let place else {
                    continuation.resume(throwing: NSError(domain: "GooglePlaceResolveService", code: -1))
                    return
                }
                let name = (place.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let formatted = (place.formattedAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let coordinate = place.coordinate
                let resolvedName = name.isEmpty ? formatted : name
                let resolvedAddress = formatted.isEmpty ? resolvedName : formatted
                continuation.resume(
                    returning: (
                        name: resolvedName,
                        formattedAddress: resolvedAddress,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                )
            }
        }
    }
}
