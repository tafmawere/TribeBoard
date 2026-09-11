import Foundation

struct RunJourneyStatus: Equatable {
    let headline: String
    let detail: String?
    let phase: ActiveRunState
}

enum RunJourneyStatusBuilder {
    static func build(
        run: SystemDomain.RunInstance,
        childDisplayName: String,
        etaMinutes: Int?
    ) -> RunJourneyStatus {
        let child = childDisplayName.split(separator: " ").first.map(String.init) ?? childDisplayName
        let state = ActiveRunStateResolver.resolve(for: run)
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        let etaSuffix: String = {
            guard let etaMinutes, etaMinutes >= 0, etaMinutes <= ETADisplayFormatter.maxReasonableMinutes else {
                return ""
            }
            return " · ETA \(etaMinutes) min"
        }()

        switch state {
        case let .headingToStop(idx), let .headingToNextStop(idx):
            let stopName = stops.indices.contains(idx) ? stops[idx].name : "destination"
            let kind = stops.indices.contains(idx)
                ? StopLocationClassifier.kind(for: stops[idx], index: idx, totalStops: stops.count)
                : .other
            let verb: String
            switch kind {
            case .home: verb = "is on the way home"
            case .school: verb = "is on the way to \(stopName)"
            case .other: verb = "is on the way to \(stopName)"
            }
            return RunJourneyStatus(
                headline: "\(child) \(verb)\(etaSuffix)",
                detail: nil,
                phase: state
            )

        case let .arrivedAtStop(idx):
            let stopName = stops.indices.contains(idx) ? stops[idx].name : "stop"
            let kind = stops.indices.contains(idx)
                ? StopLocationClassifier.kind(for: stops[idx], index: idx, totalStops: stops.count)
                : .other
            switch kind {
            case .school:
                return RunJourneyStatus(
                    headline: "\(child) is at \(stopName)",
                    detail: "Waiting for pickup",
                    phase: state
                )
            case .home:
                return RunJourneyStatus(
                    headline: "\(child) arrived home safely",
                    detail: nil,
                    phase: state
                )
            case .other:
                return RunJourneyStatus(
                    headline: "\(child) is at \(stopName)",
                    detail: nil,
                    phase: state
                )
            }

        case .completed:
            return RunJourneyStatus(
                headline: "\(child) arrived home safely",
                detail: nil,
                phase: .completed
            )
        }
    }
}
