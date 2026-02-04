//
//  ScreenContracts.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import CoreLocation

// MARK: - Screen Contract Protocols
// Implements Requirements 5.1, 5.5 - explicit input/output contracts for each screen

/// Home Dashboard screen contract
/// Displays nextRun, activeRun, and todayEvents based on current user role
protocol HomeDashboardContract {
    // Inputs
    var currentUser: User { get }
    var familyId: String { get }
    var nextRun: Run? { get }
    var activeRun: Run? { get }
    var todayEvents: [Event] { get }
    
    // Outputs
    func openRun(runId: String)
    func openCalendar()
    func createRun()
    func openActivity()
}

/// Driver Focus Mode screen contract
/// Provides Uber-like execution flow with zero cognitive load
protocol DriverFocusModeContract {
    // Inputs
    var runId: String { get }
    var currentStop: RunStop? { get }
    var nextStop: RunStop? { get }
    var passengers: [MemberSummary] { get }
    var runState: RunStatus { get }
    
    // Outputs
    func startRun() async throws
    func arrivedAtStop() async throws
    func confirmPickup(passengerId: String) async throws
    func confirmDropoff(passengerId: String) async throws
    func markDelayed(reason: String) async throws
    func endRun() async throws
}

/// Observer Tracking screen contract
/// Provides real-time monitoring capabilities for observers
protocol ObserverTrackingContract {
    // Inputs
    var runId: String { get }
    var driverLocation: CLLocationCoordinate2D? { get }
    var runState: RunStatus { get }
    var eta: Date? { get }
    var timelineEvents: [RunEvent] { get }
    
    // Outputs
    func acknowledgeUpdate()
    func contactDriver() // external action
}

// MARK: - Supporting Types

/// User information for screen contracts
struct User: Codable, Identifiable {
    let id: String
    let displayName: String
    let role: FamilyRole
    let familyId: String
    let avatarURL: String?
    
    init(id: String, displayName: String, role: FamilyRole, familyId: String, avatarURL: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.familyId = familyId
        self.avatarURL = avatarURL
    }
}

/// Event information for home dashboard
struct Event: Codable, Identifiable {
    let id: String
    let title: String
    let time: Date
    let type: EventType
    let runId: String?
    
    init(id: String = UUID().uuidString, title: String, time: Date, type: EventType, runId: String? = nil) {
        self.id = id
        self.title = title
        self.time = time
        self.type = type
        self.runId = runId
    }
}

enum EventType: String, Codable, CaseIterable {
    case runScheduled = "runScheduled"
    case runStarted = "runStarted"
    case runCompleted = "runCompleted"
    case runCancelled = "runCancelled"
    case runDelayed = "runDelayed"
    
    var displayName: String {
        switch self {
        case .runScheduled: return "Run Scheduled"
        case .runStarted: return "Run Started"
        case .runCompleted: return "Run Completed"
        case .runCancelled: return "Run Cancelled"
        case .runDelayed: return "Run Delayed"
        }
    }
}

// MARK: - Screen Contract Actions

/// Actions available for Home Dashboard
enum HomeDashboardAction {
    case openRun(runId: String)
    case openCalendar
    case createRun
    case openActivity
}

/// Actions available for Driver Focus Mode
enum DriverFocusModeAction {
    case startRun
    case arrivedAtStop
    case confirmPickup(passengerId: String)
    case confirmDropoff(passengerId: String)
    case markDelayed(reason: String)
    case endRun
}

/// Actions available for Observer Tracking
enum ObserverTrackingAction {
    case acknowledgeUpdate
    case contactDriver
}