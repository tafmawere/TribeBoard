import Foundation

enum RunAdjustmentError: LocalizedError, Equatable {
    case runIsTerminal
    case invalidIndex
    case cannotModifyCompletedStop
    case cannotRemoveOnlyRemainingStop
    case noFutureStopsAvailable
    case invalidStopData

    var errorDescription: String? {
        switch self {
        case .runIsTerminal:
            return "Route adjustment is unavailable for completed or cancelled runs."
        case .invalidIndex:
            return "That stop position is invalid for this run."
        case .cannotModifyCompletedStop:
            return "Completed or active stops cannot be modified."
        case .cannotRemoveOnlyRemainingStop:
            return "A run must keep at least one stop."
        case .noFutureStopsAvailable:
            return "No future stops are available for this action."
        case .invalidStopData:
            return "Please provide a valid stop name and coordinates."
        }
    }
}

struct RunAdjustmentService {
    func insertStop(
        into run: SystemDomain.RunInstance,
        stop: SystemDomain.Stop,
        at index: Int?
    ) throws -> SystemDomain.RunInstance {
        try ensureAdjustable(run)
        try validateStopData(stop)

        var updated = run
        let insertIndex = try resolvedInsertIndex(for: run, index: index)
        let normalizedStop = normalized(stop, order: insertIndex)
        updated.stopSnapshots.insert(normalizedStop, at: insertIndex)
        updated.stops.insert(
            SystemDomain.RunStopProgress(
                stopId: normalizedStop.id,
                status: .pending,
                arrivedAt: nil,
                departedAt: nil
            ),
            at: insertIndex
        )

        reindexStops(&updated)
        return updated
    }

    func removeStop(
        from run: SystemDomain.RunInstance,
        at index: Int
    ) throws -> SystemDomain.RunInstance {
        try ensureAdjustable(run)
        try ensureIndex(index, in: run)

        guard run.stops.count > 1 else {
            throw RunAdjustmentError.cannotRemoveOnlyRemainingStop
        }
        if run.stops[index].status == .completed {
            throw RunAdjustmentError.cannotModifyCompletedStop
        }
        if let active = run.activeStopIndex, index == active {
            throw RunAdjustmentError.cannotModifyCompletedStop
        }
        if run.status == .inProgress, let active = run.activeStopIndex, index < active {
            throw RunAdjustmentError.invalidIndex
        }

        var updated = run
        updated.stopSnapshots.remove(at: index)
        updated.stops.remove(at: index)
        reindexStops(&updated)
        return updated
    }

    func moveStop(
        in run: SystemDomain.RunInstance,
        from sourceIndex: Int,
        to destinationIndex: Int
    ) throws -> SystemDomain.RunInstance {
        try ensureAdjustable(run)
        try ensureIndex(sourceIndex, in: run)
        try ensureIndex(destinationIndex, in: run)

        if sourceIndex == destinationIndex {
            return run
        }
        if run.stops[sourceIndex].status == .completed || run.stops[destinationIndex].status == .completed {
            throw RunAdjustmentError.cannotModifyCompletedStop
        }
        guard isReorderableStatus(run.stops[sourceIndex].status),
              isReorderableStatus(run.stops[destinationIndex].status) else {
            throw RunAdjustmentError.invalidIndex
        }

        if run.status == .inProgress, let active = run.activeStopIndex {
            if sourceIndex <= active || destinationIndex <= active {
                throw RunAdjustmentError.cannotModifyCompletedStop
            }
        }

        var updated = run
        let movedSnapshot = updated.stopSnapshots.remove(at: sourceIndex)
        let movedProgress = updated.stops.remove(at: sourceIndex)
        updated.stopSnapshots.insert(movedSnapshot, at: destinationIndex)
        updated.stops.insert(movedProgress, at: destinationIndex)
        reindexStops(&updated)
        return updated
    }

    func deferStop(
        in run: SystemDomain.RunInstance,
        at index: Int
    ) throws -> SystemDomain.RunInstance {
        try ensureAdjustable(run)
        try ensureIndex(index, in: run)

        if run.stops[index].status == .completed {
            throw RunAdjustmentError.cannotModifyCompletedStop
        }
        if let active = run.activeStopIndex, index == active {
            throw RunAdjustmentError.cannotModifyCompletedStop
        }
        if run.status == .inProgress, let active = run.activeStopIndex, index < active {
            throw RunAdjustmentError.invalidIndex
        }
        let lastFutureIndex = try lastFutureMovableIndex(in: run)
        guard index < lastFutureIndex else {
            throw RunAdjustmentError.noFutureStopsAvailable
        }

        return try moveStop(in: run, from: index, to: lastFutureIndex)
    }

    private func ensureAdjustable(_ run: SystemDomain.RunInstance) throws {
        if run.status == .completed || run.status == .cancelled {
            throw RunAdjustmentError.runIsTerminal
        }
    }

    private func ensureIndex(_ index: Int, in run: SystemDomain.RunInstance) throws {
        guard run.stops.indices.contains(index), run.stopSnapshots.indices.contains(index) else {
            throw RunAdjustmentError.invalidIndex
        }
    }

    private func validateStopData(_ stop: SystemDomain.Stop) throws {
        let trimmed = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RunAdjustmentError.invalidStopData }
        guard (-90.0...90.0).contains(stop.latitude) else { throw RunAdjustmentError.invalidStopData }
        guard (-180.0...180.0).contains(stop.longitude) else { throw RunAdjustmentError.invalidStopData }
    }

    private func resolvedInsertIndex(for run: SystemDomain.RunInstance, index: Int?) throws -> Int {
        let fallback = run.stops.count
        guard let index else { return fallback }
        guard (0...run.stops.count).contains(index) else { throw RunAdjustmentError.invalidIndex }

        if run.status == .inProgress, let active = run.activeStopIndex, index <= active {
            throw RunAdjustmentError.invalidIndex
        }
        if index < run.stops.count, run.stops[index].status == .completed {
            throw RunAdjustmentError.cannotModifyCompletedStop
        }
        return index
    }

    private func lastFutureMovableIndex(in run: SystemDomain.RunInstance) throws -> Int {
        if run.stops.isEmpty {
            throw RunAdjustmentError.noFutureStopsAvailable
        }
        if run.status == .inProgress, let active = run.activeStopIndex {
            let candidate = run.stops.indices.reversed().first { index in
                index > active && isReorderableStatus(run.stops[index].status)
            }
            guard let candidate else {
                throw RunAdjustmentError.noFutureStopsAvailable
            }
            return candidate
        }
        let candidate = run.stops.indices.reversed().first { index in
            isReorderableStatus(run.stops[index].status)
        }
        guard let candidate, run.stops.count > 1 else {
            throw RunAdjustmentError.noFutureStopsAvailable
        }
        return candidate
    }

    private func normalized(_ stop: SystemDomain.Stop, order: Int) -> SystemDomain.Stop {
        SystemDomain.Stop(
            id: stop.id,
            name: stop.name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: stop.latitude,
            longitude: stop.longitude,
            order: order
        )
    }

    private func reindexStops(_ run: inout SystemDomain.RunInstance) {
        for index in run.stopSnapshots.indices {
            run.stopSnapshots[index].order = index
        }
    }

    private func isReorderableStatus(_ status: SystemDomain.StopStatus) -> Bool {
        status == .pending || status == .skipped
    }
}
