//
//  RoleBasedDataFilter.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation

/// Service for filtering data based on user roles
/// Implements Requirements 5.2, 5.3, 5.4 - role-based data filtering and display
class RoleBasedDataFilter {
    
    // MARK: - Run Filtering
    
    /// Filter runs based on user role and permissions
    /// Requirements 5.2, 5.3, 5.4
    static func filterRuns(_ runs: [Run], for roleContext: RoleContext) -> [Run] {
        switch roleContext.role {
        case .driver:
            // Drivers see runs assigned to them with execution actions
            return filterDriverRuns(runs, userId: roleContext.userId, familyId: roleContext.familyId)
            
        case .observer:
            // Observers see family runs with monitoring capabilities
            return filterObserverRuns(runs, familyId: roleContext.familyId)
            
        case .admin:
            // Admins see all runs with administrative actions
            return filterAdminRuns(runs, familyId: roleContext.familyId)
        }
    }
    
    /// Filter runs for driver role - shows runs assigned to them
    /// Requirement 5.2
    private static func filterDriverRuns(_ runs: [Run], userId: String, familyId: String) -> [Run] {
        return runs.filter { run in
            // Driver sees runs assigned to them in their family
            run.driverId == userId && run.familyId == familyId
        }
    }
    
    /// Filter runs for observer role - shows family runs for monitoring
    /// Requirement 5.3
    private static func filterObserverRuns(_ runs: [Run], familyId: String) -> [Run] {
        return runs.filter { run in
            // Observer sees all runs in their family
            run.familyId == familyId
        }
    }
    
    /// Filter runs for admin role - shows all runs with administrative capabilities
    /// Requirement 5.4
    private static func filterAdminRuns(_ runs: [Run], familyId: String) -> [Run] {
        return runs.filter { run in
            // Admin sees all runs in their family (could be extended to multiple families)
            run.familyId == familyId
        }
    }
    
    // MARK: - Action Filtering
    
    /// Get role-appropriate actions for a specific run
    /// Requirements 5.2, 5.3, 5.4
    static func getAvailableActions(for run: Run, roleContext: RoleContext) -> RunActionSet {
        var actions = RunActionSet()
        
        // Get driver actions if user has driver permissions
        if roleContext.role == .driver || roleContext.role == .admin {
            actions.driverActions = RunStateMachine.getAvailableDriverActions(for: run, roleContext: roleContext)
        }
        
        // Get admin actions if user has admin permissions
        if roleContext.role == .admin {
            actions.adminActions = RunStateMachine.getAvailableAdminActions(for: run, roleContext: roleContext)
        }
        
        // Get observer actions (available to all roles)
        actions.observerActions = getObserverActions(for: run, roleContext: roleContext)
        
        return actions
    }
    
    /// Get observer-specific actions
    private static func getObserverActions(for run: Run, roleContext: RoleContext) -> [ObserverAction] {
        var actions: [ObserverAction] = []
        
        // All roles can view run details if they have access to the run
        if PermissionValidator.canPerformOperation(.viewRunDetails, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.viewDetails)
        }
        
