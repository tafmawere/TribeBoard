//
//  DynamicRoleUpdateService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine

// MARK: - Dynamic Role Update Service

/// Service for handling dynamic role permission updates from external sources
/// Implements Requirements 6.5
@MainActor
class DynamicRoleUpdateService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let roleManagementService: RoleManagementService
    private let runEventService: RunEventService
    
    // MARK: - Published Properties
    
    @Published private(set) var pendingRoleUpdates: [PendingRoleUpdate] = []
    @Published private(set) var isProcessingUpdates: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        roleManagementService: RoleManagementService,
        runEventService: RunEventService
    ) {
        self.roleManagementService = roleManagementService
        self.runEventService = runEventService
        
        setupUpdateListeners()
    }
    
    // MARK: - Public Methods
    
    /// Process external role update (from backend, admin assignment, etc.)
    /// Implements Requirements 6.5
    func processExternalRoleUpdate(
        userId: String,
        newRole: FamilyRole,
        familyId: String,
        source: RoleUpdateSource,
        activeRuns: [Run] = []
    ) async {
        let update = PendingRoleUpdate(
            userId: userId,
            newRole: newRole,
            familyId: familyId,
            source: source,
            timestamp: Date(),
            activeRuns: activeRuns
        )
        
        // Add to pending updates
        pendingRoleUpdates.append(update)
        
        // Process immediately if it's for the current user
        if userId == roleManagementService.currentUserId {
            await processCurrentUserRoleUpdate(update)
        } else {
            // Queue for later processing when user becomes active
            print("📋 Queued role update for user \(userId): \(newRole.displayName)")
        }
    }
    
    /// Validate permissions before executing any action
    /// Implements Requirements 6.5
    func validateAndExecuteDriverAction(
        _ action: DriverAction,
        on run: inout Run
    ) -> StateTransitionResult {
        return roleManagementService.validateAndExecuteAction(
            action,
            on: &run,
            executor: RunStateMachine.processDriverActionWithPermissions
        )
    }
    
    /// Validate permissions before executing any admin action
    /// Implements Requirements 6.5
    func validateAndExecuteAdminAction(
        _ action: AdminAction,
        on run: inout Run
    ) -> StateTransitionResult {
        return roleManagementService.validateAndExecuteAction(
            action,
            on: &run,
            executor: RunStateMachine.processAdminActionWithPermissions
        )
    }
    
    /// Handle role change from family management system
    /// Implements Requirements 6.5
    func handleFamilyRoleChange(
        userId: String,
        newRole: FamilyRole,
        familyId: String,
        changedBy: String,
        activeRuns: [Run]
    ) async {
        await processExternalRoleUpdate(
            userId: userId,
            newRole: newRole,
            familyId: familyId,
            source: .familyManagement(changedBy: changedBy),
            activeRuns: activeRuns
        )
        
        // Log the change for audit trail
        print("👥 Family role change: User \(userId) → \(newRole.displayName) by \(changedBy)")
        
        // Trigger immediate UI refresh for affected runs
        await refreshUIForRoleChange(userId: userId, newRole: newRole, activeRuns: activeRuns)
    }
    
    /// Handle real-time role updates from backend synchronization
    /// Implements Requirements 6.5
    func handleRealtimeRoleUpdate(
        userId: String,
        newRole: FamilyRole,
        familyId: String,
        activeRuns: [Run],
        timestamp: Date
    ) async {
        // Only process if this is a newer update
        let existingUpdate = pendingRoleUpdates.first { $0.userId == userId }
        if let existing = existingUpdate, existing.timestamp > timestamp {
            print("⏰ Ignoring older role update for user \(userId)")
            return
        }
        
        await processExternalRoleUpdate(
            userId: userId,
            newRole: newRole,
            familyId: familyId,
            source: .backendSync,
            activeRuns: activeRuns
        )
        
        print("🔄 Real-time role update processed: User \(userId) → \(newRole.displayName)")
    }
    
    /// Refresh UI components immediately after role change
    /// Implements Requirements 6.5
    private func refreshUIForRoleChange(
        userId: String,
        newRole: FamilyRole,
        activeRuns: [Run]
    ) async {
        // Post immediate UI refresh notification
        NotificationCenter.default.post(
            name: .immediateUIRefreshRequired,
            object: nil,
            userInfo: [
                "userId": userId,
                "newRole": newRole,
                "affectedRuns": activeRuns,
                "timestamp": Date()
            ]
        )
        
        // Update each run's UI configuration
        for run in activeRuns {
            let uiConfig = roleManagementService.getUIConfiguration(for: run)
            
            NotificationCenter.default.post(
                name: .runUIConfigurationUpdated,
                object: nil,
                userInfo: [
                    "runId": run.id,
                    "uiConfiguration": uiConfig,
                    "newRole": newRole
                ]
            )
        }
    }
    
    /// Handle role change from admin assignment
    /// Implements Requirements 6.5
    func handleAdminRoleAssignment(
        userId: String,
        newRole: FamilyRole,
        familyId: String,
        adminId: String,
        reason: String?,
        activeRuns: [Run]
    ) async {
        await processExternalRoleUpdate(
            userId: userId,
            newRole: newRole,
            familyId: familyId,
            source: .adminAssignment(adminId: adminId, reason: reason),
            activeRuns: activeRuns
        )
        
        // Log the assignment for audit trail
        let reasonText = reason.map { " (Reason: \($0))" } ?? ""
        print("👑 Admin role assignment: User \(userId) → \(newRole.displayName) by \(adminId)\(reasonText)")
    }
    
    /// Get permission change summary for a role update
    /// Implements Requirements 6.5
    func getPermissionChangeSummary(
        for update: PendingRoleUpdate,
        previousRole: FamilyRole
    ) -> PermissionChangeSummary {
        return roleManagementService.getPermissionChangeSummary(
            previousRole: previousRole,
            newRole: update.newRole,
            for: update.activeRuns
        )
    }
    
    /// Validate and execute action with enhanced permission checking
    /// Implements Requirements 6.5
    func validateAndExecuteActionWithRoleCheck<T>(
        _ action: T,
        on run: inout Run,
        actionType: ActionType,
        executor: (T, inout Run, RoleContext) -> StateTransitionResult
    ) -> StateTransitionResult {
        // Double-check current role permissions before execution
        let currentRole = roleManagementService.currentUserRole
        let userId = roleManagementService.currentUserId
        
        // Validate based on action type
        let hasPermission: Bool
        switch actionType {
        case .driver:
            hasPermission = currentRole == .driver && run.driverId == userId || currentRole == .admin
        case .admin:
            hasPermission = currentRole == .admin
        case .observer:
            hasPermission = true // Observers can view but not modify
        }
        
        guard hasPermission else {
            return .failure(.permissionDenied("Current role \(currentRole.displayName) does not have permission for this action"))
        }
        
        // Execute with role validation
        return roleManagementService.validateAndExecuteAction(
            action,
            on: &run,
            executor: executor
        )
    }
    
    /// Handle permission escalation requests
    /// Implements Requirements 6.5
    func requestPermissionEscalation(
        for operation: RunOperation,
        on run: Run,
        reason: String
    ) async -> PermissionEscalationResult {
        let currentRole = roleManagementService.currentUserRole
        let userId = roleManagementService.currentUserId
        
        // Create escalation request
        let escalationRequest = PermissionEscalationRequest(
            userId: userId,
            currentRole: currentRole,
            requestedOperation: operation,
            runId: run.id,
            reason: reason,
            timestamp: Date()
        )
        
        // Post notification for admin review
        NotificationCenter.default.post(
            name: .permissionEscalationRequested,
            object: nil,
            userInfo: [
                "escalationRequest": escalationRequest,
                "run": run
            ]
        )
        
        print("🚨 Permission escalation requested: \(operation.displayName) by \(currentRole.displayName)")
        
        return .pending(escalationRequest.id)
    }
    
    // MARK: - Private Methods
    
    private func setupUpdateListeners() {
        // Listen for external role update notifications
        NotificationCenter.default.publisher(for: .externalRoleUpdateReceived)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleExternalRoleUpdateNotification(notification)
                }
            }
            .store(in: &cancellables)
        
        // Listen for backend role sync events
        NotificationCenter.default.publisher(for: .backendRoleSyncReceived)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleBackendRoleSyncNotification(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    private func processCurrentUserRoleUpdate(_ update: PendingRoleUpdate) async {
        isProcessingUpdates = true
        
        let previousRole = roleManagementService.currentUserRole
        
        // Update the role in role management service
        roleManagementService.handleExternalRoleChange(
            newRole: update.newRole,
            userId: update.userId,
            familyId: update.familyId,
            activeRuns: update.activeRuns
        )
        
        // Generate permission change summary
        let changeSummary = getPermissionChangeSummary(for: update, previousRole: previousRole)
        
        // Post notification with detailed change information
        NotificationCenter.default.post(
            name: .roleUpdateProcessed,
            object: nil,
            userInfo: [
                "update": update,
                "changeSummary": changeSummary,
                "previousRole": previousRole
            ]
        )
        
        // Remove from pending updates
        pendingRoleUpdates.removeAll { $0.id == update.id }
        
        isProcessingUpdates = false
        
        print("✅ Processed role update for current user: \(changeSummary.changeDescription)")
    }
    
    private func handleExternalRoleUpdateNotification(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let userId = userInfo["userId"] as? String,
              let newRole = userInfo["newRole"] as? FamilyRole,
              let familyId = userInfo["familyId"] as? String else {
            return
        }
        
        let source = userInfo["source"] as? RoleUpdateSource ?? .external
        let activeRuns = userInfo["activeRuns"] as? [Run] ?? []
        
        await processExternalRoleUpdate(
            userId: userId,
            newRole: newRole,
            familyId: familyId,
            source: source,
            activeRuns: activeRuns
        )
    }
    
    private func handleBackendRoleSyncNotification(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let syncData = userInfo["syncData"] as? [String: Any] else {
            return
        }
        
        // Process multiple role updates from backend sync
        for (userId, roleData) in syncData {
            if let roleInfo = roleData as? [String: Any],
               let roleString = roleInfo["role"] as? String,
               let newRole = FamilyRole(rawValue: roleString),
               let familyId = roleInfo["familyId"] as? String {
                
                let activeRuns = roleInfo["activeRuns"] as? [Run] ?? []
                
                await processExternalRoleUpdate(
                    userId: userId,
                    newRole: newRole,
                    familyId: familyId,
                    source: .backendSync,
                    activeRuns: activeRuns
                )
            }
        }
    }
}

