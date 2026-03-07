import Foundation

enum HouseholdRole: String, Codable, Equatable {
    case owner
    case admin
    case parent
    case observer
    case driver
}

struct HouseholdMembership: Identifiable, Codable, Equatable {
    let id: UUID
    let householdId: UUID
    let userId: UUID
    var role: HouseholdRole
    var createdAt: Date
}
