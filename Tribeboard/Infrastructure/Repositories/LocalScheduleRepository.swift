import Foundation

final class LocalScheduleRepository: ScheduleRepository {
    private let store: ScheduleStore
    private var cachedAllTemplates: [SystemDomain.ScheduleTemplate]?

    init(store: ScheduleStore = ScheduleStore()) {
        self.store = store
    }

    func loadTemplates(for householdId: UUID) async throws -> [SystemDomain.ScheduleTemplate] {
        let all = loadAllTemplates()
        return all.filter { $0.householdId == householdId }
    }

    func saveTemplates(_ templates: [SystemDomain.ScheduleTemplate], for householdId: UUID) async throws {
        var all = loadAllTemplates()
        all.removeAll { $0.householdId == householdId }
        all.append(contentsOf: templates)
        store.save(all)
        cachedAllTemplates = all
    }

    private func loadAllTemplates() -> [SystemDomain.ScheduleTemplate] {
        if let cachedAllTemplates {
            return cachedAllTemplates
        }
        let loaded = store.load()
        cachedAllTemplates = loaded
        return loaded
    }
}