// MARK: - Supporting Types

/// Represents a pending role update
/// Implements Requirements 6.5
struct PendingRoleUpdate: Identifiable {
    let id = UUID()
    let userId: String
    let newRole: FamilyRole
    let familyId: String
    let source: RoleUpdateSource
    let timestamp: Date
    let activeRuns: [Run]
}

/// Source of role update
/// Implements Requirements 6.5
enum RoleUpdateSource {
    case adminAssignment(adminId: String, reason: String?)
    case familyManagement(changedBy: String)
    case backendSync
    case external
    
    var description: String {
        switch self {
        case .adminAssignment(let adminId, let reason):
            let reasonText = reason.map { " (\($0))" } ?? ""
            return "Admin assignment by \(adminId)\(reasonText)"
        case .familyManagement(let changedBy):
            return "Family management by \(changedBy)"
        case .backendSync:
            return "Backend synchronization"
        case .external:
            return "External system"
        }
    }
}

// MARK: - Additional Notification Extensions

extension Notification.Name {
    static let backendRoleSyncReceived = Notification.Name("backendRoleSyncReceived")
    static let roleUpdateProcessed = Notification.Name("roleUpdateProcessed")
    static let immediateUIRefreshRequired = Notification.Name("immediateUIRefreshRequired")
    static let runUIConfigurationUpdated = Notification.Name("runUIConfigurationUpdated")
    static let permissionEscalationRequested = Notification.Name("permissionEscalationRequested")
}

