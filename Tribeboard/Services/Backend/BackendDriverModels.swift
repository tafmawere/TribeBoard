import Foundation

struct BackendDriver: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var userId: UUID?
    var displayName: String
    var role: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case userId = "user_id"
        case displayName = "display_name"
        case role
    }
}
