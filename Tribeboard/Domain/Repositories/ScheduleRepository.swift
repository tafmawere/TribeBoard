import Foundation

protocol ScheduleRepository {
    func loadTemplates(for householdId: UUID) async throws -> [SystemDomain.ScheduleTemplate]
    func saveTemplates(_ templates: [SystemDomain.ScheduleTemplate], for householdId: UUID) async throws
}
