import Foundation

extension SystemDomain {
    enum RunStatus: String, Codable {
        case scheduled
        case inProgress
        case completed
        case cancelled

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            switch rawValue {
            case Self.scheduled.rawValue:
                self = .scheduled
            case Self.inProgress.rawValue, "active", "activeEnroute", "arrivedAtStop", "paused":
                self = .inProgress
            case Self.completed.rawValue:
                self = .completed
            case Self.cancelled.rawValue, "missed":
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
