import Foundation

final class LocalSyncAuditRepository: SyncAuditRepository {
    private let store: SyncAuditStore

    init(store: SyncAuditStore = SyncAuditStore()) {
        self.store = store
    }

    func loadRecords() async throws -> [SyncAuditRecord] {
        store.load()
    }

    func saveRecords(_ records: [SyncAuditRecord]) async throws {
        store.save(records)
    }

    func append(_ record: SyncAuditRecord) async throws {
        var all = store.load()
        all.append(record)
        store.save(all)
    }

    func append(_ records: [SyncAuditRecord]) async throws {
        guard !records.isEmpty else { return }
        var all = store.load()
        all.append(contentsOf: records)
        store.save(all)
    }

    func clear() async throws {
        store.save([])
    }
}
