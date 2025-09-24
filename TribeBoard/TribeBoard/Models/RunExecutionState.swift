import Foundation
import SwiftUI

/// Enum representing the current execution state of a school run
enum RunExecutionState: String, CaseIterable, Codable {
    case notStarted = "not_started"
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
    
    /// Display text for the current execution state
    var displayText: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .active:
            return "In Progress"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Color associated with the current execution state
    var color: Color {
        switch self {
        case .notStarted:
            return .gray
        case .active:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    /// Icon representation for each execution state
    var icon: String {
        switch self {
        case .notStarted:
            return "clock"
        case .active:
            return "play.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    /// Determines if the run can be started from this state
    var canStart: Bool {
        return self == .notStarted || self == .paused
    }
    
    /// Determines if the run can be paused from this state
    var canPause: Bool {
        return self == .active
    }
    
    /// Determines if the run can be cancelled from this state
    var canCancel: Bool {
        return self == .active || self == .paused
    }
}