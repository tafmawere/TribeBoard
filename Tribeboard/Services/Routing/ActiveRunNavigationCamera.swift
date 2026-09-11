import CoreLocation
import Foundation

enum ActiveRunNavigationCamera {
    static let followZoom: Float = 16
    static let overviewZoom: Float = 14

    static func followCamera(
        driver: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        bearingDegrees: Double?
    ) -> GoogleMapCameraState {
        let bearing = bearingDegrees ?? bearing(from: driver, to: destination)
        return GoogleMapCameraState(
            target: driver,
            zoom: followZoom,
            bearing: bearing,
            viewingAngle: 45
        )
    }

    static func overviewCamera(
        driver: CLLocationCoordinate2D?,
        destination: CLLocationCoordinate2D
    ) -> GoogleMapCameraState? {
        var points = [destination]
        if let driver, RunRouteValidator.isPlausibleCoordinate(driver),
           RunCoordinateGuard.isUsableForActiveRunRouting(driver) {
            points.insert(driver, at: 0)
        }
        guard let region = regionFitting(points: points) else { return nil }
        return GoogleMapCameraState(target: region.center, zoom: overviewZoom)
    }

    static func legRegion(
        driver: CLLocationCoordinate2D?,
        destination: CLLocationCoordinate2D
    ) -> CoordinateRegionDegrees? {
        var points = [destination]
        if let driver, RunRouteValidator.isPlausibleCoordinate(driver) {
            let distance = CLLocation(latitude: driver.latitude, longitude: driver.longitude)
                .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
            if distance <= RunRouteValidationContext().maxRouteDistanceMeters,
               RunCoordinateGuard.isUsableForActiveRunRouting(driver) {
                points.insert(driver, at: 0)
            }
        }
        return regionFitting(points: points)
    }

    static func isReasonableLegDistance(meters: Double?) -> Bool {
        guard let meters, meters.isFinite, meters >= 0 else { return false }
        return meters <= RunRouteValidationContext().maxRouteDistanceMeters
    }

    /// Map camera that never zooms to a world view — always caps span and ignores unusable driver GPS.
    static func activeLegCamera(
        driver: CLLocationCoordinate2D?,
        destination: CLLocationCoordinate2D,
        follow: Bool,
        bearingDegrees: Double?
    ) -> GoogleMapCameraState {
        let usableDriver = driver.flatMap { coord -> CLLocationCoordinate2D? in
            RunCoordinateGuard.isUsableForActiveRunRouting(coord) ? coord : nil
        }

        if follow, let usableDriver {
            return followCamera(
                driver: usableDriver,
                destination: destination,
                bearingDegrees: bearingDegrees
            )
        }

        if let usableDriver {
            return overviewCamera(driver: usableDriver, destination: destination)
                ?? GoogleMapCameraState(target: destination, zoom: overviewZoom)
        }

        return GoogleMapCameraState(target: destination, zoom: overviewZoom)
    }

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return degrees >= 0 ? degrees : degrees + 360
    }

    private static func regionFitting(points: [CLLocationCoordinate2D]) -> CoordinateRegionDegrees? {
        let valid = points.filter(RunRouteValidator.isPlausibleCoordinate)
        guard !valid.isEmpty else { return nil }
        if valid.count == 1, let only = valid.first {
            return CoordinateRegionDegrees(center: only, latitudeDelta: 0.02, longitudeDelta: 0.02)
        }
        let lats = valid.map(\.latitude)
        let lons = valid.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latitudeDelta = max((maxLat - minLat) * 1.5, 0.008)
        let longitudeDelta = max((maxLon - minLon) * 1.5, 0.008)
        return CoordinateRegionDegrees(
            center: center,
            latitudeDelta: min(latitudeDelta, 0.25),
            longitudeDelta: min(longitudeDelta, 0.25)
        )
    }
}
