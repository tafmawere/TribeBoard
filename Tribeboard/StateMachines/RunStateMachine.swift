//
//  RunStateMachine.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation

// MARK: - Driver Actions

enum DriverAction: Codable, Equatable, Hashable {
    case startRun
    case arriveStop
    case confirmPickup(passengerId: String)
    case confirmDropoff(passengerId: String)
    case nextStop
    case pauseRun
    case resumeRun
    case markDelayed(reason: String)
    case clearDelayed
    case endRun
}

// MARK: - Admin Actions

enum AdminAction: Codable, Equatable, Hashable {
    case cancelRun(reason: String)
    case reassignDriver(newDriverId: String)
    case editRunDetails // pre-start only
}

// MARK: - State Machine Engine

class RunStateMachine {
    
    // MARK: - State Transition Validation
    
    static func canTransition(from currentState: RunStatus, to newState: RunStatus, with action: DriverAction) -> Bool {
        switch (currentState, newState, action) {
        
        // SCHEDULED State Transitions
        case (.scheduled, .activeEnroute, .startRun):
            return true
            
        // ACTIVE_ENROUTE State Transitions
        case (.activeEnroute, .arrivedAtStop, .arriveStop):
            return true
        case (.activeEnroute, .paused, .pauseRun):
            return true
        case (.activeEnroute, .cancelled, _):
            return false // Only admin can cancel
        case (.activeEnroute, .completed, .endRun):
            return true // Allow early completion
            
        // ARRIVED_AT_STOP State Transitions
        case (.arrivedAtStop, .activeEnroute, .nextStop):
            return true
        case (.arrivedAtStop, .completed, .endRun):
            return true // If all stops complete
        case (.arrivedAtStop, .paused, .pauseRun):
            return true
            
        // PAUSED State Transitions
        case (.paused, .activeEnroute, .resumeRun):
            return true
        case (.paused, .arrivedAtStop, .resumeRun):
            return true
            
        // Terminal states cannot transition
        case (.completed, _, _), (.cancelled, _, _):
            return false
            
        default:
            return false
        }
    }
    
    static func canTransition(from currentState: RunStatus, to newState: RunStatus, with action: AdminAction) -> Bool {
        switch (currentState, newState, action) {
        
        // Admin can cancel from any non-terminal state
        case (_, .cancelled, .cancelRun):
            return !currentState.isTerminal
            
        // Admin can reassign driver only when scheduled
        case (.scheduled, .scheduled, .reassignDriver):
            return true
            
        // Admin can edit details only when scheduled
        case (.scheduled, .scheduled, .editRunDetails):
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - State Transition Processing
    
    static func processDriverAction(_ action: DriverAction, for run: inout Run) -> StateTransitionResult {
        let currentState = run.status
        
        switch action {
        case .startRun:
            guard canTransition(from: currentState, to: .activeEnroute, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .activeEnroute))
            }
            run.status = .activeEnroute
            run.startTime = Date()
            return .success(.runStarted)
            
        case .arriveStop:
            guard canTransition(from: currentState, to: .arrivedAtStop, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .arrivedAtStop))
            }
            run.status = .arrivedAtStop
            return .success(.runArrivedStop)
            
        case .confirmPickup(let passengerId):
            guard currentState == .arrivedAtStop else {
                return .failure(.invalidState("Can only confirm pickup when arrived at stop"))
            }
            
            // Update passenger status
            if let index = run.passengers.firstIndex(where: { $0.id == passengerId }) {
                run.passengers[index].status = .onboard
                return .success(.passengerPickedUp)
            } else {
                return .failure(.passengerNotFound(passengerId))
            }
            
        case .confirmDropoff(let passengerId):
            guard currentState == .arrivedAtStop else {
                return .failure(.invalidState("Can only confirm dropoff when arrived at stop"))
            }
            
            // Update passenger status
            if let index = run.passengers.firstIndex(where: { $0.id == passengerId }) {
                run.passengers[index].status = .droppedOff
                return .success(.passengerDroppedOff)
            } else {
                return .failure(.passengerNotFound(passengerId))
            }
            
