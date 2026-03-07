import Foundation

final class LocalSyncQueueRepository: SyncQueueRepository {
    private let store: SyncQueueStore

    init(store: SyncQueueStore = SyncQueueStore()) {
        self.store = store
    }

    func loadChanges() async throws -> [SyncChange] {
        store.load()
    }

    func saveChanges(_ changes: [SyncChange]) async throws {
        store.save(changes)
    }
}

