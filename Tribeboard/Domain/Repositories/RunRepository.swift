import Foundation

protocol RunRepository {
    func loadRuns(for householdId: UUID) async throws -> [SystemDomain.RunInstance]
    func saveRuns(_ runs: [SystemDomain.RunInstance], for householdId: UUID) async throws
}
