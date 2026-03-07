import Foundation
import Combine

@MainActor
final class ETASmoothingService: ObservableObject {
    private struct SmoothedState {
        var prediction: ETAPrediction
        var lastUpdatedAt: Date
        var lastAccessedAt: Date
    }

    private var statesByRunID: [UUID: SmoothedState] = [:]
    private let staleEntryThreshold: TimeInterval = 10 * 60

    func smoothedETA(
        for runId: UUID,
        newPrediction: ETAPrediction,
        now: Date = Date()
    ) -> ETAPrediction {
        cleanupStaleEntries(now: now)
        guard let previous = statesByRunID[runId] else {
            let state = SmoothedState(prediction: newPrediction, lastUpdatedAt: now, lastAccessedAt: now)
            statesByRunID[runId] = state
            return newPrediction
        }

        if previous.prediction.nextStopName != newPrediction.nextStopName {
            let state = SmoothedState(prediction: newPrediction, lastUpdatedAt: now, lastAccessedAt: now)
            statesByRunID[runId] = state
            return newPrediction
        }

        let previousMinutes = previous.prediction.estimatedMinutesRemaining
        let newMinutes = newPrediction.estimatedMinutesRemaining
        let minuteDelta = abs(newMinutes - previousMinutes)
        let confidenceImproved = confidenceRank(newPrediction.quality.confidence) > confidenceRank(previous.prediction.quality.confidence)

        let shouldHoldPrevious = minuteDelta <= 1 && !confidenceImproved
        if shouldHoldPrevious {
            let held = ETAPrediction(
                runId: newPrediction.runId,
                nextStopName: newPrediction.nextStopName,
                nextStopDistanceMeters: newPrediction.nextStopDistanceMeters,
                nextStopETA: previous.prediction.nextStopETA,
                finalStopName: newPrediction.finalStopName,
                finalStopETA: previous.prediction.finalStopETA,
                estimatedMinutesRemaining: previous.prediction.estimatedMinutesRemaining,
                quality: newPrediction.quality
            )
            statesByRunID[runId] = SmoothedState(prediction: held, lastUpdatedAt: now, lastAccessedAt: now)
            return held
        }

        let updated = SmoothedState(prediction: newPrediction, lastUpdatedAt: now, lastAccessedAt: now)
        statesByRunID[runId] = updated
        return newPrediction
    }

    func clear(runId: UUID) {
        statesByRunID.removeValue(forKey: runId)
    }

    func clearAll() {
        statesByRunID.removeAll()
    }

    func clearTerminalRuns(using runs: [SystemDomain.RunInstance]) {
        let terminalIDs = Set(runs.filter { $0.status == .completed || $0.status == .cancelled }.map(\.id))
        guard !terminalIDs.isEmpty else { return }
        statesByRunID = statesByRunID.filter { !terminalIDs.contains($0.key) }
    }

    private func cleanupStaleEntries(now: Date) {
        statesByRunID = statesByRunID.filter { _, state in
            now.timeIntervalSince(state.lastAccessedAt) <= staleEntryThreshold
        }
    }

    private func confidenceRank(_ level: ETAConfidenceLevel) -> Int {
        switch level {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}
