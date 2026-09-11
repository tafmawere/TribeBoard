import Foundation

extension SystemDomain {
    enum RunStatus: String, Codable {
        case scheduled
        case assigned
        case inProgress
        case completed
        case cancelled

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            switch rawValue {
            case Self.scheduled.rawValue, "scheduled":
                self = .scheduled
            case Self.assigned.rawValue, "assigned":
                self = .assigned
            case Self.inProgress.rawValue, "in_progress", "active", "activeEnroute", "arrivedAtStop", "paused":
                self = .inProgress
            case Self.completed.rawValue, "completed":
                self = .completed
            case Self.cancelled.rawValue, "cancelled", "missed":
                self = .cancelled
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unsupported run status '\(rawValue)'"
                )
            }
        }
    }
}
