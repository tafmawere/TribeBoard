import Foundation

enum SyncEntityType: String, Codable, Equatable {
    case run
    case schedule
    case runAssignment
    case driver
    case household
}

enum SyncOperationType: String, Codable, Equatable {
    case create
    case update
    case delete
}

struct SyncChange: Identifiable, Codable, Equatable {
    let id: UUID
    let householdId: UUID
    let entityType: SyncEntityType
    let entityId: UUID
    let operation: SyncOperationType
    let createdAt: Date
    var retryCount: Int
    var lastTriedAt: Date?
    var payloadVersion: Int
    var sourceDeviceId: String? = nil
    var sourceRevision: Int? = nil
    var effectiveUpdatedAt: Date? = nil
}

