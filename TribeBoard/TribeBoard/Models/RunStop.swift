import Foundation
import SwiftUI

/// Represents a single stop in a school run with location, timing, and task information
struct RunStop: Identifiable, Codable {
    let id: UUID
    var name: String
    var time: Date
    var note: String
    var type: StopType
    var isCompleted: Bool
    var task: String
    var estimatedMinutes: Int
    var assignedChild: ChildProfile?
    
    init(id: UUID = UUID(), name: String, time: Date, note: String = "", type: StopType, isCompleted: Bool = false, task: String = "", estimatedMinutes: Int = 5, assignedChild: ChildProfile? = nil) {
        self.id = id
        self.name = name
        self.time = time
        self.note = note
        self.type = type
        self.isCompleted = isCompleted
        self.task = task
        self.estimatedMinutes = estimatedMinutes
        self.assignedChild = assignedChild
    }
    
    // MARK: - Computed Properties
    
    /// Formatted time string for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    /// Display text combining type icon and name
    var displayText: String {
        "\(type.icon) \(name)"
    }
    
    /// Full display text including time
    var fullDisplayText: String {
        "\(displayText) at \(formattedTime)"
    }
    
    /// Status text based on completion
    var statusText: String {
        isCompleted ? "Completed" : "Pending"
    }
    
    /// Color based on completion status
    var statusColor: Color {
        isCompleted ? .green : .primary
    }
    
    /// Formatted duration string for display
    var formattedDuration: String {
        if estimatedMinutes < 60 {
            return "\(estimatedMinutes) min"
        } else {
            let hours = estimatedMinutes / 60
            let minutes = estimatedMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
}

// MARK: - StopType Enum
extension RunStop {
    /// Enum defining the type of stop with various location types
    enum StopType: String, CaseIterable, Codable {
        case home = "home"
        case school = "school"
        case pickup = "pickup"
        case dropoff = "dropoff"
        case music = "music"
        case ot = "ot"
        case custom = "custom"
        
        /// Icon representation for each stop type
        var icon: String {
            switch self {
            case .home:
                return "house.fill"
            case .school:
                return "building.2.fill"
            case .pickup:
                return "arrow.up.circle.fill"
            case .dropoff:
                return "arrow.down.circle.fill"
            case .music:
                return "music.note"
            case .ot:
                return "stethoscope"
            case .custom:
                return "mappin.circle.fill"
            }
        }
        
        /// Display name for each stop type
        var displayName: String {
            switch self {
            case .home:
                return "Home"
            case .school:
                return "School"
            case .pickup:
                return "Pickup"
            case .dropoff:
                return "Drop-off"
            case .music:
                return "Music Academy"
            case .ot:
                return "Occupational Therapy"
            case .custom:
                return "Custom Location"
            }
        }
        
        /// Color associated with each stop type
        var color: Color {
            switch self {
            case .home:
                return .green
            case .school:
                return .blue
            case .pickup:
                return .blue
            case .dropoff:
                return .orange
            case .music:
                return .purple
            case .ot:
                return .red
            case .custom:
                return .gray
            }
        }
        
        /// Alternative SF Symbol for each stop type
        var sfSymbol: String {
            switch self {
            case .home:
                return "house.circle.fill"
            case .school:
                return "graduationcap.circle.fill"
            case .pickup:
                return "person.crop.circle.badge.plus"
            case .dropoff:
                return "person.crop.circle.badge.minus"
            case .music:
                return "music.note.house.fill"
            case .ot:
                return "cross.circle.fill"
            case .custom:
                return "location.circle.fill"
            }
        }
    }
}

// MARK: - Hashable Conformance
extension RunStop: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RunStop, rhs: RunStop) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Comparable Conformance (for sorting by time)
extension RunStop: Comparable {
    static func < (lhs: RunStop, rhs: RunStop) -> Bool {
        lhs.time < rhs.time
    }
}