//
//  RoleManagementService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine

// MARK: - Role Management Service

/// Service for managing dynamic role changes and permission updates
/// Implements Requirements 6.5
@MainActor
class RoleManagementService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentUserRole: FamilyRole = .observer
    @Published private(set) var currentUserId: String = ""
    @Published private(set) var currentFamilyId: String = ""
    @Published private(set) var availableOperations: Set<RunOperation> = []
    
    // MARK: - Private Properties
    
    private var roleContext: RoleContext {
        RoleContext(userId: currentUserId, role: currentUserRole, familyId: currentFamilyId)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupRoleChangeObserver()
    }
    
    // MARK: - Public Methods
    
    /// Set the current user (for demo user switching)
    /// Implements Requirements 2
    func setCurrentUser(userId: String, displayName: String, role: FamilyRole, familyId: String) {
        updateUserRole(role, userId: userId, familyId: familyId)
        print("👤 Current user set to: \(displayName) (role: \(role.displayName))")
    }
    
    /// Update the current user's role and refresh permissions
    /// Implements Requirements 6.5
    func updateUserRole(_ newRole: FamilyRole, userId: String, familyId: String) {
        let previousRole = currentUserRole
        
        currentUserRole = newRole
        currentUserId = userId
        currentFamilyId = familyId
        
        // Refresh available operations for the new role
        refreshAvailableOperations()
        
        // Notify observers of role change
        NotificationCenter.default.post(
            name: .userRoleDidChange,
            object: nil,
            userInfo: [
                "previousRole": previousRole,
                "newRole": newRole,
                "userId": userId,
                "familyId": familyId
            ]
        )
        
        print("🔄 Role updated: \(previousRole.displayName) → \(newRole.displayName) for user \(userId)")
    }
    
    /// Check if current user can perform a specific operation on a run
    /// Implements Requirements 6.5
    func canPerformOperation(_ operation: RunOperation, on run: Run) -> Bool {
        return PermissionValidator.canPerformOperation(
            operation,
            role: currentUserRole,
            userId: currentUserId,
            run: run
        )
    }
    
    /// Get available driver actions for current user and run
    /// Implements Requirements 6.5
    func getAvailableDriverActions(for run: Run) -> [DriverAction] {
        return RunStateMachine.getAvailableDriverActions(for: run, roleContext: roleContext)
    }
    
    /// Get available admin actions for current user and run
    /// Implements Requirements 6.5
    func getAvailableAdminActions(for run: Run) -> [AdminAction] {
        return RunStateMachine.getAvailableAdminActions(for: run, roleContext: roleContext)
    }
    
    /// Validate and process a driver action with current user permissions
    /// Implements Requirements 6.5
    func processDriverAction(_ action: DriverAction, for run: inout Run) -> StateTransitionResult {
        return RunStateMachine.processDriverActionWithPermissions(action, for: &run, roleContext: roleContext)
    }
    
    /// Validate and process an admin action with current user permissions
    /// Implements Requirements 6.5
    func processAdminAction(_ action: AdminAction, for run: inout Run) -> StateTransitionResult {
        return RunStateMachine.processAdminActionWithPermissions(action, for: &run, roleContext: roleContext)
    }
    
    /// Get filtered runs based on current user's role and permissions
    /// Implements Requirements 6.5
    func getFilteredRuns(_ runs: [Run]) -> [Run] {
        switch currentUserRole {
        case .driver:
            // Drivers see runs assigned to them
            return runs.filter { $0.driverId == currentUserId }
            
        case .observer:
            // Observers see runs in their family
            return runs.filter { $0.familyId == currentFamilyId }
            
        case .admin:
            // Admins see all runs in their family
            return runs.filter { $0.familyId == currentFamilyId }
        }
    }
    
    /// Get role-appropriate UI configuration for a run
    /// Implements Requirements 6.5
    func getUIConfiguration(for run: Run) -> RunUIConfiguration {
        let driverActions = getAvailableDriverActions(for: run)
        let adminActions = getAvailableAdminActions(for: run)
        let canViewDetails = canPerformOperation(.viewRunDetails, on: run)
        let canViewTimeline = canPerformOperation(.viewRunTimeline, on: run)
        let canViewLocation = canPerformOperation(.viewDriverLocation, on: run)
        
        return RunUIConfiguration(
            role: currentUserRole,
            canViewDetails: canViewDetails,
            canViewTimeline: canViewTimeline,
            canViewDriverLocation: canViewLocation,
            availableDriverActions: driverActions,
            availableAdminActions: adminActions,
            showDriverInterface: currentUserRole == .driver && run.driverId == currentUserId,
            showObserverInterface: currentUserRole == .observer || currentUserRole == .admin,
            showAdminControls: currentUserRole == .admin
        )
    }
    
    // MARK: - Dynamic Permission Updates
    
    /// Refresh permissions for all active runs when role changes
    /// Implements Requirements 6.5
    func refreshPermissionsForActiveRuns(_ runs: [Run]) {
        for run in runs where run.status.isActive {
            // Validate current permissions for active runs
            let driverActions = getAvailableDriverActions(for: run)
            let adminActions = getAvailableAdminActions(for: run)
            
            // Post notification for UI to update specific run permissions
            NotificationCenter.default.post(
                name: .runPermissionsDidUpdate,
                object: nil,
                userInfo: [
                    "runId": run.id,
                    "driverActions": driverActions,
                    "adminActions": adminActions,
                    "uiConfiguration": getUIConfiguration(for: run)
                ]
            )
        }
    }
    
    /// Validate permissions before allowing any action
    /// Implements Requirements 6.5
    func validateAndExecuteAction<T>(
        _ action: T,
        on run: inout Run,
        executor: (T, inout Run, RoleContext) -> StateTransitionResult
    ) -> StateTransitionResult {
        // Execute with current role context
        let result = executor(action, &run, roleContext)
        
        // If successful, refresh permissions for this run
        if case .success = result {
            refreshPermissionsForActiveRuns([run])
        }
        
        return result
    }
    
    /// Handle external role changes (from admin assignment, family updates, etc.)
    /// Implements Requirements 6.5
    func handleExternalRoleChange(
        newRole: FamilyRole,
        userId: String,
        familyId: String,
        activeRuns: [Run] = []
    ) {
        let previousRole = currentUserRole
        
        // Update role
        updateUserRole(newRole, userId: userId, familyId: familyId)
        
        // Refresh permissions for all active runs
        refreshPermissionsForActiveRuns(activeRuns)
        
        // Generate and broadcast detailed change summary
        let changeSummary = getPermissionChangeSummary(
            previousRole: previousRole,
            newRole: newRole,
            for: activeRuns
        )
        
        // Post comprehensive role change notification
        NotificationCenter.default.post(
            name: .externalRoleChangeProcessed,
            object: nil,
            userInfo: [
                "previousRole": previousRole,
                "newRole": newRole,
                "userId": userId,
                "familyId": familyId,
                "activeRuns": activeRuns,
                "changeSummary": changeSummary,
                "timestamp": Date()
            ]
        )
        
        // Log role change for audit trail
        print("🔄 External role change: \(previousRole.displayName) → \(newRole.displayName)")
        print("📊 Refreshed permissions for \(activeRuns.count) active runs")
        print("📋 Change summary: \(changeSummary.changeDescription)")
    }
    
    /// Validate permissions with enhanced context checking
    /// Implements Requirements 6.5
    func validatePermissionWithContext(
        _ operation: RunOperation,
        on run: Run,
        context: String? = nil
    ) -> PermissionValidationResult {
        let canPerform = canPerformOperation(operation, on: run)
        
        if canPerform {
            return .allowed
        }
        
        // Provide detailed reason for denial
        let reason = getDetailedPermissionDenialReason(operation, run: run, context: context)
        
        return .denied(reason: reason, suggestedAction: getSuggestedAction(for: operation, run: run))
    }
    
    /// Get detailed permission denial reason
    /// Implements Requirements 6.5
    private func getDetailedPermissionDenialReason(
        _ operation: RunOperation,
        run: Run,
        context: String?
    ) -> String {
        let baseReason = PermissionValidator.getPermissionDenialReason(
            operation,
            role: currentUserRole,
            userId: currentUserId,
            run: run
        )
        
        var detailedReason = baseReason
        
        if let context = context {
            detailedReason += " (Context: \(context))"
        }
        
        // Add role-specific guidance
        switch currentUserRole {
        case .observer:
            detailedReason += ". Observers can view runs but cannot modify them."
        case .driver:
            if run.driverId != currentUserId {
                detailedReason += ". You can only control runs assigned to you."
            }
        case .admin:
            if run.status.isTerminal {
                detailedReason += ". Completed or cancelled runs cannot be modified."
            }
        }
        
        return detailedReason
    }
    
    /// Get suggested action for permission denial
    /// Implements Requirements 6.5
    private func getSuggestedAction(for operation: RunOperation, run: Run) -> String? {
        switch (currentUserRole, operation) {
        case (.observer, .startRun), (.observer, .confirmPickup), (.observer, .confirmDropoff):
            return "Contact the assigned driver or an admin to perform this action"
        case (.driver, .cancelRun), (.driver, .reassignDriver):
            return "Contact an admin to perform this administrative action"
        case (.driver, _) where run.driverId != currentUserId:
            return "This run is assigned to another driver"
        case (_, _) where run.status.isTerminal:
            return "This run has already been completed or cancelled"
        default:
            return nil
        }
    }
    
    /// Get permission change summary for debugging and logging
    /// Implements Requirements 6.5
    func getPermissionChangeSummary(
        previousRole: FamilyRole,
        newRole: FamilyRole,
        for runs: [Run]
    ) -> PermissionChangeSummary {
        var gainedPermissions: [String] = []
        var lostPermissions: [String] = []
        var affectedRuns: [String] = []
        
        for run in runs {
            let previousActions = getActionsForRole(previousRole, run: run)
            let newActions = getActionsForRole(newRole, run: run)
            
            let gained = Set(newActions).subtracting(Set(previousActions))
            let lost = Set(previousActions).subtracting(Set(newActions))
            
            if !gained.isEmpty || !lost.isEmpty {
                affectedRuns.append(run.id)
                gainedPermissions.append(contentsOf: gained.map { $0.displayName })
                lostPermissions.append(contentsOf: lost.map { $0.displayName })
            }
        }
        
        return PermissionChangeSummary(
            previousRole: previousRole,
            newRole: newRole,
            affectedRunsCount: affectedRuns.count,
            gainedPermissions: Array(Set(gainedPermissions)),
            lostPermissions: Array(Set(lostPermissions))
        )
    }
    
    // MARK: - Private Methods
    
    private func setupRoleChangeObserver() {
        // Listen for role changes and update UI accordingly
        NotificationCenter.default.publisher(for: .userRoleDidChange)
            .sink { [weak self] notification in
                self?.handleRoleChange(notification)
            }
            .store(in: &cancellables)
        
        // Listen for external role updates (from backend, admin changes, etc.)
        NotificationCenter.default.publisher(for: .externalRoleUpdateReceived)
            .sink { [weak self] notification in
                self?.handleExternalRoleUpdate(notification)
            }
            .store(in: &cancellables)
    }
    
    private func getActionsForRole(_ role: FamilyRole, run: Run) -> [RunOperation] {
        return RunOperation.allCases.filter { operation in
            PermissionValidator.hasPermission(role: role, for: operation)
        }
    }
    
    private func handleRoleChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newRole = userInfo["newRole"] as? FamilyRole,
              let previousRole = userInfo["previousRole"] as? FamilyRole else {
            return
        }
        
        // Refresh available operations for new role
        refreshAvailableOperations()
        
        // Post UI update notification with detailed change information
        NotificationCenter.default.post(
            name: .uiShouldRefreshForRoleChange,
            object: nil,
            userInfo: [
                "previousRole": previousRole,
                "newRole": newRole,
                "userId": currentUserId,
                "familyId": currentFamilyId
            ]
        )
        
        print("🎭 UI updated for role change: \(previousRole.displayName) → \(newRole.displayName)")
    }
    
    private func handleExternalRoleUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newRole = userInfo["newRole"] as? FamilyRole,
              let userId = userInfo["userId"] as? String,
              let familyId = userInfo["familyId"] as? String else {
            return
        }
        
        // Only process if this update is for the current user
        guard userId == currentUserId else { return }
        
        let activeRuns = userInfo["activeRuns"] as? [Run] ?? []
        handleExternalRoleChange(
            newRole: newRole,
            userId: userId,
            familyId: familyId,
            activeRuns: activeRuns
        )
    }
    
    private func refreshAvailableOperations() {
        // Update available operations based on current role
        availableOperations = Set(RunOperation.allCases.filter { operation in
            PermissionValidator.hasPermission(role: currentUserRole, for: operation)
        })
    }
}