        case .nextStop:
            guard canTransition(from: currentState, to: .activeEnroute, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .activeEnroute))
            }
            
            // Validate current stop completion
            let currentStop = run.stops[run.currentStopIndex]
            guard isStopCompleted(currentStop, in: run) else {
                return .failure(.stopNotCompleted("Current stop requirements not met"))
            }
            
            // Mark current stop as completed
            run.stops[run.currentStopIndex].isCompleted = true
            run.stops[run.currentStopIndex].completedAt = Date()
            
            // Move to next stop or complete run
            if run.currentStopIndex + 1 < run.stops.count {
                run.currentStopIndex += 1
                run.status = .activeEnroute
                return .success(.runArrivedStop)
            } else {
                run.status = .completed
                return .success(.runCompleted)
            }
            
        case .pauseRun:
            guard canTransition(from: currentState, to: .paused, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .paused))
            }
            run.status = .paused
            return .success(.runPaused)
            
        case .resumeRun:
            let targetState: RunStatus = run.currentStopIndex < run.stops.count ? .activeEnroute : .completed
            guard canTransition(from: currentState, to: targetState, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: targetState))
            }
            run.status = targetState
            return .success(.runResumed)
            
        case .markDelayed(let reason):
            guard currentState.isActive else {
                return .failure(.invalidState("Can only mark delay during active run"))
            }
            run.isDelayed = true
            run.delayReason = reason
            return .success(.runDelayed)
            
        case .clearDelayed:
            run.isDelayed = false
            run.delayReason = nil
            return .success(.runDelayCleared)
            
        case .endRun:
            guard canTransition(from: currentState, to: .completed, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .completed))
            }
            run.status = .completed
            return .success(.runCompleted)
        }
    }
    
    static func processAdminAction(_ action: AdminAction, for run: inout Run) -> StateTransitionResult {
        let currentState = run.status
        
        switch action {
        case .cancelRun(let reason):
            guard canTransition(from: currentState, to: .cancelled, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .cancelled))
            }
            run.status = .cancelled
            run.delayReason = reason
            return .success(.runCancelled)
            
        case .reassignDriver(let newDriverId):
            guard canTransition(from: currentState, to: .scheduled, with: action) else {
                return .failure(.invalidTransition(from: currentState, to: .scheduled))
            }
            run.driverId = newDriverId
            return .success(.driverReassigned)
            
        case .editRunDetails:
            guard currentState == .scheduled else {
                return .failure(.invalidState("Can only edit details when run is scheduled"))
            }
            // Details editing is handled by the caller
            return .success(.runCreated)
        }
    }
    
    // MARK: - Stop Completion Validation
    
    private static func isStopCompleted(_ stop: RunStop, in run: Run) -> Bool {
        switch stop.type {
        case .pickup:
            // All required passengers must be onboard
            return stop.requiredPassengerIds.allSatisfy { passengerId in
                run.passengers.first { $0.id == passengerId }?.status == .onboard
            }
            
        case .dropoff:
            // All required passengers must be dropped off
            return stop.requiredPassengerIds.allSatisfy { passengerId in
                run.passengers.first { $0.id == passengerId }?.status == .droppedOff
            }
            
        case .waypoint:
            // Waypoints are completed when driver taps next stop
            return true
        }
    }
    
    // MARK: - Validation Helpers
    
    static func validateRunForStart(_ run: Run) -> ValidationResult {
        guard run.status == .scheduled else {
            return .failure("Run must be in scheduled state to start")
        }
        
        guard !run.stops.isEmpty else {
            return .failure("Run must have at least one stop")
        }
        
        guard !run.passengers.isEmpty else {
            return .failure("Run must have at least one passenger")
        }
        
        return .success
    }
    
    static func getAvailableActions(for run: Run, userRole: MemberRole) -> [DriverAction] {
        guard userRole == .driver else { return [] }
        
        var actions: [DriverAction] = []
        
        switch run.status {
        case .scheduled:
            actions.append(.startRun)
            
        case .activeEnroute:
            actions.append(.arriveStop)
            actions.append(.pauseRun)
            if !run.isDelayed {
                actions.append(.markDelayed(reason: ""))
            } else {
                actions.append(.clearDelayed)
            }
            actions.append(.endRun) // Allow early completion
            
        case .arrivedAtStop:
            let currentStop = run.stops[run.currentStopIndex]
            
            // Add pickup/dropoff actions for required passengers
            for passengerId in currentStop.requiredPassengerIds {
                if let passenger = run.passengers.first(where: { $0.id == passengerId }) {
                    switch currentStop.type {
                    case .pickup:
                        if passenger.status == .waiting {
                            actions.append(.confirmPickup(passengerId: passengerId))
                        }
                    case .dropoff:
                        if passenger.status == .onboard {
                            actions.append(.confirmDropoff(passengerId: passengerId))
                        }
                    case .waypoint:
                        break
                    }
                }
            }
            
            // Add next stop action if current stop can be completed
            if isStopCompleted(currentStop, in: run) {
                actions.append(.nextStop)
            }
            
            actions.append(.pauseRun)
            actions.append(.endRun)
            
        case .paused:
            actions.append(.resumeRun)
            
        case .completed, .cancelled:
            break // No actions available for terminal states
        }
        
        return actions
    }
    
    // MARK: - Enhanced Role-Based Action Validation
    
    /// Get available driver actions with enhanced role-based permission checking
    /// Implements Requirements 6.1, 6.2, 6.3, 6.4
    static func getAvailableDriverActions(
        for run: Run,
        roleContext: RoleContext
    ) -> [DriverAction] {
        // Check if user has driver permissions and is assigned to this run
        guard roleContext.role == .driver || roleContext.role == .admin else { return [] }
        guard run.driverId == roleContext.userId || roleContext.role == .admin else { return [] }
        
        var actions: [DriverAction] = []
        
        switch run.status {
        case .scheduled:
            if PermissionValidator.canPerformOperation(.startRun, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.startRun)
            }
            
        case .activeEnroute:
            if PermissionValidator.canPerformOperation(.arriveAtStop, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.arriveStop)
            }
            if PermissionValidator.canPerformOperation(.pauseRun, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.pauseRun)
            }
            if PermissionValidator.canPerformOperation(.endRun, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.endRun)
            }
            
            if !run.isDelayed {
                if PermissionValidator.canPerformOperation(.markDelayed, role: roleContext.role, userId: roleContext.userId, run: run) {
                    actions.append(.markDelayed(reason: ""))
                }
            } else {
                if PermissionValidator.canPerformOperation(.clearDelayed, role: roleContext.role, userId: roleContext.userId, run: run) {
                    actions.append(.clearDelayed)
                }
            }
            
        case .arrivedAtStop:
            let currentStop = run.stops[run.currentStopIndex]
            
            // Add pickup/dropoff actions for required passengers
            for passengerId in currentStop.requiredPassengerIds {
                if let passenger = run.passengers.first(where: { $0.id == passengerId }) {
                    switch currentStop.type {
                    case .pickup:
                        if passenger.status == .waiting &&
                           PermissionValidator.canPerformOperation(.confirmPickup, role: roleContext.role, userId: roleContext.userId, run: run) {
                            actions.append(.confirmPickup(passengerId: passengerId))
                        }
                    case .dropoff:
                        if passenger.status == .onboard &&
                           PermissionValidator.canPerformOperation(.confirmDropoff, role: roleContext.role, userId: roleContext.userId, run: run) {
                            actions.append(.confirmDropoff(passengerId: passengerId))
                        }
                    case .waypoint:
                        break
                    }
                }
            }
            
            // Add next stop action if current stop can be completed
            if isStopCompleted(currentStop, in: run) &&
               PermissionValidator.canPerformOperation(.nextStop, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.nextStop)
            }
            
            if PermissionValidator.canPerformOperation(.pauseRun, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.pauseRun)
            }
            if PermissionValidator.canPerformOperation(.endRun, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.endRun)
            }
            
        case .paused:
            if PermissionValidator.canPerformOperation(.resumeRun, role: roleContext.role, userId: roleContext.userId, run: run) {
                actions.append(.resumeRun)
            }
            
        case .completed, .cancelled:
            break // No actions available for terminal states
        }
        
        return actions
    }
    
    /// Get available admin actions with permission checking
    /// Implements Requirements 6.1, 6.2, 6.3, 6.4
    static func getAvailableAdminActions(
        for run: Run,
        roleContext: RoleContext
    ) -> [AdminAction] {
        guard roleContext.role == .admin else { return [] }
        
        var actions: [AdminAction] = []
        
        if PermissionValidator.canPerformOperation(.cancelRun, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.cancelRun(reason: ""))
        }
        
        if PermissionValidator.canPerformOperation(.reassignDriver, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.reassignDriver(newDriverId: ""))
        }
        
        if PermissionValidator.canPerformOperation(.editRunDetails, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.editRunDetails)
        }
        
        return actions
    }
    
    /// Process driver action with permission validation
    /// Implements Requirements 6.1, 6.2, 6.3, 6.4
    static func processDriverActionWithPermissions(
        _ action: DriverAction,
        for run: inout Run,
        roleContext: RoleContext
    ) -> StateTransitionResult {
        // Validate permissions before processing
        let operation = mapDriverActionToOperation(action)
        
        do {
            try PermissionValidator.validatePermission(operation, role: roleContext.role, userId: roleContext.userId, run: run)
        } catch {
            return .failure(.permissionDenied(error.localizedDescription))
        }
        
        // Process the action if permissions are valid
        return processDriverAction(action, for: &run)
    }
    
    /// Process admin action with permission validation
    /// Implements Requirements 6.1, 6.2, 6.3, 6.4
    static func processAdminActionWithPermissions(
        _ action: AdminAction,
        for run: inout Run,
        roleContext: RoleContext
    ) -> StateTransitionResult {
        // Validate permissions before processing
        let operation = mapAdminActionToOperation(action)
        
        do {
            try PermissionValidator.validatePermission(operation, role: roleContext.role, userId: roleContext.userId, run: run)
        } catch {
            return .failure(.permissionDenied(error.localizedDescription))
        }
        
        // Process the action if permissions are valid
        return processAdminAction(action, for: &run)
    }
    
    // MARK: - Action Mapping Helpers
    
    private static func mapDriverActionToOperation(_ action: DriverAction) -> RunOperation {
        switch action {
        case .startRun: return .startRun
        case .arriveStop: return .arriveAtStop
        case .confirmPickup: return .confirmPickup
        case .confirmDropoff: return .confirmDropoff
        case .nextStop: return .nextStop
        case .pauseRun: return .pauseRun
        case .resumeRun: return .resumeRun
        case .markDelayed: return .markDelayed
        case .clearDelayed: return .clearDelayed
        case .endRun: return .endRun
        }
    }
    
    private static func mapAdminActionToOperation(_ action: AdminAction) -> RunOperation {
        switch action {
        case .cancelRun: return .cancelRun
        case .reassignDriver: return .reassignDriver
        case .editRunDetails: return .editRunDetails
        }
    }
}

// MARK: - Result Types

enum StateTransitionResult {
    case success(RunEventType)
    case failure(StateTransitionError)
}

enum StateTransitionError: LocalizedError {
    case invalidTransition(from: RunStatus, to: RunStatus)
    case invalidState(String)
    case passengerNotFound(String)
    case stopNotCompleted(String)
    case permissionDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Invalid transition from \(from.displayName) to \(to.displayName)"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .passengerNotFound(let passengerId):
            return "Passenger not found: \(passengerId)"
        case .stopNotCompleted(let message):
            return "Stop not completed: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        }
    }
}

enum ValidationResult {
    case success
    case failure(String)
}