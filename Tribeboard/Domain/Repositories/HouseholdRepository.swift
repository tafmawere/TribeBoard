import Foundation

protocol HouseholdRepository {
    func loadHouseholds() async throws -> [Household]
    func saveHouseholds(_ households: [Household]) async throws
}
