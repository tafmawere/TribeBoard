import Foundation

enum AppTab: Hashable {
    case home
    case runs
    case calendar
    case family
    case more

    var title: String {
        switch self {
        case .home: return "Home"
        case .runs: return "Runs"
        case .calendar: return "Calendar"
        case .family: return "Tribe"
        case .more: return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .runs: return "car.fill"
        case .calendar: return "calendar"
        case .family: return "person.3.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

enum Destination: Hashable {
    // Runs module
    case runDetails(runId: String)
    case runEdit(runId: String)
    case runHistoryDetail(runId: String)
    case cancelRun(runId: String)

    // Calendar / schedules
    case schedulesList
    case scheduleDetail(scheduleId: String)
    case scheduleEditor(scheduleId: String?)
    case dayScheduleList(date: Date)

    // Notifications & comms
    case notificationsInbox
    case notificationSettings
    case quickContact

    // Safety & privacy
    case locationSharing
    case permissionsConsent
    case emergencyContacts

    // General
    case calendarSync
    case settings
    case helpSupport
    case about
    case error(message: String)
}
