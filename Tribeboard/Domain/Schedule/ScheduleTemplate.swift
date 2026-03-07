import Foundation

enum SystemDomain { }

extension SystemDomain {
    struct ScheduleTemplate: Identifiable, Codable {
        // Stable identity for cross-device/backend sync. Must decode exactly as persisted.
        var id: UUID
        // Ownership anchor for household/tenant scope in future sync and permissions.
        let householdId: UUID
        var name: String
        var childId: UUID
        var driverId: UUID?
        var weekdays: Set<Int> // 1 = Sunday ... 7 = Saturday
        var hour: Int
        var minute: Int
        var stops: [Stop]
        var isActive: Bool
        var createdAt: Date

        init(
            id: UUID,
            householdId: UUID = HouseholdDefaults.defaultHouseholdId,
            name: String,
            childId: UUID,
            driverId: UUID?,
            weekdays: Set<Int>,
            hour: Int,
            minute: Int,
            stops: [Stop],
            isActive: Bool,
            createdAt: Date
        ) {
            self.id = id
            self.householdId = householdId
            self.name = name
            self.childId = childId
            self.driverId = driverId
            self.weekdays = weekdays
            self.hour = hour
            self.minute = minute
            self.stops = stops
            self.isActive = isActive
            self.createdAt = createdAt
        }

        enum CodingKeys: String, CodingKey {
            case id
            case householdId
            case name
            case childId
            case driverId
            case weekdays
            case hour
            case minute
            case stops
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
                print("ScheduleTemplate.decode -> missing householdId for template \(id); defaulting to \(householdId).")
#endif
            }
            name = try container.decode(String.self, forKey: .name)
            childId = try container.decode(UUID.self, forKey: .childId)
            driverId = try container.decodeIfPresent(UUID.self, forKey: .driverId)
            weekdays = try container.decode(Set<Int>.self, forKey: .weekdays)
            hour = try container.decode(Int.self, forKey: .hour)
            minute = try container.decode(Int.self, forKey: .minute)
            stops = try container.decode([Stop].self, forKey: .stops)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }
}
