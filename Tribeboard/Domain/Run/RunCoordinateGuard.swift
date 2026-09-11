import CoreLocation
import Foundation

/// Guards active-run routing coordinates. In DEBUG builds, rejects points outside South Africa
/// so simulator default locations (e.g. Cupertino) do not produce world-spanning routes.
enum RunCoordinateGuard {
    struct SouthAfricaBounds {
        static let minLatitude = -35.0
        static let maxLatitude = -22.0
        static let minLongitude = 16.0
        static let maxLongitude = 33.0
    }

    static var enforceSouthAfricaBounds: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func isWithinSouthAfrica(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard RunRouteValidator.isPlausibleCoordinate(coordinate) else { return false }
        return coordinate.latitude >= SouthAfricaBounds.minLatitude
            && coordinate.latitude <= SouthAfricaBounds.maxLatitude
            && coordinate.longitude >= SouthAfricaBounds.minLongitude
            && coordinate.longitude <= SouthAfricaBounds.maxLongitude
    }

    /// Whether a coordinate may be used as driver origin or for leg distance / ETA.
    static func isUsableForActiveRunRouting(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard RunRouteValidator.isPlausibleCoordinate(coordinate) else { return false }
        if enforceSouthAfricaBounds {
            return isWithinSouthAfrica(coordinate)
        }
        return true
    }

    static func rejectionReason(for coordinate: CLLocationCoordinate2D, label: String) -> String? {
        guard RunRouteValidator.isPlausibleCoordinate(coordinate) else {
            return "\(label) has invalid coordinates"
        }
        guard enforceSouthAfricaBounds, !isWithinSouthAfrica(coordinate) else { return nil }
        return "\(label) is outside South Africa testing bounds " +
            "(lat=\(coordinate.latitude), lon=\(coordinate.longitude))"
    }

    static func format(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}
