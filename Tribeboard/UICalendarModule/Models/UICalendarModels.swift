import Foundation

enum UICalendarUserRole: String, Hashable {
    case parent = "Parent"
    case child = "Child"
    case driver = "Driver"
    case observer = "Observer"
    case passenger = "Passenger"
}

struct UICalendarUser: Identifiable, Hashable {
    let id: UUID
    var name: String
    var roles: [UICalendarUserRole]

    init(id: UUID = UUID(), name: String, roles: [UICalendarUserRole]) {
        self.id = id
        self.name = name
        self.roles = roles
    }
}

enum UICalendarStopType: String, Hashable, CaseIterable {
    case pickup = "Pickup"
    case dropoff = "Dropoff"
}

struct UICalendarStop: Identifiable, Hashable {
    let id: UUID
    var type: UICalendarStopType
    var label: String

    init(id: UUID = UUID(), type: UICalendarStopType, label: String) {
        self.id = id
        self.type = type
        self.label = label
    }
}

enum UICalendarRecurrence: Hashable {
    case oneOff(date: Date)
    case daily
    case weekly(days: [Int]) // 1 = Sunday ... 7 = Saturday
}

struct UISchedule: Identifiable, Hashable {
    let id: UUID
    var title: String
    var timeOfDay: DateComponents
    var recurrence: UICalendarRecurrence
    var startDate: Date
    var endDate: Date?
    var driver: UICalendarUser
    var passengers: [UICalendarUser]
    var stops: [UICalendarStop]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        timeOfDay: DateComponents,
        recurrence: UICalendarRecurrence,
        startDate: Date,
        endDate: Date? = nil,
        driver: UICalendarUser,
        passengers: [UICalendarUser],
        stops: [UICalendarStop],
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.timeOfDay = timeOfDay
        self.recurrence = recurrence
        self.startDate = startDate
        self.endDate = endDate
        self.driver = driver
        self.passengers = passengers
        self.stops = stops
        self.isEnabled = isEnabled
    }
}

struct UIScheduleOccurrence: Identifiable, Hashable {
    let id: UUID
    let scheduleId: UUID
    let dateTime: Date
    let title: String
    let driver: UICalendarUser
    let passengers: [UICalendarUser]
    let stops: [UICalendarStop]
    let hasMaterializedRun: Bool

    init(
        id: UUID = UUID(),
        scheduleId: UUID,
        dateTime: Date,
        title: String,
        driver: UICalendarUser,
        passengers: [UICalendarUser],
        stops: [UICalendarStop],
        hasMaterializedRun: Bool
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.dateTime = dateTime
        self.title = title
        self.driver = driver
        self.passengers = passengers
        self.stops = stops
        self.hasMaterializedRun = hasMaterializedRun
    }
}
