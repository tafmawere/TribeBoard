import Foundation

enum UIStopType: String, Hashable {
    case pickup = "Pickup"
    case dropoff = "Dropoff"
}

enum UIPassengerStatus: String, Hashable {
    case waiting = "Waiting"
    case onboard = "Onboard"
    case droppedOff = "Dropped Off"
}

enum UIRunStatus: String, Hashable {
    case scheduled = "Scheduled"
    case active = "Active"
    case completed = "Completed"
}

struct UIPassenger: Identifiable, Hashable {
    let id: UUID
    let name: String
    let status: UIPassengerStatus

    init(id: UUID = UUID(), name: String, status: UIPassengerStatus) {
        self.id = id
        self.name = name
        self.status = status
    }
}

struct UIStop: Identifiable, Hashable {
    let id: UUID
    let type: UIStopType
    let label: String
    let timeText: String
    let passengerNames: [String]

    init(
        id: UUID = UUID(),
        type: UIStopType,
        label: String,
        timeText: String,
        passengerNames: [String]
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.timeText = timeText
        self.passengerNames = passengerNames
    }
}

struct UITimelineItem: Identifiable, Hashable {
    let id: UUID
    let timeText: String
    let title: String
    let subtitle: String

    init(id: UUID = UUID(), timeText: String, title: String, subtitle: String) {
        self.id = id
        self.timeText = timeText
        self.title = title
        self.subtitle = subtitle
    }
}

struct UIRun: Identifiable, Hashable {
    let id: UUID
    let backingRunId: String
    let title: String
    let scheduledTime: String
    let status: UIRunStatus
    let driverName: String
    let passengers: [UIPassenger]
    let stops: [UIStop]
    let etaText: String
    let distanceText: String

    init(
        id: UUID = UUID(),
        backingRunId: String = UUID().uuidString,
        title: String,
        scheduledTime: String,
        status: UIRunStatus,
        driverName: String,
        passengers: [UIPassenger],
        stops: [UIStop],
        etaText: String,
        distanceText: String
    ) {
        self.id = id
        self.backingRunId = backingRunId
        self.title = title
        self.scheduledTime = scheduledTime
        self.status = status
        self.driverName = driverName
        self.passengers = passengers
        self.stops = stops
        self.etaText = etaText
        self.distanceText = distanceText
    }
}
