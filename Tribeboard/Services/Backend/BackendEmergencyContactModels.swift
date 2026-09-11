import Foundation

struct BackendEmergencyContact: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var name: String
    var relationship: String?
    var phone: String
    var email: String?
    var priority: Int
    var canPickUpChild: Bool
    var notes: String?
    var createdBy: UUID?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case relationship
        case phone
        case email
        case priority
        case canPickUpChild = "can_pick_up_child"
        case notes
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension BackendEmergencyContact {
    var createdAtDate: Date? {
        BackendTimestampParser.parse(createdAt)
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        if letters.isEmpty { return "?" }
        return letters.joined().uppercased()
    }
}
