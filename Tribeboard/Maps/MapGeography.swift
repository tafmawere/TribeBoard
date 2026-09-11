import CoreLocation
import Foundation

/// Map framing in lat/lon deltas (replaces `MKCoordinateRegion` in shared run-map models).
struct CoordinateRegionDegrees: Equatable {
    var center: CLLocationCoordinate2D
    var latitudeDelta: Double
    var longitudeDelta: Double

    init(center: CLLocationCoordinate2D, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    init(center: CLLocationCoordinate2D, latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) {
        self.center = center
        let spanLat = Self.metersToLatitudeDegrees(meters: latitudinalMeters)
        let spanLon = Self.metersToLongitudeDegrees(meters: longitudinalMeters, atLatitude: center.latitude)
        self.latitudeDelta = max(spanLat, 0.000_5)
        self.longitudeDelta = max(spanLon, 0.000_5)
    }

    private static func metersToLatitudeDegrees(meters: CLLocationDistance) -> Double {
        meters / 111_320.0
    }

    private static func metersToLongitudeDegrees(meters: CLLocationDistance, atLatitude latitude: Double) -> Double {
        let cosLat = max(0.2, cos(latitude * .pi / 180.0))
        return meters / (111_320.0 * cosLat)
    }

    /// Fits a camera region around coordinate bounds (used by route previews and replay).
    static func fittingCoordinates(
        _ coordinates: [CLLocationCoordinate2D],
        fallback: CLLocationCoordinate2D,
        paddingFactor: Double = 1.55,
        minimumDelta: Double = 0.012
    ) -> CoordinateRegionDegrees {
        guard !coordinates.isEmpty else {
            return CoordinateRegionDegrees(
                center: fallback,
                latitudeDelta: minimumDelta,
                longitudeDelta: minimumDelta
            )
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max()
        else {
            return CoordinateRegionDegrees(
                center: fallback,
                latitudeDelta: minimumDelta,
                longitudeDelta: minimumDelta
            )
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latDelta = max(minimumDelta, (maxLat - minLat) * paddingFactor)
        let lonDelta = max(minimumDelta, (maxLon - minLon) * paddingFactor)
        return CoordinateRegionDegrees(
            center: center,
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
    }
}