// MARK: - UI Configuration

/// Configuration object for role-based UI display
/// Implements Requirements 6.5
struct RunUIConfiguration {
    let role: FamilyRole
    let canViewDetails: Bool
    let canViewTimeline: Bool
    let canViewDriverLocation: Bool
    let availableDriverActions: [DriverAction]
    let availableAdminActions: [AdminAction]
    let showDriverInterface: Bool
    let showObserverInterface: Bool
    let showAdminControls: Bool
    
    var primaryInterface: UIInterfaceType {
        if showDriverInterface {
            return .driverFocusMode
        } else if showAdminControls {
            return .adminDashboard
        } else {
            return .observerTracking
        }
    }
}

enum UIInterfaceType {
    case driverFocusMode
    case observerTracking
    case adminDashboard
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let userRoleDidChange = Notification.Name("userRoleDidChange")
    static let uiShouldRefreshForRoleChange = Notification.Name("uiShouldRefreshForRoleChange")
    static let runPermissionsDidUpdate = Notification.Name("runPermissionsDidUpdate")
    static let externalRoleUpdateReceived = Notification.Name("externalRoleUpdateReceived")
    static let externalRoleChangeProcessed = Notification.Name("externalRoleChangeProcessed")
}

// MARK: - Permission Validation Result

/// Enhanced permission validation result with detailed feedback
/// Implements Requirements 6.5
enum PermissionValidationResult {
    case allowed
    case denied(reason: String, suggestedAction: String?)
    
