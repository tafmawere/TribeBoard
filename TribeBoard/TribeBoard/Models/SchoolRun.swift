import Foundation

/// Core data model representing a school run with multiple stops and scheduling information
struct ScheduledSchoolRun: Identifiable, Codable {
    let id = UUID()
    var name: String
    var scheduledDate: Date
    var scheduledTime: Date
    var stops: [RunStop]
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    
    /// Computed property that calculates total estimated duration for all stops
    var estimatedDuration: TimeInterval {
        stops.reduce(0) { $0 + TimeInterval($1.estimatedMinutes * 60) }
    }
    
    /// Computed property that returns unique children participating in this run
    var participatingChildren: [ChildProfile] {
        let allChildren = stops.compactMap(\.assignedChild)
        var uniqueChildren: [ChildProfile] = []
        
        for child in allChildren {
            if !uniqueChildren.contains(where: { $0.id == child.id }) {
                uniqueChildren.append(child)
            }
        }
        
        return uniqueChildren
    }
    
    /// Computed property that formats the scheduled date and time for display
    var formattedScheduleTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: scheduledDate) + " at " + dateFormatter.string(from: scheduledTime)
    }
}