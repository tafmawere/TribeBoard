import Foundation

final class LocalProcessedChangeRepository: ProcessedChangeRepository {
    private let store: ProcessedChangeStore

    init(store: ProcessedChangeStore = ProcessedChangeStore()) {
        self.store = store
    }

    func loadProcessed() async throws -> [ProcessedSyncChange] {
        store.load()
    }

    func saveProcessed(_ processed: [ProcessedSyncChange]) async throws {
        store.save(processed)
    }

    func append(_ processed: [ProcessedSyncChange]) async throws {
        guard !processed.isEmpty else { return }
        var all = store.load()
        all.append(contentsOf: processed)
        let unique = Dictionary(grouping: all, by: \.changeId).compactMap { $0.value.max(by: { $0.processedAt < $1.processedAt }) }
        store.save(unique.sorted(by: { $0.processedAt < $1.processedAt }))
    }

    func clear() async throws {
        store.save([])
    }
}
