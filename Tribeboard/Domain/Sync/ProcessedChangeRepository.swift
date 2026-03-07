import Foundation

protocol ProcessedChangeRepository {
    func loadProcessed() async throws -> [ProcessedSyncChange]
    func saveProcessed(_ processed: [ProcessedSyncChange]) async throws
    func append(_ processed: [ProcessedSyncChange]) async throws
    func clear() async throws
}
