import Foundation

struct BackendRun: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var scheduleId: UUID
    var childId: UUID?
    var title: String?
    var runDate: Date
    var departureTime: String
    var status: String
    var driverId: UUID?
    var startedAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case scheduleId = "schedule_id"
        case childId = "child_id"
        case title
        case runDate = "run_date"
        case departureTime = "departure_time"
        case status
        case driverId = "driver_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
        case createdAt = "created_at"
    }
}

/// Insert payload for `runs` — omits server-managed timestamps and encodes `run_date` as SQL date.
struct BackendRunInsertPayload: Encodable {
    let id: UUID
    let householdId: UUID
    let scheduleId: UUID
    let childId: UUID?
    let title: String?
    let runDate: String
    let departureTime: String
    let status: String
    let driverId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case scheduleId = "schedule_id"
        case childId = "child_id"
        case title
        case runDate = "run_date"
        case departureTime = "departure_time"
        case status
        case driverId = "driver_id"
    }

    init(from run: BackendRun, calendar: Calendar = .current) {
        id = run.id
        householdId = run.householdId
        scheduleId = run.scheduleId
        childId = run.childId
        title = run.title
        runDate = BackendTimestampParser.formatDateOnly(run.runDate, calendar: calendar)
        departureTime = run.departureTime
        status = run.status
        driverId = run.driverId
    }
}

struct BackendRunStop: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var childId: UUID
    var label: String
    var latitude: Double
    var longitude: Double
    var stopOrder: Int
    var status: String
    var locationId: UUID?
    var arrivedAt: Date?
    var departedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case childId = "child_id"
        case label
        case latitude
        case longitude
        case stopOrder = "stop_order"
        case status
        case locationId = "location_id"
        case arrivedAt = "arrived_at"
        case departedAt = "departed_at"
    }
}

struct BackendRunUpdatePayload: Encodable {
    let householdId: UUID
    let scheduleId: UUID
    let childId: UUID?
    let title: String?
    let runDate: String
    let departureTime: String
    let status: String
    let driverId: UUID?
    let startedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case scheduleId = "schedule_id"
        case childId = "child_id"
        case title
        case runDate = "run_date"
        case departureTime = "departure_time"
        case status
        case driverId = "driver_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    init(from run: BackendRun, calendar: Calendar = .current) {
        householdId = run.householdId
        scheduleId = run.scheduleId
        childId = run.childId
        title = run.title
        runDate = BackendTimestampParser.formatDateOnly(run.runDate, calendar: calendar)
        departureTime = run.departureTime
        status = run.status
        driverId = run.driverId
        startedAt = run.startedAt
        completedAt = run.completedAt
    }
}

struct BackendRunStopInsertPayload: Encodable {
    let id: UUID
    let runId: UUID
    let childId: UUID
    let label: String
    let latitude: Double
    let longitude: Double
    let stopOrder: Int
    let status: String
    let locationId: UUID?
    let arrivedAt: Date?
    let departedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case childId = "child_id"
        case label
        case latitude
        case longitude
        case stopOrder = "stop_order"
        case status
        case locationId = "location_id"
        case arrivedAt = "arrived_at"
        case departedAt = "departed_at"
    }

    init(from stop: BackendRunStop) {
        let validated = RunStopLifecycle.validatedForPersistence(
            status: BackendRunStopStatusCodec.decode(stop.status),
            arrivedAt: stop.arrivedAt,
            departedAt: stop.departedAt
        )
        id = stop.id
        runId = stop.runId
        childId = stop.childId
        label = stop.label
        latitude = stop.latitude
        longitude = stop.longitude
        stopOrder = stop.stopOrder
        status = BackendRunStopStatusCodec.encode(validated.status)
        locationId = stop.locationId
        arrivedAt = validated.arrivedAt
        departedAt = validated.departedAt
    }
}

struct BackendRunStopUpdatePayload: Encodable {
    let status: String
    let arrivedAt: Date?
    let departedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case arrivedAt = "arrived_at"
        case departedAt = "departed_at"
    }

    init(from stop: BackendRunStop) {
        let validated = RunStopLifecycle.validatedForPersistence(
            status: BackendRunStopStatusCodec.decode(stop.status),
            arrivedAt: stop.arrivedAt,
            departedAt: stop.departedAt
        )
        status = BackendRunStopStatusCodec.encode(validated.status)
        arrivedAt = validated.arrivedAt
        departedAt = validated.departedAt
    }
}

struct BackendRunPackage: Equatable {
    let run: BackendRun
    let stops: [BackendRunStop]
}

enum BackendRunStatusCodec {
    static func encode(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled: return "scheduled"
        case .assigned: return "assigned"
        case .inProgress: return "in_progress"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        }
    }

    static func decode(_ raw: String) -> SystemDomain.RunStatus {
        switch raw.lowercased() {
        case "scheduled": return .scheduled
        case "assigned": return .assigned
        case "in_progress", "inprogress", "active", "activeenroute", "arrivedatstop", "paused":
            return .inProgress
        case "completed": return .completed
        case "cancelled", "missed": return .cancelled
        default: return .scheduled
        }
    }
}

enum BackendRunStopStatusCodec {
    static func encode(_ status: SystemDomain.StopStatus) -> String {
        switch status {
        case .pending: return "pending"
        case .enRoute: return "en_route"
        case .arrived: return "arrived"
        case .completed: return "completed"
        case .skipped: return "skipped"
        }
    }

    static func decode(_ raw: String) -> SystemDomain.StopStatus {
        switch raw.lowercased() {
        case "pending": return .pending
        case "en_route", "enroute": return .enRoute
        case "arrived", "active": return .arrived
        case "completed": return .completed
        case "skipped": return .skipped
        default: return .pending
        }
    }
}
