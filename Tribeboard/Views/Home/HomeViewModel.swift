import Foundation

struct HomeUpcomingEvent: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let label: String
    let title: String
    let timeRange: String
    let location: String
    let passengerInitials: [String]
}

enum HomeRunStatus: String, Hashable {
    case completed = "COMPLETED"
    case pending = "PENDING"
}

struct HomeRunItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let status: HomeRunStatus
}

struct HomeViewModel {
    let activeRunCount: Int
    let syncStatusText: String
    let upcomingEvent: HomeUpcomingEvent?
    let todaysRuns: [HomeRunItem]

    init(
        activeRunCount: Int = 1,
        syncStatusText: String = "JUST NOW",
        upcomingEvent: HomeUpcomingEvent? = HomeUpcomingEvent(
            category: "FIELD TRIP",
            label: "UPCOMING EVENT",
            title: "Soccer Practice",
            timeRange: "4:00 PM - 5:30 PM",
            location: "Harare Sports Complex",
            passengerInitials: ["RM", "TM", "TJ"]
        ),
        todaysRuns: [HomeRunItem] = [
            HomeRunItem(
                title: "Grocery Restock",
                subtitle: "Completed at 10:15 AM",
                status: .completed
            ),
            HomeRunItem(
                title: "School Pick-up",
                subtitle: "Starts at 3:15 PM",
                status: .pending
            )
        ]
    ) {
        self.activeRunCount = activeRunCount
        self.syncStatusText = syncStatusText
        self.upcomingEvent = upcomingEvent
        self.todaysRuns = todaysRuns
    }
}