// MARK: - Action Type Classification

/// Classifies actions for permission validation
/// Implements Requirements 6.5
enum ActionType {
    case driver
    case admin
    case observer
}

// MARK: - Permission Escalation

/// Represents a request for permission escalation
/// Implements Requirements 6.5
struct PermissionEscalationRequest: Identifiable {
    let id = UUID()
    let userId: String
    let currentRole: FamilyRole
    let requestedOperation: RunOperation
    let runId: String
    let reason: String
    let timestamp: Date
}

/// Result of permission escalation request
/// Implements Requirements 6.5
enum PermissionEscalationResult {
    case granted(newRole: FamilyRole)
    case denied(reason: String)
    case pending(UUID)
}

// MARK: - Enhanced Role Change Coordinator

/// Enhanced coordinator for complex role change scenarios
/// Implements Requirements 6.5
class EnhancedRoleChangeCoordinator {
    
    private let dynamicRoleService: DynamicRoleUpdateService
    private let roleManagementService: RoleManagementService
    
    init(
        dynamicRoleService: DynamicRoleUpdateService,
        roleManagementService: RoleManagementService
    ) {
        self.dynamicRoleService = dynamicRoleService
        self.roleManagementService = roleManagementService
    }
    
    /// Handle complex role transitions with validation
    /// Implements Requirements 6.5
    func handleComplexRoleTransition(
        userId: String,
        fromRole: FamilyRole,
        toRole: FamilyRole,
        familyId: String,
        activeRuns: [Run],
        transitionReason: String
    ) async -> RoleTransitionResult {
        
        // Validate transition is allowed
        guard isRoleTransitionAllowed(from: fromRole, to: toRole) else {
            return .failure("Role transition from \(fromRole.displayName) to \(toRole.displayName) is not allowed")
        }
        
        // Check impact on active runs
        let impactAnalysis = analyzeRoleTransitionImpact(
            userId: userId,
            fromRole: fromRole,
            toRole: toRole,
            activeRuns: activeRuns
        )
        
        // If high impact, require additional validation
        if impactAnalysis.isHighImpact {
            return await handleHighImpactRoleTransition(
                userId: userId,
                toRole: toRole,
                familyId: familyId,
                activeRuns: activeRuns,
                impactAnalysis: impactAnalysis
            )
        }
        
        // Process normal role transition
        await dynamicRoleService.processExternalRoleUpdate(
            userId: userId,
            newRole: toRole,
            familyId: familyId,
            source: .adminAssignment(adminId: "system", reason: transitionReason),
            activeRuns: activeRuns
        )
        
        return .success(impactAnalysis)
    }
    
