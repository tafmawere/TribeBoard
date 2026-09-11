import Foundation

struct BackendChild: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var legalName: String
    var displayName: String?
    var dateOfBirth: String?
    var schoolName: String?
    var schoolLocationId: UUID?
    var gradeOrClass: String?
    var avatarType: String? = nil
    var avatarKey: String? = nil
    var avatarURL: String? = nil
    var avatarUpdatedAt: String? = nil
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case legalName = "legal_name"
        case displayName = "display_name"
        case dateOfBirth = "date_of_birth"
        case schoolName = "school_name"
        case schoolLocationId = "school_location_id"
        case gradeOrClass = "grade_or_class"
        case avatarType = "avatar_type"
        case avatarKey = "avatar_key"
        case avatarURL = "avatar_url"
        case avatarUpdatedAt = "avatar_updated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BackendChildActivity: Identifiable, Codable, Equatable {
    let id: UUID
    var childId: UUID
    var householdId: UUID
    var name: String
    var type: String
    var locationName: String?
    var locationId: UUID?
    var days: [Int]
    var startTime: String?
    var endTime: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case householdId = "household_id"
        case name
        case type
        case locationName = "location_name"
        case locationId = "location_id"
        case days
        case startTime = "start_time"
        case endTime = "end_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
