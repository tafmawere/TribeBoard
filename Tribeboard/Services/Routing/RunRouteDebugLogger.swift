import CoreLocation
import Foundation

enum RunRouteDebugLogger {
    static func logRouteAttempt(
        runId: UUID,
        stopIndex: Int,
        origin: CLLocationCoordinate2D?,
        destination: CLLocationCoordinate2D,
        currentLocation: CLLocation?
    ) {
        #if DEBUG
        let originText = origin.map(RunCoordinateGuard.format) ?? "nil"
        let locationText = currentLocation.map { RunCoordinateGuard.format($0.coordinate) } ?? "nil"
        NSLog(
            "[ActiveRunRoute] attempt run=\(runId.uuidString) stopIndex=\(stopIndex) " +
            "currentLocation=\(locationText) origin=\(originText) " +
            "destination=\(RunCoordinateGuard.format(destination))"
        )
        if let origin {
            if let reason = RunCoordinateGuard.rejectionReason(for: origin, label: "origin") {
                NSLog("[ActiveRunRoute] rejected origin: \(reason)")
            }
        }
        if let reason = RunCoordinateGuard.rejectionReason(for: destination, label: "destination") {
            NSLog("[ActiveRunRoute] rejected destination: \(reason)")
        }
        #endif
    }

    static func logRouteResult(
        runId: UUID,
        distanceMeters: Double?,
        etaSeconds: TimeInterval?,
        polylinePointCount: Int,
        source: String
    ) {
        #if DEBUG
        let distanceText = distanceMeters.map { String(format: "%.0f m", $0) } ?? "nil"
        let etaText = etaSeconds.map { String(format: "%.0f s", $0) } ?? "nil"
        NSLog(
            "[ActiveRunRoute] result run=\(runId.uuidString) source=\(source) " +
            "distance=\(distanceText) eta=\(etaText) polylinePoints=\(polylinePointCount)"
        )
        #endif
    }

    static func logRouteFailure(runId: UUID, message: String) {
        #if DEBUG
        NSLog("[ActiveRunRoute] failed run=\(runId.uuidString) reason=\(message)")
        #endif
    }
}
