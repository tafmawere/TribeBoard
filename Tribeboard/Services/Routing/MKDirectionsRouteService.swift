import CoreLocation
import Foundation
import MapKit

struct MKDirectionsRouteService: RouteDirectionsService {
    func fetchRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteDirectionsResult {
        guard RunRouteValidator.isPlausibleCoordinate(origin),
              RunRouteValidator.isPlausibleCoordinate(destination) else {
            throw RouteDirectionsError.invalidCoordinates
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RouteDirectionsError.noRoute
        }

        let coordinates = polylineCoordinates(from: route.polyline)
        guard !coordinates.isEmpty else {
            throw RouteDirectionsError.noRoute
        }

        return RouteDirectionsResult(
            coordinates: coordinates,
            distanceMeters: route.distance,
            expectedTravelTimeSeconds: route.expectedTravelTime
        )
    }

    private func polylineCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords.filter { RunRouteValidator.isPlausibleCoordinate($0) }
    }
}
