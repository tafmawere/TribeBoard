import Foundation

extension SystemDomain {
    enum StopStatus: String, Codable {
        case pending
        case enRoute
        case arrived
        case completed
        case skipped
    }

    struct RunStopProgress: Codable, Equatable {
        let stopId: UUID
        var status: StopStatus
        var arrivedAt: Date?
        var departedAt: Date?

        var hasLifecycleTimestamp: Bool {
            arrivedAt != nil || departedAt != nil
        }
    }
}

enum RunStopLifecycle {
    /// Completed stops must carry at least one lifecycle timestamp.
    static func canMarkCompleted(arrivedAt: Date?, departedAt: Date?) -> Bool {
        arrivedAt != nil || departedAt != nil
    }

    /// Repairs backend rows that claim `completed` without any lifecycle timestamps.
    static func sanitized(
        status: SystemDomain.StopStatus,
        arrivedAt: Date?,
        departedAt: Date?
    ) -> (status: SystemDomain.StopStatus, arrivedAt: Date?, departedAt: Date?) {
        guard status == .completed, !canMarkCompleted(arrivedAt: arrivedAt, departedAt: departedAt) else {
            return (status, arrivedAt, departedAt)
        }
        return (.arrived, arrivedAt, departedAt)
    }

    static func validatedForPersistence(
        status: SystemDomain.StopStatus,
        arrivedAt: Date?,
        departedAt: Date?
    ) -> (status: SystemDomain.StopStatus, arrivedAt: Date?, departedAt: Date?) {
        let cleaned = sanitized(status: status, arrivedAt: arrivedAt, departedAt: departedAt)
        guard cleaned.status != .completed || canMarkCompleted(arrivedAt: cleaned.arrivedAt, departedAt: cleaned.departedAt) else {
            return (.arrived, cleaned.arrivedAt, cleaned.departedAt)
        }
        return cleaned
    }
}