        // All roles can view timeline if they have access
        if PermissionValidator.canPerformOperation(.viewRunTimeline, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.viewTimeline)
        }
        
        // Contact driver during active runs
        if run.status.isActive && 
           PermissionValidator.canPerformOperation(.contactDriver, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.contactDriver)
        }
        
        // Acknowledge updates
        if PermissionValidator.canPerformOperation(.acknowledgeUpdate, role: roleContext.role, userId: roleContext.userId, run: run) {
            actions.append(.acknowledgeUpdate)
        }
        
        // Share run status (available for all active runs)
        if run.status.isActive {
            actions.append(.shareRunStatus)
        }
        
        return actions
    }
    
    // MARK: - Data Display Filtering
    
    /// Filter run data for display based on role permissions
    /// Requirements 5.2, 5.3, 5.4
    static func filterRunDataForDisplay(_ run: Run, roleContext: RoleContext) -> FilteredRunData {
        var filteredData = FilteredRunData(run: run)
        
        switch roleContext.role {
        case .driver:
            filteredData = filterDriverDisplayData(run, userId: roleContext.userId)
            
        case .observer:
            filteredData = filterObserverDisplayData(run)
            
        case .admin:
            filteredData = filterAdminDisplayData(run)
        }
        
        return filteredData
    }
    
    /// Filter display data for driver role
    /// Requirement 5.2 - show role-appropriate data and actions
    private static func filterDriverDisplayData(_ run: Run, userId: String) -> FilteredRunData {
        var data = FilteredRunData(run: run)
        
        // Drivers see full run details for their assigned runs
        if run.driverId == userId {
            data.showFullDetails = true
            data.showDriverLocation = true
            data.showPassengerDetails = true
            data.showStopDetails = true
            data.showExecutionActions = true
        } else {
            // Limited view for runs not assigned to them
            data.showFullDetails = false
            data.showDriverLocation = false
            data.showPassengerDetails = false
            data.showStopDetails = false
            data.showExecutionActions = false
        }
        
        return data
    }
    
    /// Filter display data for observer role
    /// Requirement 5.3 - show monitoring capabilities
    private static func filterObserverDisplayData(_ run: Run) -> FilteredRunData {
        var data = FilteredRunData(run: run)
        
        // Observers see monitoring information but no execution actions
        data.showFullDetails = true
        data.showDriverLocation = true
        data.showPassengerDetails = true
        data.showStopDetails = true
        data.showExecutionActions = false
        data.showMonitoringInfo = true
        
        return data
    }
    
    /// Filter display data for admin role
    /// Requirement 5.4 - show administrative actions
    private static func filterAdminDisplayData(_ run: Run) -> FilteredRunData {
        var data = FilteredRunData(run: run)
        
        // Admins see everything including administrative actions
        data.showFullDetails = true
        data.showDriverLocation = true
        data.showPassengerDetails = true
        data.showStopDetails = true
        data.showExecutionActions = true
        data.showMonitoringInfo = true
        data.showAdminActions = true
        
        return data
    }
    
    // MARK: - Event Filtering
    
    /// Filter timeline events based on role permissions
    /// Requirements 5.2, 5.3, 5.4
    static func filterTimelineEvents(_ events: [RunEvent], for roleContext: RoleContext) -> [RunEvent] {
        switch roleContext.role {
        case .driver:
            // Drivers see all events for their runs
            return events
            
        case .observer:
            // Observers see public events (no sensitive driver actions)
            return events.filter { event in
                !isSensitiveDriverEvent(event)
            }
            
        case .admin:
            // Admins see all events
            return events
        }
    }
    
    /// Check if an event contains sensitive driver information
    private static func isSensitiveDriverEvent(_ event: RunEvent) -> Bool {
        // For now, all events are considered public
        // This could be extended to filter sensitive location or personal information
        return false
    }
    
    // MARK: - Dashboard Data Filtering
    
    /// Filter dashboard data based on role
    /// Requirements 5.2, 5.3, 5.4
    static func filterDashboardData(
        runs: [Run],
        events: [Event],
        roleContext: RoleContext
    ) -> DashboardData {
        let filteredRuns = filterRuns(runs, for: roleContext)
        let filteredEvents = filterDashboardEvents(events, for: roleContext)
        
        return DashboardData(
            runs: filteredRuns,
            events: filteredEvents,
            nextRun: findNextRun(in: filteredRuns),
            activeRun: findActiveRun(in: filteredRuns),
            availableActions: getDashboardActions(for: roleContext)
        )
    }
    
    /// Filter dashboard events based on role
    private static func filterDashboardEvents(_ events: [Event], for roleContext: RoleContext) -> [Event] {
        // All roles see the same dashboard events for now
        // This could be extended to filter based on run access permissions
        return events
    }
    
    /// Find the next scheduled run
    private static func findNextRun(in runs: [Run]) -> Run? {
        return runs
            .filter { $0.status == .scheduled && $0.scheduledTime > Date() }
            .min { $0.scheduledTime < $1.scheduledTime }
    }
    
    /// Find the currently active run
    private static func findActiveRun(in runs: [Run]) -> Run? {
        return runs.first { $0.status.isActive }
    }
    
    /// Get available dashboard actions for role
    private static func getDashboardActions(for roleContext: RoleContext) -> [HomeDashboardAction] {
        var actions: [HomeDashboardAction] = []
        
        // All roles can view calendar and activity
        actions.append(.openCalendar)
        actions.append(.openActivity)
        
        // Check create run permission
        if PermissionValidator.hasPermission(role: roleContext.role, for: .createRun) {
            actions.append(.createRun)
        }
        
        return actions
    }
}

// MARK: - Supporting Types

/// Set of actions available for a run based on role
struct RunActionSet {
    var driverActions: [DriverAction] = []
    var adminActions: [AdminAction] = []
    var observerActions: [ObserverAction] = []
    
    var hasAnyActions: Bool {
        return !driverActions.isEmpty || !adminActions.isEmpty || !observerActions.isEmpty
    }
}

/// Observer-specific actions
enum ObserverAction {
    case viewDetails
    case viewTimeline
    case contactDriver
    case acknowledgeUpdate
    case shareRunStatus
    
    var displayName: String {
        switch self {
        case .viewDetails: return "View Details"
        case .viewTimeline: return "View Timeline"
        case .contactDriver: return "Contact Driver"
        case .acknowledgeUpdate: return "Acknowledge Update"
        case .shareRunStatus: return "Share Run Status"
        }
    }
}

/// Filtered run data for display
struct FilteredRunData {
    let run: Run
    var showFullDetails: Bool = false
    var showDriverLocation: Bool = false
    var showPassengerDetails: Bool = false
    var showStopDetails: Bool = false
    var showExecutionActions: Bool = false
    var showMonitoringInfo: Bool = false
    var showAdminActions: Bool = false
    
    init(run: Run) {
        self.run = run
    }
}

/// Dashboard data filtered by role
struct DashboardData {
    let runs: [Run]
    let events: [Event]
    let nextRun: Run?
    let activeRun: Run?
    let availableActions: [HomeDashboardAction]
}