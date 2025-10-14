import Foundation
import SwiftUI

/// Enum representing the current status of a school run
enum RunStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case inProgress = "inProgress"
    case completed = "completed"
    case cancelled = "cancelled"
    
    /// Display text for the current status
    var displayText: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Color associated with the current status
    var color: Color {
        switch self {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    /// Icon representation for each status
    var icon: String {
        switch self {
        case .scheduled:
            return "calendar"
        case .inProgress:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    /// Alternative icon for different contexts
    var alternativeIcon: String {
        switch self {
        case .scheduled:
            return "clock"
        case .inProgress:
            return "car.fill"
        case .completed:
            return "flag.checkered"
        case .cancelled:
            return "stop.circle.fill"
        }
    }
    
    /// Background color for status badges
    var backgroundColor: Color {
        color.opacity(0.1)
    }
    
    /// Foreground color for status badges
    var foregroundColor: Color {
        color
    }
    
    /// Determines if the run can be started from this status
    var canStart: Bool {
        self == .scheduled
    }
    
    /// Determines if the run can be paused from this status
    var canPause: Bool {
        self == .inProgress
    }
    
    /// Determines if the run can be resumed from this status
    var canResume: Bool {
        false // Paused state not implemented in this version
    }
    
    /// Determines if the run can be cancelled from this status
    var canCancel: Bool {
        self == .scheduled || self == .inProgress
    }
    
    /// Determines if the run can be completed from this status
    var canComplete: Bool {
        self == .inProgress
    }
    
    /// Determines if the run can be edited from this status
    var canEdit: Bool {
        self == .scheduled
    }
    
    /// Determines if the run can be deleted from this status
    var canDelete: Bool {
        self == .scheduled || self == .cancelled || self == .completed
    }
    
    /// Check if the status represents an active run
    var isActive: Bool {
        self == .inProgress
    }
    
    /// Check if the status represents a finished run
    var isFinished: Bool {
        self == .completed || self == .cancelled
    }
    
    /// Check if the status represents a pending run
    var isPending: Bool {
        self == .scheduled
    }
}

// MARK: - Comparable Conformance (for sorting)
extension RunStatus: Comparable {
    static func < (lhs: RunStatus, rhs: RunStatus) -> Bool {
        let order: [RunStatus] = [.scheduled, .inProgress, .completed, .cancelled]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}