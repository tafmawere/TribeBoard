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
        RunStop(
            name: "Home",
            type: .home,
            task: "Pick snacks & guitar",
            estimatedMinutes: 5
        ),
        RunStop(
            name: "Riverside Elementary",
            type: .school,
            assignedChild: sampleChildren[0],
            task: "Pick up Emma from classroom 3B",
            estimatedMinutes: 10
        ),
        RunStop(
            name: "OT Clinic",
            type: .ot,
            assignedChild: sampleChildren[0],
            task: "Drop Emma for therapy session",
            estimatedMinutes: 15
        ),
        RunStop(
            name: "Music Academy",
            type: .music,
            assignedChild: sampleChildren[1],
            task: "Pick up Liam from piano lesson",
            estimatedMinutes: 10
        ),
        RunStop(
            name: "OT Clinic",
            type: .ot,
            assignedChild: sampleChildren[0],
            task: "Pick up Emma after therapy",
            estimatedMinutes: 15
        ),
        RunStop(
            name: "Home",
            type: .home,
            task: "Return home safely",
            estimatedMinutes: 10
        )
    ]
    
    // MARK: - Sample Runs
    
    static let upcomingRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Thursday School Run",
        scheduledDate: Date().addingTimeInterval(86400), // Tomorrow
        scheduledTime: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date()) ?? Date(),
        stops: sampleStops
    )
    
    static let todayRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Today's Pickup Run",
        scheduledDate: Date(),
        scheduledTime: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date()) ?? Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Get ready", estimatedMinutes: 5),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[2], task: "Pick up Sophia", estimatedMinutes: 8),
            RunStop(name: "Home", type: .home, task: "Return home", estimatedMinutes: 12)
        ]
    )
    
    static let completedRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Monday Morning Drop-off",
        scheduledDate: Date().addingTimeInterval(-86400), // Yesterday
        scheduledTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Start journey", estimatedMinutes: 5, isCompleted: true),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[0], task: "Drop off Emma", estimatedMinutes: 10, isCompleted: true),
            RunStop(name: "Home", type: .home, task: "Return home", estimatedMinutes: 15, isCompleted: true)
        ],
        isCompleted: true
    )
    
    static let longRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Friday Multi-Stop Adventure",
        scheduledDate: Date().addingTimeInterval(345600), // 4 days from now
        scheduledTime: Calendar.current.date(bySettingHour: 14, minute: 45, second: 0, of: Date()) ?? Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Pack everything", estimatedMinutes: 8),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[0], task: "Pick up Emma", estimatedMinutes: 12),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[1], task: "Pick up Liam", estimatedMinutes: 8),
            RunStop(name: "Music Academy", type: .music, assignedChild: sampleChildren[1], task: "Drop Liam for lesson", estimatedMinutes: 15),
            RunStop(name: "OT Clinic", type: .ot, assignedChild: sampleChildren[0], task: "Drop Emma for therapy", estimatedMinutes: 20),
            RunStop(name: "Grocery Store", type: .custom, task: "Quick grocery run", estimatedMinutes: 25),
            RunStop(name: "OT Clinic", type: .ot, assignedChild: sampleChildren[0], task: "Pick up Emma", estimatedMinutes: 15),
            RunStop(name: "Music Academy", type: .music, assignedChild: sampleChildren[1], task: "Pick up Liam", estimatedMinutes: 10),
            RunStop(name: "Home", type: .home, task: "Finally home!", estimatedMinutes: 18)
        ]
    )
    
    static let shortRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Quick School Pickup",
        scheduledDate: Date().addingTimeInterval(172800), // 2 days from now
        scheduledTime: Calendar.current.date(bySettingHour: 15, minute: 15, second: 0, of: Date()) ?? Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Quick departure", estimatedMinutes: 3),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[2], task: "Pick up Sophia", estimatedMinutes: 7),
            RunStop(name: "Home", type: .home, task: "Back home", estimatedMinutes: 8)
        ]
    )
    
    // MARK: - Sample Run Collections
    
    static let allSampleRuns: [ScheduledSchoolRun] = [
        upcomingRun,
        todayRun,
        completedRun,
        longRun,
        shortRun
    ]
    
    static let upcomingRuns: [ScheduledSchoolRun] = [
        upcomingRun,
        todayRun,
        longRun,
        shortRun
    ]
    
    static let pastRuns: [ScheduledSchoolRun] = [
        completedRun
    ]
    
    // MARK: - Execution State Samples
    
    static let executionRunStart: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Execution Demo Run",
        scheduledDate: Date(),
        scheduledTime: Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Get ready to go", estimatedMinutes: 5),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[0], task: "Pick up Emma", estimatedMinutes: 10),
            RunStop(name: "Music School", type: .music, assignedChild: sampleChildren[1], task: "Drop Liam", estimatedMinutes: 15),
            RunStop(name: "Home", type: .home, task: "Return home", estimatedMinutes: 12)
        ]
    )
    
    static let executionRunMidway: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Execution Demo Run",
        scheduledDate: Date(),
        scheduledTime: Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Get ready to go", estimatedMinutes: 5, isCompleted: true),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[0], task: "Pick up Emma", estimatedMinutes: 10, isCompleted: true),
            RunStop(name: "Music School", type: .music, assignedChild: sampleChildren[1], task: "Drop Liam", estimatedMinutes: 15),
            RunStop(name: "Home", type: .home, task: "Return home", estimatedMinutes: 12)
        ]
    )
    
    static let executionRunNearEnd: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Execution Demo Run",
        scheduledDate: Date(),
        scheduledTime: Date(),
        stops: [
            RunStop(name: "Home", type: .home, task: "Get ready to go", estimatedMinutes: 5, isCompleted: true),
            RunStop(name: "School", type: .school, assignedChild: sampleChildren[0], task: "Pick up Emma", estimatedMinutes: 10, isCompleted: true),
            RunStop(name: "Music School", type: .music, assignedChild: sampleChildren[1], task: "Drop Liam", estimatedMinutes: 15, isCompleted: true),
            RunStop(name: "Home", type: .home, task: "Return home", estimatedMinutes: 12)
        ]
    )
    
    // MARK: - Form State Samples
    
    static let emptyFormStops: [RunStop] = [
        RunStop(name: "", type: .home, task: "", estimatedMinutes: 5)
    ]
    
    static let partialFormStops: [RunStop] = [
        RunStop(name: "Home", type: .home, task: "Get ready", estimatedMinutes: 5),
        RunStop(name: "", type: .school, assignedChild: sampleChildren[0], task: "", estimatedMinutes: 10)
    ]
    
    static let completeFormStops: [RunStop] = [
        RunStop(name: "Home", type: .home, task: "Pack snacks", estimatedMinutes: 5),
        RunStop(name: "School", type: .school, assignedChild: sampleChildren[0], task: "Pick up Emma", estimatedMinutes: 10),
        RunStop(name: "Music Academy", type: .music, assignedChild: sampleChildren[1], task: "Drop Liam", estimatedMinutes: 15)
    ]
    
    // MARK: - Accessibility Test Data
    
    static let accessibilityTestRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "Accessibility Test Run with Very Long Name That Should Wrap Properly",
        scheduledDate: Date().addingTimeInterval(86400),
        scheduledTime: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date()) ?? Date(),
        stops: [
            RunStop(
                name: "Home Sweet Home",
                type: .home,
                task: "This is a very long task description that should test how well the UI handles longer text content and wrapping behavior",
                estimatedMinutes: 5
            ),
            RunStop(
                name: "Riverside Elementary School",
                type: .school,
                assignedChild: ChildProfile(name: "Emma-Louise", avatar: "person.circle.fill", age: 8),
                task: "Pick up Emma-Louise from her classroom and collect her art project",
                estimatedMinutes: 15
            )
        ]
    )
    
    // MARK: - Error State Samples
    
    static let invalidRun: ScheduledSchoolRun = ScheduledSchoolRun(
        name: "",
        scheduledDate: Date(),
        scheduledTime: Date(),
        stops: []
    )
    
    // MARK: - Preview Environment Setup
    
    /// Sets up a mock environment for previews
    @MainActor
    static func setupPreviewEnvironment() -> some View {
        EmptyView()
            .environmentObject(AppState())
    }
    
    /// Creates a preview with sample data
    @MainActor
    static func previewWithSampleData<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .environmentObject(AppState())
    }
}

// MARK: - Preview Extensions

extension ScheduledSchoolRun {
    /// Creates a sample run for previews
    static var previewSample: ScheduledSchoolRun {
        SchoolRunPreviewProvider.upcomingRun
    }
    
    /// Creates a completed run for previews
    static var previewCompleted: ScheduledSchoolRun {
        SchoolRunPreviewProvider.completedRun
    }
    
    /// Creates a long run for previews
    static var previewLong: ScheduledSchoolRun {
        SchoolRunPreviewProvider.longRun
    }
}

extension RunStop {
    /// Creates a sample stop for previews
    static var previewSample: RunStop {
        SchoolRunPreviewProvider.sampleStops[1]
    }
    
    /// Creates a completed stop for previews
    static var previewCompleted: RunStop {
        RunStop(
            name: "School",
            type: .school,
            assignedChild: SchoolRunPreviewProvider.sampleChildren[0],
            task: "Pick up Emma",
            estimatedMinutes: 10,
            isCompleted: true
        )
    }
}

extension ChildProfile {
    /// Creates a sample child for previews
    static var previewSample: ChildProfile {
        SchoolRunPreviewProvider.sampleChildren[0]
    }
}