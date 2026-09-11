import Foundation

final class LocalDriverRepository: DriverRepository {
    private let store: DriverStore

    init(store: DriverStore = DriverStore()) {
        self.store = store
    }

    func loadDrivers(for householdId: UUID) async throws -> [SystemDomain.Driver] {
        let all = loadAllDrivers()
        return all.filter { $0.householdId == householdId }
    }

    func saveDrivers(_ drivers: [SystemDomain.Driver], for householdId: UUID) async throws {
        var all = loadAllDrivers()
        all.removeAll { $0.householdId == householdId }
        all.append(contentsOf: drivers)
        store.save(all)
    }

    private func loadAllDrivers() -> [SystemDomain.Driver] {
        store.load()
    }
}
