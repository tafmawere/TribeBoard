import Foundation

/// UI-facing run execution phase for map-first driver and observer experiences.
enum ActiveRunState: Equatable {
    case headingToStop(stopIndex: Int)
    case arrivedAtStop(stopIndex: Int)
    case headingToNextStop(fromIndex: Int)
    case completed
}

enum ActiveRunStateResolver {
    static func resolve(for run: SystemDomain.RunInstance) -> ActiveRunState {
        guard run.status == .inProgress else {
            if run.status == .completed { return .completed }
            return .headingToStop(stopIndex: 0)
        }

        let allDone = run.stops.allSatisfy { $0.status == .completed || $0.status == .skipped }
        if !run.stops.isEmpty, allDone {
            return .completed
        }

        guard let idx = run.activeStopIndex, run.stops.indices.contains(idx) else {
            return .headingToStop(stopIndex: 0)
        }

        switch run.stops[idx].status {
        case .pending, .enRoute:
            if idx > 0, run.stops[idx - 1].status == .completed || run.stops[idx - 1].status == .skipped {
                return .headingToNextStop(fromIndex: idx - 1)
            }
            return .headingToStop(stopIndex: idx)
        case .arrived:
            return .arrivedAtStop(stopIndex: idx)
        case .completed, .skipped:
            if let next = run.stops.indices.first(where: { i in
                i > idx && (run.stops[i].status == .pending || run.stops[i].status == .enRoute)
            }) {
                return .headingToNextStop(fromIndex: idx)
            }
            return allDone ? .completed : .headingToStop(stopIndex: idx)
        }
    }
}
