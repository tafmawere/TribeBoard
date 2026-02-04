//
//  FamilyRole.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation

// MARK: - Family Role System

/// Enhanced role system for family members with specific permissions
/// Implements Requirements 6.1, 6.2, 6.3, 6.4
enum FamilyRole: String, Codable, CaseIterable {
    case driver = "driver"
    case observer = "observer"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .driver: return "Driver"
        case .observer: return "Observer"
        case .admin: return "Admin"
        }
    }
    
    var description: String {
        switch self {
        case .driver: return "Can execute runs and perform driver actions"
        case .observer: return "Can monitor runs in real-time with read-only access"
        case .admin: return "Can manage runs, cancel, reassign drivers, and perform administrative actions"
        }
    }
}

// MARK: - Run Operation Permissions

/// Defines all possible operations that can be performed on runs
enum RunOperation: String, CaseIterable {
    // Driver Operations
    case startRun = "startRun"
    case arriveAtStop = "arriveAtStop"
    case confirmPickup = "confirmPickup"
    case confirmDropoff = "confirmDropoff"
    case nextStop = "nextStop"
    case pauseRun = "pauseRun"
    case resumeRun = "resumeRun"
    case markDelayed = "markDelayed"
    case clearDelayed = "clearDelayed"
    case endRun = "endRun"
    
    // Observer Operations
    case viewRunDetails = "viewRunDetails"
    case viewRunTimeline = "viewRunTimeline"
    case viewDriverLocation = "viewDriverLocation"
    case acknowledgeUpdate = "acknowledgeUpdate"
    case contactDriver = "contactDriver"
    
    // Admin Operations
    case cancelRun = "cancelRun"
    case reassignDriver = "reassignDriver"
    case editRunDetails = "editRunDetails"
    case viewAllRuns = "viewAllRuns"
    case manageFamily = "manageFamily"
    
    // Run Creation Operations
    case createRun = "createRun"
    case selectDriver = "selectDriver"
    case selectPassengers = "selectPassengers"
    case defineStops = "defineStops"
    case confirmRunCreation = "confirmRunCreation"
    
    var displayName: String {
        switch self {
        case .startRun: return "Start Run"
        case .arriveAtStop: return "Arrive at Stop"
        case .confirmPickup: return "Confirm Pickup"
        case .confirmDropoff: return "Confirm Dropoff"
        case .nextStop: return "Next Stop"
        case .pauseRun: return "Pause Run"
        case .resumeRun: return "Resume Run"
        case .markDelayed: return "Mark Delayed"
        case .clearDelayed: return "Clear Delayed"
        case .endRun: return "End Run"
        case .viewRunDetails: return "View Run Details"
        case .viewRunTimeline: return "View Run Timeline"
        case .viewDriverLocation: return "View Driver Location"
        case .acknowledgeUpdate: return "Acknowledge Update"
        case .contactDriver: return "Contact Driver"
        case .cancelRun: return "Cancel Run"
        case .reassignDriver: return "Reassign Driver"
        case .editRunDetails: return "Edit Run Details"
        case .viewAllRuns: return "View All Runs"
        case .manageFamily: return "Manage Family"
        case .createRun: return "Create Run"
        case .selectDriver: return "Select Driver"
        case .selectPassengers: return "Select Passengers"
        case .defineStops: return "Define Stops"
        case .confirmRunCreation: return "Confirm Run Creation"
        }
    }
}

// MARK: - Permission Validation System

/// Centralized permission validation system
/// Implements Requirements 6.1, 6.2, 6.3, 6.4
class PermissionValidator {
    
    /// Check if a role has permission to perform a specific operation
    static func hasPermission(role: FamilyRole, for operation: RunOperation) -> Bool {
        switch role {
        case .driver:
            return driverPermissions.contains(operation)
        case .observer:
            return observerPermissions.contains(operation)
        case .admin:
            return adminPermissions.contains(operation)
        }
    }
    
    /// Check if a user can perform an operation on a specific run
    /// Considers both role permissions and run-specific context
    static func canPerformOperation(
        _ operation: RunOperation,
        role: FamilyRole,
        userId: String,
        run: Run
    ) -> Bool {
        // First check if role has general permission
        guard hasPermission(role: role, for: operation) else {
            return false
        }
        
        // Additional context-specific validation
        switch operation {
        case .startRun, .arriveAtStop, .confirmPickup, .confirmDropoff, 
             .nextStop, .pauseRun, .resumeRun, .markDelayed, .clearDelayed, .endRun:
            // Driver operations require being the assigned driver
            return role == .driver && run.driverId == userId
            
        case .editRunDetails, .reassignDriver:
            // Can only edit scheduled runs
            return role == .admin && run.status == .scheduled
            
        case .cancelRun:
            // Admin can cancel non-terminal runs
            return role == .admin && !run.status.isTerminal
            
        case .viewRunDetails, .viewRunTimeline, .viewDriverLocation, 
             .acknowledgeUpdate, .contactDriver:
            // Observers can view runs in their family
            return run.familyId == getFamilyId(for: userId)
            
        case .createRun, .selectDriver, .selectPassengers, .defineStops, .confirmRunCreation:
            // All roles can create runs (family members)
            return true
            
        case .viewAllRuns, .manageFamily:
            // Admin-only operations
            return role == .admin
        }
    }
    