    var isAllowed: Bool {
        switch self {
        case .allowed: return true
        case .denied: return false
        }
    }
    
    var userFeedback: String? {
        switch self {
        case .allowed: return nil
        case .denied(let reason, let suggestion):
            var feedback = reason
            if let suggestion = suggestion {
                feedback += "\n\nSuggestion: \(suggestion)"
            }
            return feedback
        }
    }
}

// MARK: - Role Change Coordinator

/// Coordinates role changes across the application
/// Implements Requirements 6.5
class RoleChangeCoordinator {
    
    private let roleManagementService: RoleManagementService
    private let runEventService: RunEventService
    
    init(roleManagementService: RoleManagementService, runEventService: RunEventService) {
        self.roleManagementService = roleManagementService
        self.runEventService = runEventService
    }
    
    /// Handle role change from external source (e.g., admin assignment)
    /// Implements Requirements 6.5
    func handleRoleChange(
        userId: String,
        newRole: FamilyRole,
        familyId: String,
        source: RoleChangeSource
    ) async {
        // Update role in role management service
        await MainActor.run {
            roleManagementService.updateUserRole(newRole, userId: userId, familyId: familyId)
        }
        
        // Log role change event
        await logRoleChangeEvent(userId: userId, newRole: newRole, source: source)
        
        // Refresh active run permissions if user has active runs
        await refreshActiveRunPermissions(userId: userId)
    }
    
