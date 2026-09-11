import Foundation

struct RunStateMachine {
    func start(_ run: SystemDomain.RunInstance, now: Date) throws -> SystemDomain.RunInstance {
        try throwIfTerminal(run)
        guard run.status == .scheduled || run.status == .assigned else {
            throw RunTransitionError.invalidTransition
        }

        var updated = run
        updated.status = .inProgress
        updated.startedAt = now

        if updated.stops.isEmpty {
            updated.activeStopIndex = nil
        } else {
            updated.activeStopIndex = 0
            if updated.stops[0].status == .pending {
                updated.stops[0].status = .enRoute
            }
        }
        return updated
    }

    func arriveAtStop(_ run: SystemDomain.RunInstance, stopIndex: Int, now: Date) throws -> SystemDomain.RunInstance {
        try throwIfTerminal(run)
        guard run.status == .inProgress else { throw RunTransitionError.notStarted }
        guard let activeIndex = run.activeStopIndex, activeIndex == stopIndex else {
            throw RunTransitionError.invalidStopIndex
        }
        guard run.stops.indices.contains(stopIndex) else {
            throw RunTransitionError.invalidStopIndex
        }

        var updated = run
        updated.stops[stopIndex].status = .arrived
        updated.stops[stopIndex].arrivedAt = now
        return updated
    }

    func departStop(_ run: SystemDomain.RunInstance, stopIndex: Int, now: Date) throws -> SystemDomain.RunInstance {
        try throwIfTerminal(run)
        guard run.status == .inProgress else { throw RunTransitionError.notStarted }
        guard let activeIndex = run.activeStopIndex, activeIndex == stopIndex else {
            throw RunTransitionError.invalidStopIndex
        }
        guard run.stops.indices.contains(stopIndex) else {
            throw RunTransitionError.invalidStopIndex
        }
        guard run.stops[stopIndex].status == .arrived else {
            throw RunTransitionError.invalidTransition
        }
        guard run.stops[stopIndex].arrivedAt != nil else {
            throw RunTransitionError.invalidTransition
        }

        var updated = run
        updated.stops[stopIndex].status = .completed
        updated.stops[stopIndex].departedAt = now
        guard RunStopLifecycle.canMarkCompleted(
            arrivedAt: updated.stops[stopIndex].arrivedAt,
            departedAt: updated.stops[stopIndex].departedAt
        ) else {
            throw RunTransitionError.invalidTransition
        }
        advanceActiveStop(on: &updated)
        return updated
    }

    func skipStop(_ run: SystemDomain.RunInstance, stopIndex: Int, now: Date) throws -> SystemDomain.RunInstance {
        try throwIfTerminal(run)
        guard run.status == .inProgress else { throw RunTransitionError.notStarted }
        guard let activeIndex = run.activeStopIndex, activeIndex == stopIndex else {
            throw RunTransitionError.invalidStopIndex
        }
        guard run.stops.indices.contains(stopIndex) else {
            throw RunTransitionError.invalidStopIndex
        }

        var updated = run
        updated.stops[stopIndex].status = .skipped
        updated.stops[stopIndex].departedAt = now
        advanceActiveStop(on: &updated)
        return updated
    }

    func complete(_ run: SystemDomain.RunInstance, now: Date) throws -> SystemDomain.RunInstance {
        try throwIfTerminal(run)
        guard run.status == .inProgress else { throw RunTransitionError.notStarted }
        let allStopsFinished = run.stops.allSatisfy { $0.status == .completed || $0.status == .skipped }
        guard run.stops.isEmpty || allStopsFinished else {
            throw RunTransitionError.invalidTransition
        }

        var updated = run
        updated.status = .completed
        updated.completedAt = now
        updated.activeStopIndex = nil
        return updated
    }

    func cancel(_ run: SystemDomain.RunInstance, now: Date) throws -> SystemDomain.RunInstance {
        try throwIfTerminal(run)
        guard run.status == .scheduled || run.status == .assigned || run.status == .inProgress else {
            throw RunTransitionError.invalidTransition
        }

        var updated = run
        updated.status = .cancelled
        updated.cancelledAt = now
        updated.activeStopIndex = nil
        return updated
    }

    private func throwIfTerminal(_ run: SystemDomain.RunInstance) throws {
        if run.status == .completed {
            throw RunTransitionError.alreadyCompleted
        }
        if run.status == .cancelled {
            throw RunTransitionError.alreadyCancelled
        }
    }

    private func advanceActiveStop(on run: inout SystemDomain.RunInstance) {
        let nextIndex = run.stops.indices.first(where: { index in
            run.stops[index].status == .pending || run.stops[index].status == .enRoute
        })
        run.activeStopIndex = nextIndex
        if let nextIndex, run.stops[nextIndex].status == .pending {
            run.stops[nextIndex].status = .enRoute
        }
    }
}
