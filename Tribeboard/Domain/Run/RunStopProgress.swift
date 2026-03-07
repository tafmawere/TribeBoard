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
    }
}
