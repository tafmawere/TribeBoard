import Foundation

struct BackendScheduleTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var childId: UUID
    var title: String
    var weekday: String
    var departureTime: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case childId = "child_id"
        case title
        case weekday
        case departureTime = "departure_time"
        case createdAt = "created_at"
    }
}

extension BackendScheduleTemplate {
    var createdAtDate: Date? {
        BackendTimestampParser.parse(createdAt)
    }
}

struct BackendScheduleStop: Identifiable, Codable, Equatable {
    let id: UUID
    var scheduleId: UUID
    var childId: UUID
    var label: String
    var latitude: Double
    var longitude: Double
    var stopOrder: Int
    var locationId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case scheduleId = "schedule_id"
        case childId = "child_id"
        case label
        case latitude
        case longitude
        case stopOrder = "stop_order"
        case locationId = "location_id"
    }
}
