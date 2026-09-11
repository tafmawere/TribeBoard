import Foundation

struct BackendHouseholdPerson: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var name: String
    var relationship: String?
    var role: String
    var phone: String?
    var isDriver: Bool
    var avatarType: String? = nil
    var avatarKey: String? = nil
    var avatarURL: String? = nil
    var avatarUpdatedAt: String? = nil
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case relationship
        case role
        case phone
        case isDriver = "is_driver"
        case avatarType = "avatar_type"
        case avatarKey = "avatar_key"
        case avatarURL = "avatar_url"
        case avatarUpdatedAt = "avatar_updated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension BackendHouseholdPerson {
    var createdAtDate: Date? {
        BackendTimestampParser.parse(createdAt)
    }
}
