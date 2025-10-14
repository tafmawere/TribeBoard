import SwiftUI
import Foundation

// MARK: - Helper Data Structures

/// Information about the driver for the school run
struct DriverInfo {
    let name: String
    let avatar: String
}

/// Information about a child participating in the school run
struct ChildInfo {
    let name: String
    let avatar: String
}

/// Information about the destination for the school run
struct DestinationInfo {
    let name: String
    let time: String
}

// MARK: - Run Status Enum
// Note: RunStatus enum is now defined in RunStatus.swift for the comprehensive school run scheduler

// MARK: - Static Data Container

/// Container for all static placeholder data used in the School Run UI
struct SchoolRunUIData {
    
    /// Static driver information
    static let driverInfo = DriverInfo(
        name: "John Doe",
        avatar: "person.circle.fill"
    )
    
    /// Static children information
    static let children = [
        ChildInfo(name: "Emma", avatar: "person.circle"),
        ChildInfo(name: "Liam", avatar: "person.circle"),
        ChildInfo(name: "Sophia", avatar: "person.circle")
    ]
    
    /// Static destination information
    static let destination = DestinationInfo(
        name: "Soccer Practice",
        time: "15:30"
    )
    
    /// Static ETA information
    static let eta = "15 min"
    
    /// Static route points for map visualization
    static let routePoints = [
        CGPoint(x: 50, y: 100),   // Home
        CGPoint(x: 150, y: 80),   // Waypoint
        CGPoint(x: 200, y: 120)   // School
    ]
    
    /// Default run status
    static let defaultStatus = RunStatus.scheduled
}