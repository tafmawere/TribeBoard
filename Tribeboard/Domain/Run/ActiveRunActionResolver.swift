import Foundation

enum ActiveRunDriverAction: Equatable {
    case none
    case navigate(stopIndex: Int)
    case arrive(stopIndex: Int)
    case childCollected(stopIndex: Int)
    case complete
}

enum StopLocationKind: Equatable {
    case home
    case school
    case other
}

enum StopLocationClassifier {
    static func kind(for stop: SystemDomain.Stop, index: Int, totalStops: Int) -> StopLocationKind {
        let normalized = stop.name.lowercased()
        if normalized.contains("school") || normalized.contains("college") || normalized.contains("academy") {
            return .school
        }
        if normalized.contains("home") || normalized == "house" {
            return .home
        }
        if index == 0, totalStops >= 2 { return .home }
        if index == totalStops - 1, totalStops >= 2 { return .home }
        if index == 1, totalStops == 3 { return .school }
        return .other
    }
}

enum ActiveRunActionResolver {
    static func primaryAction(for run: SystemDomain.RunInstance) -> ActiveRunDriverAction {
        let state = ActiveRunStateResolver.resolve(for: run)
        switch state {
        case .completed:
            return .complete
        case let .headingToStop(idx):
            return .arrive(stopIndex: idx)
        case .headingToNextStop:
            guard let idx = run.activeStopIndex else { return .none }
            return .arrive(stopIndex: idx)
        case let .arrivedAtStop(idx):
            let stops = run.stopSnapshots.sorted { $0.order < $1.order }
            guard stops.indices.contains(idx) else { return .none }
            let isFinalStop = idx == stops.count - 1
            let kind = StopLocationClassifier.kind(for: stops[idx], index: idx, totalStops: stops.count)
            switch kind {
            case .school:
                return .childCollected(stopIndex: idx)
            case .home:
                return isFinalStop ? .complete : .childCollected(stopIndex: idx)
            case .other:
                return isFinalStop ? .complete : .childCollected(stopIndex: idx)
            }
        }
    }

    static func secondaryAction(for run: SystemDomain.RunInstance) -> ActiveRunDriverAction {
        let state = ActiveRunStateResolver.resolve(for: run)
        switch state {
        case .headingToStop, .headingToNextStop:
            if let idx = run.activeStopIndex {
                return .navigate(stopIndex: idx)
            }
            return .none
        default:
            return .none
        }
    }

    static func primaryButtonTitle(for action: ActiveRunDriverAction, run: SystemDomain.RunInstance) -> String {
        switch action {
        case .none: return "—"
        case .navigate: return "Follow route"
        case .arrive:
            return "Arrived"
        case let .childCollected(idx):
            let stops = run.stopSnapshots.sorted { $0.order < $1.order }
            if stops.indices.contains(idx),
               StopLocationClassifier.kind(for: stops[idx], index: idx, totalStops: stops.count) == .school {
                return "Child collected"
            }
            return "Head home"
        case .complete:
            return "Complete Run"
        }
    }

    static func secondaryButtonTitle(for action: ActiveRunDriverAction, isFollowingRoute: Bool) -> String {
        switch action {
        case .navigate:
            return isFollowingRoute ? "Recenter route" : "Follow route"
        default: return ""
        }
    }

    static func allowsPrimaryAction(_ action: ActiveRunDriverAction) -> Bool {
        switch action {
        case .none: return false
        default: return true
        }
    }
}
