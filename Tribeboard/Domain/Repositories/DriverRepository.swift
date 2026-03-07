import Foundation

protocol DriverRepository {
    func loadDrivers(for householdId: UUID) async throws -> [SystemDomain.Driver]
    func saveDrivers(_ drivers: [SystemDomain.Driver], for householdId: UUID) async throws
}
