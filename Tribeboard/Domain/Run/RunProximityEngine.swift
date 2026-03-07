import Foundation
import CoreLocation

struct RunProximity {
    let runId: UUID
    let stopName: String
    let distanceMeters: Double
    let withinArrivalRadius: Bool
}

struct RunProximityEngine {
    func evaluate(
        run: SystemDomain.RunInstance,
        driverLocation: CLLocation
    ) -> RunProximity? {
        guard run.assignedDriverId != nil else { return nil }
        guard !run.stops.isEmpty else { return nil }

        let targetStopProgress: SystemDomain.RunStopProgress?
        if run.status == .inProgress,
           let activeIndex = run.activeStopIndex,
           run.stops.indices.contains(activeIndex) {
            targetStopProgress = run.stops[activeIndex]
        } else {
            targetStopProgress = run.stops.first(where: { $0.status == .pending || $0.status == .enRoute || $0.status == .arrived })
        }

        guard let stopProgress = targetStopProgress else { return nil }
        guard let stop = run.stopSnapshots.first(where: { $0.id == stopProgress.stopId }) else { return nil }

        let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        let distanceMeters = driverLocation.distance(from: stopLocation)

        return RunProximity(
            runId: run.id,
            stopName: stop.name,
            distanceMeters: distanceMeters,
            withinArrivalRadius: distanceMeters <= AppSettings.arrivalRadiusMeters
        )
    }
}
