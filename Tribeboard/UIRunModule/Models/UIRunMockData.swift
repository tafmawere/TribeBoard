import Foundation

enum UIRunMockData {
    static let scheduledRun = UIRun(
        backingRunId: "run_1",
        title: "School Morning Drop-off",
        scheduledTime: "Today, 7:45 AM",
        status: .scheduled,
        driverName: "Mom",
        passengers: [
            UIPassenger(name: "Leo", status: .waiting),
            UIPassenger(name: "Maya", status: .waiting),
            UIPassenger(name: "Sam", status: .waiting)
        ],
        stops: [
            UIStop(type: .pickup, label: "Home (123 Maple St)", timeText: "Pickup at 7:45 AM", passengerNames: ["Leo", "Maya", "Sam"]),
            UIStop(type: .dropoff, label: "Lincoln Elementary", timeText: "Dropoff at 8:15 AM", passengerNames: ["Leo", "Maya"]),
            UIStop(type: .dropoff, label: "Westside Preschool", timeText: "Dropoff at 8:25 AM", passengerNames: ["Sam"])
        ],
        etaText: "15 min",
        distanceText: "4.2 miles"
    )

    static let activeRun = UIRun(
        backingRunId: "run_2",
        title: "Soccer Practice - West",
        scheduledTime: "Now",
        status: .active,
        driverName: "Dad",
        passengers: [
            UIPassenger(name: "Maya", status: .onboard),
            UIPassenger(name: "Leo", status: .waiting),
            UIPassenger(name: "Sam", status: .waiting)
        ],
        stops: [
            UIStop(type: .pickup, label: "West Field Entrance", timeText: "Arriving in 8 min", passengerNames: ["Maya"]),
            UIStop(type: .dropoff, label: "Oakwood Community Center", timeText: "ETA 4:10 PM", passengerNames: ["Maya"]),
            UIStop(type: .pickup, label: "Whole Foods", timeText: "ETA 5:00 PM", passengerNames: ["Leo"])
        ],
        etaText: "8 min",
        distanceText: "2.4 mi"
    )

    static let historyRuns: [UIRun] = [
        UIRun(
            backingRunId: "run_3",
            title: "Grocery Restock",
            scheduledTime: "Yesterday, 11:15 AM",
            status: .completed,
            driverName: "Dad",
            passengers: [
                UIPassenger(name: "Sam", status: .droppedOff)
            ],
            stops: [
                UIStop(type: .pickup, label: "Home", timeText: "11:00 AM", passengerNames: ["Sam"]),
                UIStop(type: .dropoff, label: "Whole Foods", timeText: "11:15 AM", passengerNames: ["Sam"])
            ],
            etaText: "Completed",
            distanceText: "6.1 mi"
        )
    ]

    static let passengerChecklistPickup: [UIPassenger] = [
        UIPassenger(name: "Leo", status: .onboard),
        UIPassenger(name: "Maya", status: .waiting),
        UIPassenger(name: "Sam", status: .waiting)
    ]

    static let passengerChecklistDropoff: [UIPassenger] = [
        UIPassenger(name: "Leo", status: .droppedOff),
        UIPassenger(name: "Maya", status: .onboard),
        UIPassenger(name: "Sam", status: .onboard)
    ]

    static let timeline: [UITimelineItem] = [
        UITimelineItem(timeText: "3:20 PM", title: "Departed Home", subtitle: "Run started on time"),
        UITimelineItem(timeText: "3:30 PM", title: "Heading to School", subtitle: "In progress"),
        UITimelineItem(timeText: "3:45 PM", title: "Arrival at School", subtitle: "Expected destination")
    ]
}
