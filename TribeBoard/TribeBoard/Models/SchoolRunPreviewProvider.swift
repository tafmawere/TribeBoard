import SwiftUI

/// Comprehensive preview data provider for School Run Scheduler components and screens
struct SchoolRunPreviewProvider {
    
    // MARK: - Sample Children
    
    static let sampleChildren: [ChildProfile] = [
        ChildProfile(name: "Emma", avatar: "person.circle.fill", age: 8),
        ChildProfile(name: "Liam", avatar: "person.circle.fill", age: 10),
        ChildProfile(name: "Sophia", avatar: "person.circle.fill", age: 6),
        ChildProfile(name: "Oliver", avatar: "person.circle.fill", age: 12),
        ChildProfile(name: "Ava", avatar: "person.circle.fill", age: 7)
    ]
    
    // MARK: - Sample Stops
    
    static let sampleStops: [RunStop] = [
        RunStop(name: "Home", time: Date(), note: "Pick up Emma", type: .pickup, task: "Get ready to go", estimatedMinutes: 5),
        RunStop(name: "School", time: Date().addingTimeInterval(1800), note: "Drop off at main entrance", type: .dropoff, task: "Drop off at main entrance", estimatedMinutes: 10, assignedChild: sampleChildren[0]),
        RunStop(name: "Music Academy", time: Date().addingTimeInterval(3600), note: "Piano lesson", type: .music, task: "Drop off for piano lesson", estimatedMinutes: 15, assignedChild: sampleChildren[1]),
        RunStop(name: "OT Clinic", time: Date().addingTimeInterval(5400), note: "Therapy session", type: .ot, task: "Drop off for therapy", estimatedMinutes: 20, assignedChild: sampleChildren[0]),
        RunStop(name: "Friend's House", time: Date().addingTimeInterval(7200), note: "Playdate pickup", type: .pickup, task: "Pick up from playdate", estimatedMinutes: 5),
        RunStop(name: "Home", time: Date().addingTimeInterval(9000), note: "Return home", type: .home, task: "Return home safely", estimatedMinutes: 10)
    ]
    
    // MARK: - Sample Runs
    
    static let upcomingRun: SchoolRun = SchoolRun(
        title: "Thursday School Run",
        date: Date().addingTimeInterval(86400), // Tomorrow
        route: [
            RunStop(name: "Home", time: Date(), note: "Pick up Emma", type: .pickup, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(1800), note: "Drop off", type: .dropoff, task: "Drop off at main entrance", estimatedMinutes: 10)
        ]
    )
    
    static let todayRun: SchoolRun = SchoolRun(
        title: "Today's Pickup Run",
        date: Date(),
        route: [
            RunStop(name: "School", time: Date(), note: "Pick up", type: .pickup, task: "Pick up from school", estimatedMinutes: 10),
            RunStop(name: "Home", time: Date().addingTimeInterval(1200), note: "Drop off", type: .dropoff, task: "Return home", estimatedMinutes: 15)
        ]
    )
    
    static let completedRun: SchoolRun = SchoolRun(
        title: "Monday Morning Drop-off",
        date: Date().addingTimeInterval(-86400), // Yesterday
        route: [
            RunStop(name: "Home", time: Date().addingTimeInterval(-86400), note: "Pick up", type: .pickup, isCompleted: true, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(-86400 + 1800), note: "Drop off", type: .dropoff, isCompleted: true, task: "Drop off at school", estimatedMinutes: 10)
        ],
        status: .completed
    )
    
    static let longRun: SchoolRun = SchoolRun(
        title: "Extended School Run",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date(), note: "Start", type: .pickup, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "Friend's House", time: Date().addingTimeInterval(600), note: "Pick up friend", type: .pickup, task: "Pick up friend", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(1800), note: "Drop off", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10),
            RunStop(name: "After School Club", time: Date().addingTimeInterval(3600), note: "Pick up", type: .pickup, task: "Pick up from club", estimatedMinutes: 5),
            RunStop(name: "Home", time: Date().addingTimeInterval(4200), note: "End", type: .dropoff, task: "Return home", estimatedMinutes: 10)
        ]
    )
    
    static let shortRun: SchoolRun = SchoolRun(
        title: "Quick Run",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date(), note: "Start", type: .pickup, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(900), note: "Drop off", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
        ]
    )
    
    static let accessibilityTestRun: SchoolRun = SchoolRun(
        title: "Accessibility Test Run",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date(), note: "Wheelchair accessible pickup", type: .pickup, task: "Wheelchair accessible pickup", estimatedMinutes: 10),
            RunStop(name: "Special Needs School", time: Date().addingTimeInterval(1800), note: "Accessible drop off", type: .dropoff, task: "Accessible drop off", estimatedMinutes: 15)
        ]
    )
    
    static let executionRunStart: SchoolRun = SchoolRun(
        title: "Active Run - Starting",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date(), note: "Starting point", type: .pickup, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(1800), note: "Destination", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
        ],
        status: .inProgress
    )
    
    static let executionRunMidway: SchoolRun = SchoolRun(
        title: "Active Run - Midway",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date().addingTimeInterval(-900), note: "Completed", type: .pickup, isCompleted: true, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(900), note: "Next stop", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
        ],
        status: .inProgress
    )
    
    static let executionRunNearEnd: SchoolRun = SchoolRun(
        title: "Active Run - Near End",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date().addingTimeInterval(-1800), note: "Completed", type: .pickup, isCompleted: true, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "Friend's House", time: Date().addingTimeInterval(-900), note: "Completed", type: .pickup, isCompleted: true, task: "Pick up friend", estimatedMinutes: 5),
            RunStop(name: "School", time: Date().addingTimeInterval(300), note: "Final stop", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
        ],
        status: .inProgress
    )
    
    // MARK: - Sample Run Collections
    
    static let sampleRuns: [SchoolRun] = [
        executionRunStart,
        executionRunMidway,
        executionRunNearEnd,
        upcomingRun,
        todayRun
    ]
    
    static let allSampleRuns: [SchoolRun] = [
        upcomingRun,
        todayRun,
        completedRun,
        longRun,
        shortRun
    ]
    
    static let upcomingRuns: [SchoolRun] = [
        upcomingRun,
        todayRun
    ]
    
    static let pastRuns: [SchoolRun] = [
        completedRun
    ]
    
    // MARK: - Preview Helper Methods
    
    static func previewWithSampleData() -> [SchoolRun] {
        return allSampleRuns
    }
}

// MARK: - Preview Extensions

extension SchoolRun {
    /// Creates a sample run for previews
    static var previewSample: SchoolRun {
        SchoolRunPreviewProvider.upcomingRun
    }
    
    /// Creates a completed run for previews
    static var previewCompleted: SchoolRun {
        SchoolRunPreviewProvider.completedRun
    }
    
    /// Creates a long run for previews
    static var previewLong: SchoolRun {
        SchoolRunPreviewProvider.upcomingRun
    }
}

extension RunStop {
    /// Creates a sample pickup stop for previews
    static var previewPickup: RunStop {
        RunStop(
            name: "Home",
            time: Date(),
            note: "Pick up Emma and Liam",
            type: .pickup,
            task: "Pick up Emma and Liam",
            estimatedMinutes: 5
        )
    }
    
    /// Creates a sample dropoff stop for previews
    static var previewDropoff: RunStop {
        RunStop(
            name: "Greenwood Elementary",
            time: Date().addingTimeInterval(1200),
            note: "Drop off at main entrance",
            type: .dropoff,
            task: "Drop off at main entrance",
            estimatedMinutes: 10
        )
    }
}