    private func isRoleTransitionAllowed(from: FamilyRole, to: FamilyRole) -> Bool {
        // Define allowed role transitions
        switch (from, to) {
        case (.observer, .driver), (.observer, .admin):
            return true
        case (.driver, .observer), (.driver, .admin):
            return true
        case (.admin, .observer), (.admin, .driver):
            return true
        case (let fromRole, let toRole) where fromRole == toRole:
            return false // No-op transition
        default:
            return true
        }
    }
    
    private func analyzeRoleTransitionImpact(
        userId: String,
        fromRole: FamilyRole,
        toRole: FamilyRole,
        activeRuns: [Run]
    ) -> RoleTransitionImpact {
        
        let affectedRuns = activeRuns.filter { run in
            run.driverId == userId || run.familyId == roleManagementService.currentFamilyId
        }
        
        let lostPermissions = calculateLostPermissions(from: fromRole, to: toRole, runs: affectedRuns)
        let gainedPermissions = calculateGainedPermissions(from: fromRole, to: toRole, runs: affectedRuns)
        
        let isHighImpact = affectedRuns.count > 2 || 
                          lostPermissions.count > 5 ||
                          affectedRuns.contains { $0.status.isActive && $0.driverId == userId }
        
        return RoleTransitionImpact(
            affectedRuns: affectedRuns,
            lostPermissions: lostPermissions,
            gainedPermissions: gainedPermissions,
            isHighImpact: isHighImpact
        )
    }
    
    private func calculateLostPermissions(from: FamilyRole, to: FamilyRole, runs: [Run]) -> [RunOperation] {
        let fromPermissions = Set(RunOperation.allCases.filter { PermissionValidator.hasPermission(role: from, for: $0) })
        let toPermissions = Set(RunOperation.allCases.filter { PermissionValidator.hasPermission(role: to, for: $0) })
        return Array(fromPermissions.subtracting(toPermissions))
    }
    
    private func calculateGainedPermissions(from: FamilyRole, to: FamilyRole, runs: [Run]) -> [RunOperation] {
        let fromPermissions = Set(RunOperation.allCases.filter { PermissionValidator.hasPermission(role: from, for: $0) })
        let toPermissions = Set(RunOperation.allCases.filter { PermissionValidator.hasPermission(role: to, for: $0) })
        return Array(toPermissions.subtracting(fromPermissions))
    }
    
    private func handleHighImpactRoleTransition(
        userId: String,
        toRole: FamilyRole,
        familyId: String,
        activeRuns: [Run],
        impactAnalysis: RoleTransitionImpact
    ) async -> RoleTransitionResult {
        
        // Post notification for admin approval
        NotificationCenter.default.post(
            name: .highImpactRoleTransitionRequested,
            object: nil,
            userInfo: [
                "userId": userId,
                "toRole": toRole,
                "familyId": familyId,
                "activeRuns": activeRuns,
                "impactAnalysis": impactAnalysis
            ]
        )
        
        print("⚠️ High-impact role transition requires approval: User \(userId) → \(toRole.displayName)")
        
        return .requiresApproval(impactAnalysis)
    }
}

// MARK: - Role Transition Support Types

struct RoleTransitionImpact {
    let affectedRuns: [Run]
    let lostPermissions: [RunOperation]
    let gainedPermissions: [RunOperation]
    let isHighImpact: Bool
    
    var summary: String {
        var parts: [String] = []
        
        if !affectedRuns.isEmpty {
            parts.append("\(affectedRuns.count) run\(affectedRuns.count == 1 ? "" : "s") affected")
        }
        
        if !lostPermissions.isEmpty {
            parts.append("\(lostPermissions.count) permission\(lostPermissions.count == 1 ? "" : "s") lost")
        }
        
        if !gainedPermissions.isEmpty {
            parts.append("\(gainedPermissions.count) permission\(gainedPermissions.count == 1 ? "" : "s") gained")
        }
        
        return parts.joined(separator: ", ")
    }
}

enum RoleTransitionResult {
    case success(RoleTransitionImpact)
    case failure(String)
    case requiresApproval(RoleTransitionImpact)
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let highImpactRoleTransitionRequested = Notification.Name("highImpactRoleTransitionRequested")
    static let actionPermissionDenied = Notification.Name("actionPermissionDenied")
}