import Foundation
import SwiftUI

/// Mock data provider for School Run Scheduler
struct MockSchoolRunDataProvider {
    
    // MARK: - Sample Data
    
    static let children: [ChildProfile] = [
        ChildProfile(name: "Emma", avatar: "person.circle.fill", age: 8),
        ChildProfile(name: "Liam", avatar: "person.circle.fill", age: 10),
        ChildProfile(name: "Sophia", avatar: "person.circle.fill", age: 6)
    ]
    
    static let sampleRuns: [SchoolRun] = [
        SchoolRun(
            title: "Morning School Run",
            date: Date(),
            route: [
                RunStop(name: "Home", time: Date(), note: "Pick up Emma", type: .pickup, task: "Pick up Emma", estimatedMinutes: 5),
                RunStop(name: "School", time: Date().addingTimeInterval(1800), note: "Drop off", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
            ]
        ),
        SchoolRun(
            title: "Afternoon Pickup",
            date: Date().addingTimeInterval(3600),
            route: [
                RunStop(name: "School", time: Date().addingTimeInterval(3600), note: "Pick up", type: .pickup, task: "Pick up from school", estimatedMinutes: 10),
                RunStop(name: "Home", time: Date().addingTimeInterval(5400), note: "Drop off", type: .dropoff, task: "Return home", estimatedMinutes: 15)
            ]
        )
    ]
    
    // MARK: - Helper Methods
    
    static func createSampleRun(title: String, date: Date) -> SchoolRun {
        return SchoolRun(
            title: title,
            date: date,
            route: [
                RunStop(name: "Home", time: date, note: "Start", type: .pickup, task: "Get ready to go", estimatedMinutes: 5),
                RunStop(name: "School", time: date.addingTimeInterval(1800), note: "End", type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
            ]
        )
    }
    
    static func createEmptyStop() -> RunStop {
        return RunStop(
            name: "",
            time: Date(),
            note: "",
            type: .custom,
            task: "",
            estimatedMinutes: 5
        )
    }
}