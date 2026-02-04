//
//  RunEvent.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation

struct RunEvent: Codable, Identifiable {
    let id: String
    let runId: String
    let type: RunEventType
    let timestamp: Date
    let actorId: String
    let stateBefore: RunStatus?
    let stateAfter: RunStatus
    let currentStopIndex: Int
    let location: GeoPoint?
    let note: String?
    
    init(id: String = UUID().uuidString,
         runId: String,
         type: RunEventType,
         timestamp: Date = Date(),
         actorId: String,
         stateBefore: RunStatus?,
         stateAfter: RunStatus,
         currentStopIndex: Int,
         location: GeoPoint? = nil,
         note: String? = nil) {
        self.id = id
        self.runId = runId
        self.type = type
        self.timestamp = timestamp
        self.actorId = actorId
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.currentStopIndex = currentStopIndex
        self.location = location
        self.note = note
    }
}

enum RunEventType: String, Codable, CaseIterable {
    case runCreated = "runCreated"
    case runAssigned = "runAssigned"
    case runStarted = "runStarted"
    case runArrivedStop = "runArrivedStop"
    case passengerPickedUp = "passengerPickedUp"
    case passengerDroppedOff = "passengerDroppedOff"
    case runDelayed = "runDelayed"
    case runDelayCleared = "runDelayCleared"
    case runPaused = "runPaused"
    case runResumed = "runResumed"
    case runCompleted = "runCompleted"
    case runCancelled = "runCancelled"
    case driverReassigned = "driverReassigned"
    case locationUpdated = "locationUpdated"
    
    var displayName: String {
        switch self {
        case .runCreated: return "Run Created"
        case .runAssigned: return "Driver Assigned"
        case .runStarted: return "Run Started"
        case .runArrivedStop: return "Arrived at Stop"
        case .passengerPickedUp: return "Passenger Picked Up"
        case .passengerDroppedOff: return "Passenger Dropped Off"
        case .runDelayed: return "Run Delayed"
        case .runDelayCleared: return "Delay Cleared"
        case .runPaused: return "Run Paused"
        case .runResumed: return "Run Resumed"
        case .runCompleted: return "Run Completed"
        case .runCancelled: return "Run Cancelled"
        case .driverReassigned: return "Driver Reassigned"
        case .locationUpdated: return "Location Updated"
        }
    }
    
    var message: String {
        switch self {
        case .runCreated: return "Run was created"
        case .runAssigned: return "Driver was assigned to run"
        case .runStarted: return "Run has started"
        case .runArrivedStop: return "Driver arrived at stop"
        case .passengerPickedUp: return "Passenger was picked up"
        case .passengerDroppedOff: return "Passenger was dropped off"
        case .runDelayed: return "Run is delayed"
        case .runDelayCleared: return "Run delay was cleared"
        case .runPaused: return "Run was paused"
        case .runResumed: return "Run was resumed"
        case .runCompleted: return "Run completed successfully"
        case .runCancelled: return "Run was cancelled"
        case .driverReassigned: return "New driver was assigned"
        case .locationUpdated: return "Driver location updated"
        }
    }
}