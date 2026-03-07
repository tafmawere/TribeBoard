import Foundation

extension SystemDomain {
    struct Driver: Identifiable, Codable, Equatable {
        // Stable identity for cross-device/backend sync. Must decode exactly as persisted.
        var id: UUID
        // Ownership anchor for household/tenant scope in future sync and permissions.
        let householdId: UUID
        var name: String
        var phoneNumber: String?
        var isActive: Bool
        var createdAt: Date

        init(
            id: UUID,
            householdId: UUID = HouseholdDefaults.defaultHouseholdId,
            name: String,
            phoneNumber: String?,
            isActive: Bool,
            createdAt: Date
        ) {
            self.id = id
            self.householdId = householdId
            self.name = name
            self.phoneNumber = phoneNumber
            self.isActive = isActive
            self.createdAt = createdAt
        }

        enum CodingKeys: String, CodingKey {
            case id
            case householdId
            case name
            case phoneNumber
            case isActive
            case createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Never regenerate IDs during decode/migration.
            id = try container.decode(UUID.self, forKey: .id)
            if let decodedHouseholdId = try container.decodeIfPresent(UUID.self, forKey: .householdId) {
                householdId = decodedHouseholdId
            } else {
                householdId = HouseholdDefaults.defaultHouseholdId
#if DEBUG
                print("Driver.decode -> missing householdId for driver \(id); defaulting to \(householdId).")
#endif
            }
            name = try container.decode(String.self, forKey: .name)
            phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }
}
