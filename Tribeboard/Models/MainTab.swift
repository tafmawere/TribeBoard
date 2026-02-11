//
//  MainTab.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/11.
//

import Foundation

/// Main navigation tabs for the app
/// Used by MainNavigationView and BottomNavigationBar
enum MainTab: Hashable {
    case home
    case runs
    case calendar
    case feed
    case tribe
    
    var description: String {
        switch self {
        case .home: return "Today"
        case .runs: return "Runs"
        case .calendar: return "Calendar"
        case .feed: return "Feed"
        case .tribe: return "Tribe"
        }
    }
}
