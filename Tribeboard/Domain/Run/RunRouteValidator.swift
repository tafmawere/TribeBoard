import CoreLocation
import Foundation

struct RunRouteValidationContext: Equatable {
    var homeCoordinate: CLLocationCoordinate2D?
    /// Max distance from home anchor for a coordinate to be considered in-region (meters).
    var regionalRadiusMeters: Double = 800_000
    /// Max total route distance for a school run (meters).
    var maxRouteDistanceMeters: Double = 150_000
}

enum RunRouteValidationResult: Equatable {
    case valid(validStopCount: Int, totalDistanceMeters: Double)
    case invalid(reason: RunRouteInvalidReason)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

enum RunRouteInvalidReason: Equatable {
    case insufficientStops
    case invalidCoordinates
    case unrealisticDistance(Double)
    case outsideRegionalBounds
}

enum RunRouteValidator {
    static func validate(
        run: SystemDomain.RunInstance,
        context: RunRouteValidationContext = RunRouteValidationContext()
    ) -> RunRouteValidationResult {
        let orderedStops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard orderedStops.count >= 2 else {
            return .invalid(reason: .insufficientStops)
        }

        let coordinates = orderedStops.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        if let invalidStop = orderedStops.first(where: {
            !isPlausibleCoordinate(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
        }) {
            NSLog(
                "[RunRoute] invalid coordinates stop=\(invalidStop.name) " +
                "lat=\(invalidStop.latitude) lon=\(invalidStop.longitude)"
            )
            return .invalid(reason: .invalidCoordinates)
        }

        if let home = context.homeCoordinate, isPlausibleCoordinate(home) {
            let outOfRegion = coordinates.contains { coordinate in
                distanceMeters(from: home, to: coordinate) > context.regionalRadiusMeters
            }
            if outOfRegion {
                NSLog("[RunRoute] invalid coordinates")
                return .invalid(reason: .outsideRegionalBounds)
            }
        }

        let totalDistance = polylineDistanceMeters(coordinates)
        if totalDistance > context.maxRouteDistanceMeters {
            NSLog("[RunRoute] invalid route distance=\(totalDistance)")
            return .invalid(reason: .unrealisticDistance(totalDistance))
        }

        return .valid(validStopCount: orderedStops.count, totalDistanceMeters: totalDistance)
    }

    static func isPlausibleCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return false }
        guard (-90.0...90.0).contains(coordinate.latitude),
              (-180.0...180.0).contains(coordinate.longitude) else {
            return false
        }
        let isNullIsland = abs(coordinate.latitude) < 0.0001 && abs(coordinate.longitude) < 0.0001
        return !isNullIsland
    }

    static func validCoordinates(for run: SystemDomain.RunInstance) -> [CLLocationCoordinate2D] {
        run.stopSnapshots
            .sorted { $0.order < $1.order }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            .filter(isPlausibleCoordinate)
    }

    static func fallbackMapCenter(
        run: SystemDomain.RunInstance,
        context: RunRouteValidationContext
    ) -> CLLocationCoordinate2D? {
        if let home = context.homeCoordinate, isPlausibleCoordinate(home) {
            NSLog("[RunRoute] using fallback map center=home")
            return home
        }
        let valid = validCoordinates(for: run)
        if let first = valid.first {
            NSLog("[RunRoute] using fallback map center=first-valid-stop")
            return first
        }
        NSLog("[RunRoute] using fallback map center=none")
        return nil
    }

    static func polylineDistanceMeters(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        var total: CLLocationDistance = 0
        for index in 0..<(coordinates.count - 1) {
            let start = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            let end = CLLocation(latitude: coordinates[index + 1].latitude, longitude: coordinates[index + 1].longitude)
            total += start.distance(from: end)
        }
        return total
    }

    private static func distanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let start = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let end = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return start.distance(from: end)
    }

    static func userFacingMessage(for result: RunRouteValidationResult, run: SystemDomain.RunInstance) -> String? {
        guard case let .invalid(reason) = result else { return nil }
        switch reason {
        case .insufficientStops:
            return "Route needs attention. Add at least two stops before starting."
        case .invalidCoordinates:
            let badStop = run.stopSnapshots.sorted { $0.order < $1.order }.first {
                !isPlausibleCoordinate(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
            }
            if let badStop {
                return "Route needs attention. \(badStop.name) location is missing or invalid."
            }
            return "Route needs attention. A stop location is missing or invalid."
        case .unrealisticDistance:
            return "Route needs attention. Total distance exceeds 150 km."
        case .outsideRegionalBounds:
            return "Route needs attention. A stop is too far from home."
        }
    }
}