    private func logRoleChangeEvent(userId: String, newRole: FamilyRole, source: RoleChangeSource) async {
        // TODO: Implement role change logging
        print("📝 Role change logged: User \(userId) → \(newRole.displayName) (Source: \(source))")
    }
    
    private func refreshActiveRunPermissions(userId: String) async {
        // TODO: Refresh permissions for any active runs involving this user
        print("🔄 Refreshing active run permissions for user \(userId)")
    }
}

enum RoleChangeSource {
    case adminAssignment
    case familyInvitation
    case systemUpdate
    case userRequest
}

// MARK: - Permission Validation Helpers

extension RoleManagementService {
    
    /// Validate multiple operations at once
    /// Implements Requirements 6.5
    func validateOperations(_ operations: [RunOperation], for run: Run) -> [RunOperation: Bool] {
        var results: [RunOperation: Bool] = [:]
        
        for operation in operations {
            results[operation] = canPerformOperation(operation, on: run)
        }
        
        return results
    }
    
    /// Get permission summary for debugging
    /// Implements Requirements 6.5
    func getPermissionSummary(for run: Run) -> PermissionSummary {
        let driverActions = getAvailableDriverActions(for: run)
        let adminActions = getAvailableAdminActions(for: run)
        let viewPermissions = validateOperations([.viewRunDetails, .viewRunTimeline, .viewDriverLocation], for: run)
        
        return PermissionSummary(
            userId: currentUserId,
            role: currentUserRole,
            runId: run.id,
            driverActionsCount: driverActions.count,
            adminActionsCount: adminActions.count,
            canView: viewPermissions.values.contains(true),
            isAssignedDriver: run.driverId == currentUserId
        )
    }
}

struct PermissionSummary {
    let userId: String
    let role: FamilyRole
    let runId: String
    let driverActionsCount: Int
    let adminActionsCount: Int
    let canView: Bool
    let isAssignedDriver: Bool
}

// MARK: - Permission Change Summary

struct PermissionChangeSummary {
    let previousRole: FamilyRole
    let newRole: FamilyRole
    let affectedRunsCount: Int
    let gainedPermissions: [String]
    let lostPermissions: [String]
    
    var hasChanges: Bool {
        return !gainedPermissions.isEmpty || !lostPermissions.isEmpty
    }
    
    var changeDescription: String {
        var description = "Role changed from \(previousRole.displayName) to \(newRole.displayName)"
        
        if affectedRunsCount > 0 {
            description += " affecting \(affectedRunsCount) run\(affectedRunsCount == 1 ? "" : "s")"
        }
        
        if !gainedPermissions.isEmpty {
            description += ". Gained: \(gainedPermissions.joined(separator: ", "))"
        }
        
        if !lostPermissions.isEmpty {
            description += ". Lost: \(lostPermissions.joined(separator: ", "))"
        }
        
        return description
    }
}