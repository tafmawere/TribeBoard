import Foundation

protocol SyncAuditRepository {
    func loadRecords() async throws -> [SyncAuditRecord]
    func saveRecords(_ records: [SyncAuditRecord]) async throws
    func append(_ record: SyncAuditRecord) async throws
    func append(_ records: [SyncAuditRecord]) async throws
    func clear() async throws
}
