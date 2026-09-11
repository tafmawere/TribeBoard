import Foundation
import CoreLocation

struct ETAPrediction: Equatable {
    let runId: UUID
    let nextStopName: String
    let nextStopDistanceMeters: Double
    let nextStopETA: Date
    let finalStopName: String
    let finalStopETA: Date
    let estimatedMinutesRemaining: Int
    let quality: ETAQuality
}

struct ETAConfig: Equatable {
    let minimumSpeedMetersPerSecond: Double
    let defaultSpeedMetersPerSecond: Double
    let dwellTimePerStopSeconds: Double
}

extension ETAConfig {
    static let `default` = ETAConfig(
        minimumSpeedMetersPerSecond: 3.0,
        defaultSpeedMetersPerSecond: 8.33,
        dwellTimePerStopSeconds: 90
    )
}

struct ETAEngine {
    func predict(
        run: SystemDomain.RunInstance,
        currentLocation: CLLocation,
        now: Date,
        config: ETAConfig = .default,
        liveSpeedMetersPerSecond: Double? = nil,
        sampleCount: Int = 0,
        speedVariance: Double? = nil
    ) -> ETAPrediction? {
        guard run.status != .completed, run.status != .cancelled else { return nil }

        let orderedStops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard !orderedStops.isEmpty else { return nil }

        let firstTargetIndex = firstTargetStopIndex(for: run, orderedStops: orderedStops)
        guard let firstTargetIndex else { return nil }

        let visitableIndices = orderedStops.indices.filter { index in
            guard index >= firstTargetIndex, run.stops.indices.contains(index) else { return false }
            let status = run.stops[index].status
            return status != .completed && status != .skipped
        }
        guard let nextIndex = visitableIndices.first, let finalIndex = visitableIndices.last else {
            return nil
        }

        let nextStop = orderedStops[nextIndex]
        let finalStop = orderedStops[finalIndex]

        guard isValidCoordinate(nextStop), isValidCoordinate(finalStop) else {
            NSLog("[RunRoute] invalid coordinates")
            return nil
        }

        let routeCoordinates = visitableIndices.map { orderedStops[$0] }.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let routeDistance = RunRouteValidator.polylineDistanceMeters(routeCoordinates)
        if routeDistance > RunRouteValidationContext().maxRouteDistanceMeters {
            NSLog("[RunRoute] invalid route distance=\(routeDistance)")
            return nil
        }

        let usedLiveSpeed = liveSpeedMetersPerSecond != nil
        let selectedSpeed = liveSpeedMetersPerSecond ?? config.defaultSpeedMetersPerSecond
        let speed = max(config.minimumSpeedMetersPerSecond, selectedSpeed)
        let nextLocation = CLLocation(latitude: nextStop.latitude, longitude: nextStop.longitude)
        let nextDistance = currentLocation.distance(from: nextLocation)
        let nextTravelSeconds = nextDistance / speed
        let nextETA = now.addingTimeInterval(nextTravelSeconds)

        var totalSeconds = nextTravelSeconds
        if visitableIndices.count > 1 {
            for pair in zip(visitableIndices, visitableIndices.dropFirst()) {
                let from = orderedStops[pair.0]
                let to = orderedStops[pair.1]
                guard isValidCoordinate(from), isValidCoordinate(to) else { return nil }
                let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
                let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
                totalSeconds += fromLocation.distance(from: toLocation) / speed
            }
            let dwellStops = max(0, visitableIndices.count - 1)
            totalSeconds += Double(dwellStops) * config.dwellTimePerStopSeconds
        }

        let finalETA = now.addingTimeInterval(totalSeconds)
        let minutesRemaining = max(0, Int(ceil(totalSeconds / 60.0)))
        let quality = qualityForPrediction(
            usedLiveSpeed: usedLiveSpeed,
            sampleCount: sampleCount,
            speedVariance: speedVariance,
            visitableStopsCount: visitableIndices.count,
            nextDistanceMeters: nextDistance
        )

        return ETAPrediction(
            runId: run.id,
            nextStopName: nextStop.name,
            nextStopDistanceMeters: nextDistance,
            nextStopETA: nextETA,
            finalStopName: finalStop.name,
            finalStopETA: finalETA,
            estimatedMinutesRemaining: minutesRemaining,
            quality: quality
        )
    }

    private func firstTargetStopIndex(
        for run: SystemDomain.RunInstance,
        orderedStops: [SystemDomain.Stop]
    ) -> Int? {
        if run.status == .inProgress {
            if let active = run.activeStopIndex, orderedStops.indices.contains(active) {
                let activeStatus = run.stops.indices.contains(active) ? run.stops[active].status : .pending
                if activeStatus != .completed && activeStatus != .skipped {
                    return active
                }
            }
            if let active = run.activeStopIndex {
                let start = active + 1
                guard start < orderedStops.count else { return nil }
                return orderedStops.indices.first(where: { index in
                    index >= start && run.stops.indices.contains(index) &&
                        run.stops[index].status != .completed &&
                        run.stops[index].status != .skipped
                })
            }
        }

        return orderedStops.indices.first(where: { index in
            run.stops.indices.contains(index) &&
                run.stops[index].status != .completed &&
                run.stops[index].status != .skipped
        })
    }

    private func isValidCoordinate(_ stop: SystemDomain.Stop) -> Bool {
        RunRouteValidator.isPlausibleCoordinate(
            CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
        )
    }

    private func qualityForPrediction(
        usedLiveSpeed: Bool,
        sampleCount: Int,
        speedVariance: Double?,
        visitableStopsCount: Int,
        nextDistanceMeters: Double
    ) -> ETAQuality {
        let variance = speedVariance ?? 0

        if usedLiveSpeed, sampleCount >= 3, variance <= 9 {
            return ETAQuality(
                confidence: .high,
                sampleCount: sampleCount,
                usedLiveSpeed: true,
                speedVariance: speedVariance,
                reason: "ETA based on stable live movement"
            )
        }

        if usedLiveSpeed, sampleCount >= 1, variance <= 25 {
            return ETAQuality(
                confidence: .medium,
                sampleCount: sampleCount,
                usedLiveSpeed: true,
                speedVariance: speedVariance,
                reason: sampleCount < 3
                    ? "Low confidence due to limited movement samples"
                    : "Using live speed estimate"
            )
        }

        if !usedLiveSpeed, visitableStopsCount <= 2, nextDistanceMeters <= 5000 {
            return ETAQuality(
                confidence: .medium,
                sampleCount: sampleCount,
                usedLiveSpeed: false,
                speedVariance: speedVariance,
                reason: "Using default speed"
            )
        }

        return ETAQuality(
            confidence: .low,
            sampleCount: sampleCount,
            usedLiveSpeed: usedLiveSpeed,
            speedVariance: speedVariance,
            reason: usedLiveSpeed ? "Low confidence due to unstable movement samples" : "Using default speed"
        )
    }
}
