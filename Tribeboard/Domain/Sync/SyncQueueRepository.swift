import Foundation

protocol SyncQueueRepository {
    func loadChanges() async throws -> [SyncChange]
    func saveChanges(_ changes: [SyncChange]) async throws
}

