import Foundation
import CoreLocation
import MapKit

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
    let region: MKCoordinateRegion?

    static func == (lhs: RunMapModel, rhs: RunMapModel) -> Bool {
        guard lhs.points == rhs.points else { return false }
        switch (lhs.region, rhs.region) {
        case (nil, nil):
            return true
        case let (.some(left), .some(right)):
            return left.center.latitude == right.center.latitude
                && left.center.longitude == right.center.longitude
                && left.span.latitudeDelta == right.span.latitudeDelta
                && left.span.longitudeDelta == right.span.longitudeDelta
        default:
            return false
        }
    }
}

struct RunMapAdapter {
    private static let driverPointID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func makeModel(
        run: SystemDomain.RunInstance,
        currentLocation: CLLocation?
    ) -> RunMapModel {
        var points: [RunMapPoint] = []

        if let currentLocation {
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
                    coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                    kind: kind
                )
            )
        }

        return RunMapModel(points: points, region: regionFitting(points: points))
    }

    private func regionFitting(points: [RunMapPoint]) -> MKCoordinateRegion? {
        guard !points.isEmpty else { return nil }

        if points.count == 1, let only = points.first {
            return MKCoordinateRegion(
                center: only.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
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

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}
