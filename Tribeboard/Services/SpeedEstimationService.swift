import Foundation
import CoreLocation
import Combine

@MainActor
final class SpeedEstimationService: ObservableObject {
    @Published private(set) var estimatedSpeedMetersPerSecond: Double?
    @Published private(set) var sampleCount: Int = 0
    @Published private(set) var speedVariance: Double?

    private var samples: [(location: CLLocation, timestamp: Date)] = []
    private let maxSamples = 5
    private let minimumIntervalSeconds: TimeInterval = 2
    private let minimumDistanceMeters: Double = 5
    private let maximumAcceptedSpeed: Double = 50

    func ingestLocation(_ location: CLLocation, at timestamp: Date) {
        samples.append((location, timestamp))
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }

        guard samples.count >= 2 else {
            estimatedSpeedMetersPerSecond = nil
            sampleCount = 0
            speedVariance = nil
            return
        }

        var candidateSpeeds: [Double] = []
        for pair in zip(samples, samples.dropFirst()) {
            let from = pair.0
            let to = pair.1
            let dt = to.timestamp.timeIntervalSince(from.timestamp)
            guard dt >= minimumIntervalSeconds else { continue }
            let distance = to.location.distance(from: from.location)
            guard distance >= minimumDistanceMeters else { continue }
            let speed = distance / dt
            guard speed.isFinite, speed >= 0, speed <= maximumAcceptedSpeed else { continue }
            candidateSpeeds.append(speed)
        }

        guard !candidateSpeeds.isEmpty else {
            estimatedSpeedMetersPerSecond = nil
            sampleCount = 0
            speedVariance = nil
            return
        }

        let average = candidateSpeeds.reduce(0, +) / Double(candidateSpeeds.count)
        estimatedSpeedMetersPerSecond = average
        sampleCount = candidateSpeeds.count
        speedVariance = variance(for: candidateSpeeds, mean: average)
    }

    func reset() {
        samples.removeAll()
        estimatedSpeedMetersPerSecond = nil
        sampleCount = 0
        speedVariance = nil
    }

    private func variance(for values: [Double], mean: Double) -> Double? {
        guard values.count >= 2 else { return nil }
        let squaredDiffSum = values.reduce(0.0) { partial, value in
            let delta = value - mean
            return partial + (delta * delta)
        }
        return squaredDiffSum / Double(values.count)
    }
}
