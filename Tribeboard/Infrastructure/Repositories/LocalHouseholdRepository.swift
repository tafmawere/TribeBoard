import Foundation

final class LocalHouseholdRepository: HouseholdRepository {
    private let store: HouseholdStore

    init(store: HouseholdStore = HouseholdStore()) {
        self.store = store
    }

    func loadHouseholds() async throws -> [Household] {
        try store.load()
    }

    func saveHouseholds(_ households: [Household]) async throws {
        try store.save(households)
    }
}
