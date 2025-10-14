import Foundation
import SwiftUI

/// Core data model representing a school run with multiple stops and scheduling information
struct SchoolRun: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var route: [RunStop]
    var status: RunStatus
    var createdAt: Date
    var estimatedDuration: TimeInterval
    
    init(id: UUID = UUID(), title: String, date: Date, route: [RunStop] = [], status: RunStatus = .scheduled, createdAt: Date = Date(), estimatedDuration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.date = date
        self.route = route
        self.status = status
        self.createdAt = createdAt
        self.estimatedDuration = estimatedDuration
    }
    
    // MARK: - Computed Properties for UI Display
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// List of participating children names (placeholder implementation)
    var participatingChildren: [String] {
        // Extract unique child names from stop notes or names
        let childNames = route.compactMap { stop in
            // For now, return stop names as placeholder for children
            // This can be enhanced when child assignment is implemented
            stop.note.isEmpty ? nil : stop.note
        }
        return Array(Set(childNames))
    }
    
    /// Check if the run is scheduled for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Check if the run is in the future
    var isUpcoming: Bool {
        date > Date()
    }
    
    /// Check if the run is in the past
    var isPast: Bool {
        date < Date() && !isToday
    }
    
    /// Total number of stops in the route
    var totalStops: Int {
        route.count
    }
    
    /// Number of completed stops
    var completedStops: Int {
        route.filter(\.isCompleted).count
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard totalStops > 0 else { return 0.0 }
        return Double(completedStops) / Double(totalStops)
    }
    
    /// Next incomplete stop in the route
    var nextStop: RunStop? {
        route.first { !$0.isCompleted }
    }
    
    /// Check if all stops are completed
    var allStopsCompleted: Bool {
        !route.isEmpty && route.allSatisfy(\.isCompleted)
    }
    
    /// Formatted duration string for display
    var formattedDuration: String {
        let hours = Int(estimatedDuration) / 3600
        let minutes = (Int(estimatedDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formatted created date string for display
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Get all pickup stops
    var pickupStops: [RunStop] {
        route.filter { $0.type == .pickup }
    }
    
    /// Get all drop-off stops
    var dropoffStops: [RunStop] {
        route.filter { $0.type == .dropoff }
    }
}

// MARK: - Hashable Conformance
extension SchoolRun: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SchoolRun, rhs: SchoolRun) -> Bool {
        lhs.id == rhs.id
    }
}