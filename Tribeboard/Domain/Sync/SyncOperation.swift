import Foundation

struct SyncOperation: Identifiable, Codable, Equatable {
    let id: UUID
    let entityType: SyncEntityType
    let operationType: SyncOperationType
    let entityId: UUID
    let householdId: UUID
    let createdAt: Date
}

