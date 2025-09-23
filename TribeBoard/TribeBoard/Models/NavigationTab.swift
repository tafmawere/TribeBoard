import Foundation
import SwiftUI

/// Enum representing the main navigation tabs in the TribeBoard app
enum NavigationTab: String, CaseIterable, Identifiable {
    case home = "home"
    case schoolRun = "school_run"
    case shopping = "shopping"
    case tasks = "tasks"
    
    var id: String { rawValue }
    
    /// Display name for the navigation tab
    var displayName: String {
        switch self {
        case .home:
            return "Home"
        case .schoolRun:
            return "School Run"
        case .shopping:
            return "Shopping"
        case .tasks:
            return "Tasks"
        }
    }
    
    /// Icon name for inactive state
    var icon: String {
        switch self {
        case .home:
            return "house"
        case .schoolRun:
            return "bus"
        case .shopping:
            return "cart"
        case .tasks:
            return "checkmark.circle"
        }
    }
    
    /// Icon name for active state
    var activeIcon: String {
        switch self {
        case .home:
            return "house.fill"
        case .schoolRun:
            return "bus.fill"
        case .shopping:
            return "cart.fill"
        case .tasks:
            return "checkmark.circle.fill"
        }
    }
}