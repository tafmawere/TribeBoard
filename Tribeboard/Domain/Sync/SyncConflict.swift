import Foundation

enum SyncConflictType: String, Codable, Equatable {
    case staleRemoteChange
    case staleLocalChange
    case competingUpdates
    case deleteVsUpdate
}

struct SyncConflict: Identifiable, Codable, Equatable {
    let id: UUID
    let householdId: UUID?
    let entityType: SyncEntityType
    let entityId: UUID
    let type: SyncConflictType
    let localTimestamp: Date?
    let remoteTimestamp: Date?
    let message: String
    let createdAt: Date
}
