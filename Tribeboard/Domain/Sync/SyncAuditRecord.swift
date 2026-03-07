import Foundation

enum SyncAuditDirection: String, Codable, Equatable {
    case push
    case pull
    case merge
}

enum SyncAuditResult: String, Codable, Equatable {
    case success
    case failed
    case skipped
    case duplicate
    case conflict
}

struct SyncAuditRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let householdId: UUID?
    let entityType: SyncEntityType?
    let entityId: UUID?
    let direction: SyncAuditDirection
    let result: SyncAuditResult
    let changeId: UUID?
    let message: String
    let createdAt: Date
}