    /// Get all available operations for a role and run context
    static func getAvailableOperations(
        role: FamilyRole,
        userId: String,
        run: Run
    ) -> [RunOperation] {
        return RunOperation.allCases.filter { operation in
            canPerformOperation(operation, role: role, userId: userId, run: run)
        }
    }
    
    /// Validate permission and throw error if not allowed
    static func validatePermission(
        _ operation: RunOperation,
        role: FamilyRole,
        userId: String,
        run: Run
    ) throws {
        guard canPerformOperation(operation, role: role, userId: userId, run: run) else {
            throw PermissionError.operationNotAllowed(
                operation: operation,
                role: role,
                reason: getPermissionDenialReason(operation, role: role, userId: userId, run: run)
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private static let driverPermissions: Set<RunOperation> = [
        // Driver execution operations
        .startRun, .arriveAtStop, .confirmPickup, .confirmDropoff,
        .nextStop, .pauseRun, .resumeRun, .markDelayed, .clearDelayed, .endRun,
        
        // Observer operations (drivers can also observe)
        .viewRunDetails, .viewRunTimeline, .viewDriverLocation,
        .acknowledgeUpdate, .contactDriver,
        
        // Run creation operations
        .createRun, .selectDriver, .selectPassengers, .defineStops, .confirmRunCreation
    ]
    
    private static let observerPermissions: Set<RunOperation> = [
        // Observer-only operations
        .viewRunDetails, .viewRunTimeline, .viewDriverLocation,
        .acknowledgeUpdate, .contactDriver,
        
        // Run creation operations
        .createRun, .selectDriver, .selectPassengers, .defineStops, .confirmRunCreation
    ]
    
    private static let adminPermissions: Set<RunOperation> = [
        // All driver permissions
        .startRun, .arriveAtStop, .confirmPickup, .confirmDropoff,
        .nextStop, .pauseRun, .resumeRun, .markDelayed, .clearDelayed, .endRun,
        
        // All observer permissions
        .viewRunDetails, .viewRunTimeline, .viewDriverLocation,
        .acknowledgeUpdate, .contactDriver,
        
        // Admin-specific operations
        .cancelRun, .reassignDriver, .editRunDetails, .viewAllRuns, .manageFamily,
        
        // Run creation operations
        .createRun, .selectDriver, .selectPassengers, .defineStops, .confirmRunCreation
    ]
    
    private static func getFamilyId(for userId: String) -> String {
        // TODO: Implement family lookup logic
        // For now, return a placeholder - this would typically query the user's family membership
        return "default_family"
    }
    
    /// Get detailed permission denial reason (public version)
    /// Implements Requirements 6.5
    static func getPermissionDenialReason(
        _ operation: RunOperation,
        role: FamilyRole,
        userId: String,
        run: Run
    ) -> String {
        if !hasPermission(role: role, for: operation) {
            return "\(role.displayName) role does not have permission for \(operation.displayName)"
        }
        
        switch operation {
        case .startRun, .arriveAtStop, .confirmPickup, .confirmDropoff,
             .nextStop, .pauseRun, .resumeRun, .markDelayed, .clearDelayed, .endRun:
            if run.driverId != userId {
                return "Only the assigned driver can perform this action"
            }
            
        case .editRunDetails, .reassignDriver:
            if run.status != .scheduled {
                return "Can only edit scheduled runs"
            }
            
        case .cancelRun:
            if run.status.isTerminal {
                return "Cannot cancel completed or already cancelled runs"
            }
            
        default:
            break
        }
        
        return "Operation not allowed in current context"
    }
}

// MARK: - Permission Errors

enum PermissionError: LocalizedError {
    case operationNotAllowed(operation: RunOperation, role: FamilyRole, reason: String)
    case roleNotFound(userId: String)
    case invalidRole(String)
    
    var errorDescription: String? {
        switch self {
        case .operationNotAllowed(let operation, let role, let reason):
            return "Permission denied: \(operation.displayName) not allowed for \(role.displayName). \(reason)"
        case .roleNotFound(let userId):
            return "Role not found for user: \(userId)"
        case .invalidRole(let role):
            return "Invalid role: \(role)"
        }
    }
}

// MARK: - Role Context

/// Context information for role-based operations
struct RoleContext {
    let userId: String
    let role: FamilyRole
    let familyId: String
    
    init(userId: String, role: FamilyRole, familyId: String) {
        self.userId = userId
        self.role = role
        self.familyId = familyId
    }
}