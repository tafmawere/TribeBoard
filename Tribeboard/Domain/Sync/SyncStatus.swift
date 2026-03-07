import Foundation

enum SyncState: String, Codable, Equatable {
    case idle
    case pending
    case syncing
    case failed
    case succeeded
}

struct SyncStatusSnapshot: Codable, Equatable {
    var state: SyncState
    var pendingCount: Int
    var lastSyncAt: Date?
    var lastError: String?
}

