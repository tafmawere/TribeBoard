import Foundation

final class LocalRunRepository: RunRepository {
    private let store: RunStore
    private var cachedAllRuns: [SystemDomain.RunInstance]?

    init(store: RunStore = RunStore()) {
        self.store = store
    }

    func loadRuns(for householdId: UUID) async throws -> [SystemDomain.RunInstance] {
        let all = loadAllRuns()
        return all.filter { $0.householdId == householdId }
    }

    func saveRuns(_ runs: [SystemDomain.RunInstance], for householdId: UUID) async throws {
        var all = loadAllRuns()
        all.removeAll { $0.householdId == householdId }
        all.append(contentsOf: runs)
        store.save(all)
        cachedAllRuns = all
    }

    private func loadAllRuns() -> [SystemDomain.RunInstance] {
        if let cachedAllRuns {
            return cachedAllRuns
        }
        let loaded = store.load()
        cachedAllRuns = loaded
        return loaded
    }
}
