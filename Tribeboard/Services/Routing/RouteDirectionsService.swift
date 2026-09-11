import CoreLocation
import Foundation

struct RouteDirectionsResult: Equatable {
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let expectedTravelTimeSeconds: TimeInterval

    static func == (lhs: RouteDirectionsResult, rhs: RouteDirectionsResult) -> Bool {
        lhs.distanceMeters == rhs.distanceMeters
            && lhs.expectedTravelTimeSeconds == rhs.expectedTravelTimeSeconds
            && lhs.coordinates.count == rhs.coordinates.count
            && zip(lhs.coordinates, rhs.coordinates).allSatisfy {
                $0.latitude == $1.latitude && $0.longitude == $1.longitude
            }
    }
}

protocol RouteDirectionsService: Sendable {
    func fetchRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteDirectionsResult
}

enum RouteDirectionsError: Error, Equatable {
    case noRoute
    case invalidCoordinates
}
