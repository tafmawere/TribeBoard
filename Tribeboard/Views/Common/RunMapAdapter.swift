import CoreLocation
import Foundation

struct RunMapPoint: Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let kind: RunMapPointKind

    static func == (lhs: RunMapPoint, rhs: RunMapPoint) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.kind == rhs.kind
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum RunMapPointKind: Equatable {
    case driver
    case stopPending
    case stopActive
    case stopCompleted
    case stopSkipped
}

struct RunMapModel: Equatable {
    let points: [RunMapPoint]
    let region: CoordinateRegionDegrees?

    static func == (lhs: RunMapModel, rhs: RunMapModel) -> Bool {
        guard lhs.points == rhs.points else { return false }
        switch (lhs.region, rhs.region) {
        case (nil, nil):
            return true
        case let (.some(left), .some(right)):
            return left.center.latitude == right.center.latitude
                && left.center.longitude == right.center.longitude
                && left.latitudeDelta == right.latitudeDelta
                && left.longitudeDelta == right.longitudeDelta
        default:
            return false
        }
    }
}

struct RunMapAdapter {
    static let driverPointID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func makeModel(
        run: SystemDomain.RunInstance,
        currentLocation: CLLocation?,
        routeContext: RunRouteValidationContext = RunRouteValidationContext()
    ) -> RunMapModel {
        let routeValidation = RunRouteValidator.validate(run: run, context: routeContext)
        guard routeValidation.isValid else {
            if let fallback = RunRouteValidator.fallbackMapCenter(run: run, context: routeContext) {
                return RunMapModel(
                    points: [],
                    region: CoordinateRegionDegrees(
                        center: fallback,
                        latitudeDelta: 0.02,
                        longitudeDelta: 0.02
                    )
                )
            }
            return RunMapModel(points: [], region: nil)
        }

        var points: [RunMapPoint] = []

        if let currentLocation,
           RunRouteValidator.isPlausibleCoordinate(currentLocation.coordinate) {
            points.append(
                RunMapPoint(
                    id: Self.driverPointID,
                    name: "Driver",
                    coordinate: currentLocation.coordinate,
                    kind: .driver
                )
            )
        }

        let activeIndex = run.activeStopIndex
        let progressByStopId = Dictionary(uniqueKeysWithValues: run.stops.map { ($0.stopId, $0) })

        for stop in run.stopSnapshots.sorted(by: { $0.order < $1.order }) {
            let coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            guard RunRouteValidator.isPlausibleCoordinate(coordinate) else { continue }

            let progress = progressByStopId[stop.id]
            let kind: RunMapPointKind
            if let activeIndex,
               run.stops.indices.contains(activeIndex),
               run.stops[activeIndex].stopId == stop.id {
                kind = .stopActive
            } else {
                switch progress?.status {
                case .completed:
                    kind = .stopCompleted
                case .skipped:
                    kind = .stopSkipped
                default:
                    kind = .stopPending
                }
            }

            points.append(
                RunMapPoint(
                    id: stop.id,
                    name: stop.name,
                    coordinate: coordinate,
                    kind: kind
                )
            )
        }

        return RunMapModel(points: points, region: regionFitting(points: points, run: run, context: routeContext))
    }

    /// Ordered coordinates along scheduled stops (for route polyline on the map).
    func orderedRouteCoordinates(
        for run: SystemDomain.RunInstance,
        context: RunRouteValidationContext = RunRouteValidationContext()
    ) -> [CLLocationCoordinate2D] {
        guard RunRouteValidator.validate(run: run, context: context).isValid else {
            return []
        }
        return RunRouteValidator.validCoordinates(for: run)
    }

    /// Remaining stops from the active stop onward (straight-line fallback).
    func remainingRouteCoordinates(
        for run: SystemDomain.RunInstance,
        context: RunRouteValidationContext = RunRouteValidationContext()
    ) -> [CLLocationCoordinate2D] {
        guard RunRouteValidator.validate(run: run, context: context).isValid else { return [] }
        let ordered = run.stopSnapshots.sorted { $0.order < $1.order }
        let coords = ordered.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            .filter(RunRouteValidator.isPlausibleCoordinate)
        guard let activeIndex = run.activeStopIndex else { return coords }
        let startOrder = ordered.indices.contains(activeIndex) ? ordered[activeIndex].order : 0
        return ordered
            .filter { $0.order >= startOrder }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            .filter(RunRouteValidator.isPlausibleCoordinate)
    }

    func roadRouteCoordinates(
        roadLeg: [CLLocationCoordinate2D],
        run: SystemDomain.RunInstance,
        context: RunRouteValidationContext = RunRouteValidationContext()
    ) -> [CLLocationCoordinate2D] {
        if !roadLeg.isEmpty { return roadLeg }
        return remainingRouteCoordinates(for: run, context: context)
    }

    private func regionFitting(
        points: [RunMapPoint],
        run: SystemDomain.RunInstance,
        context: RunRouteValidationContext
    ) -> CoordinateRegionDegrees? {
        guard !points.isEmpty else {
            guard let fallback = RunRouteValidator.fallbackMapCenter(run: run, context: context) else {
                return nil
            }
            return CoordinateRegionDegrees(
                center: fallback,
                latitudeDelta: 0.02,
                longitudeDelta: 0.02
            )
        }

        if points.count == 1, let only = points.first {
            return CoordinateRegionDegrees(
                center: only.coordinate,
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        }

        let latitudes = points.map { $0.coordinate.latitude }
        let longitudes = points.map { $0.coordinate.longitude }
        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else {
            return nil
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latitudeDelta = max((maxLat - minLat) * 1.4, 0.006)
        let longitudeDelta = max((maxLon - minLon) * 1.4, 0.006)

        return CoordinateRegionDegrees(
            center: center,
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    }
}
