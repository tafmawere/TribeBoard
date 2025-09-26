import Foundation
import SwiftUI

/// Enum representing the main navigation tabs in the TribeBoard app
enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case calendar = "calendar"
    case schoolRun = "schoolRun"
    case homeLife = "homeLife"
    case tasks = "tasks"
    case messages = "messages"
    
    var id: String { rawValue }
    
    /// Display name for the navigation tab
    var displayName: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .calendar:
            return "Calendar"
        case .schoolRun:
            return "Run"
        case .homeLife:
            return "HomeLife"
        case .tasks:
            return "Tasks"
        case .messages:
            return "Messages"
        }
    }
    
    /// Icon name for inactive state
    var icon: String {
        switch self {
        case .dashboard:
            return "house"
        case .calendar:
            return "calendar"
        case .schoolRun:
            return "car"
        case .homeLife:
            return "house.heart"
        case .tasks:
            return "checkmark.circle"
        case .messages:
            return "message"
        }
    }
    
    /// Icon name for active state
    var activeIcon: String {
        switch self {
        case .dashboard:
            return "house.fill"
        case .calendar:
            return "calendar"
        case .schoolRun:
            return "car.fill"
        case .homeLife:
            return "house.heart.fill"
        case .tasks:
            return "checkmark.circle"
        case .messages:
            return "message.fill"
        }
    }
}