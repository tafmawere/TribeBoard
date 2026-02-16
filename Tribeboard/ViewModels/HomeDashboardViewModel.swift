//
//  HomeDashboardViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine

/// ViewModel for Home Dashboard screen
/// Implements HomeDashboardContract with role-based data filtering
/// Requirements 5.1, 5.2, 5.3, 5.4, 5.5
@MainActor
class HomeDashboardViewModel: ObservableObject, HomeDashboardContract {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var error: HomeDashboardError?
    @Published var refreshing: Bool = false
    
    // Contract inputs (computed from internal state)
    var currentUser: User { _currentUser }
    var familyId: String { _currentUser.familyId }
    var nextRun: Run? { _nextRun }
    var activeRun: Run? { _activeRun }
    var todayEvents: [Event] { _todayEvents }
    
    // MARK: - Private Properties
    
    private var _currentUser: User
    private var _nextRun: Run?
    private var _activeRun: Run?
    private var _todayEvents: [Event] = []
    
    private let runEventService: RunEventService
    private var roleContext: RoleContext
    private var cancellables = Set<AnyCancellable>()
    
    // Role-based data filtering
    private var filteredRuns: [Run] = []
    private var availableActions: [HomeDashboardAction] = []
    
    // MARK: - Dependencies
    
    private let firebaseService: MockFirebaseRunService
    private let roleManagementService: RoleManagementService
    private let roleBasedDataFilter: RoleBasedDataFilter
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService, roleManagementService: RoleManagementService, roleBasedDataFilter: RoleBasedDataFilter, runEventService: RunEventService) {
        self.firebaseService = firebaseService
        self.roleManagementService = roleManagementService
        self.roleBasedDataFilter = roleBasedDataFilter
        self.runEventService = runEventService
        
        // Initialize user from debug mode selection or role management service
        // Requirements: 5.2, 5.4
        #if DEBUG
        if AppConfig.isActiveRunOnlyMode {
            self._currentUser = AppConfig.currentDemoUser
            print("🔍 DIAGNOSTIC [Init]: Using AppConfig.currentDemoUser - id: \(AppConfig.currentDemoUser.id), familyId: \(AppConfig.currentDemoUser.familyId), role: \(AppConfig.currentDemoUser.role)")
        } else {
            self._currentUser = User(
                id: roleManagementService.currentUserId,
                displayName: "Demo User",
                role: roleManagementService.currentUserRole,
                familyId: roleManagementService.currentFamilyId
            )
            print("🔍 DIAGNOSTIC [Init]: Using RoleManagementService - id: \(roleManagementService.currentUserId), familyId: \(roleManagementService.currentFamilyId), role: \(roleManagementService.currentUserRole)")
        }
        #else
        self._currentUser = User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        print("🔍 DIAGNOSTIC [Init]: Using RoleManagementService (Release) - id: \(roleManagementService.currentUserId), familyId: \(roleManagementService.currentFamilyId), role: \(roleManagementService.currentUserRole)")
        #endif
        
        self.roleContext = RoleContext(
            userId: _currentUser.id,
            role: _currentUser.role,
            familyId: _currentUser.familyId
        )
        
        setupDataBinding()
        loadInitialData()
    }
    
    /// Update dependencies for dependency injection
    func updateDependencies(firebaseService: MockFirebaseRunService, roleManagementService: RoleManagementService, roleBasedDataFilter: RoleBasedDataFilter, runEventService: RunEventService) {
        // This method allows updating dependencies after initialization
        // In a real app, this would be handled by proper DI container
    }
    
    /// Update role context and reload data (for user switching)
    func updateRoleContext(userId: String, displayName: String, role: FamilyRole, familyId: String) {
        _currentUser = User(
            id: userId,
            displayName: displayName,
            role: role,
            familyId: familyId
        )
        
        // Update internal role context (CRITICAL: must update the stored roleContext)
        self.roleContext = RoleContext(
            userId: userId,
            role: role,
            familyId: familyId
        )
        
        // Force reload with new context
        Task {
            await loadDashboardData()
        }
        
        print("📱 HomeDashboardViewModel updated for user: \(displayName) (familyId: \(familyId))")
    }
    
    /// Load initial data
    func loadData() {
        Task {
            await loadDashboardData()
        }
    }
    
    /// Refresh data
    func refreshData() async {
        await refresh()
    }
    
    // MARK: - HomeDashboardContract Implementation
    
    func openRun(runId: String) {
        // Validate permission to view run details
        guard let run = filteredRuns.first(where: { $0.id == runId }) else {
            error = .runNotFound(runId)
            return
        }
        
        guard PermissionValidator.canPerformOperation(.viewRunDetails, role: roleContext.role, userId: roleContext.userId, run: run) else {
            error = .permissionDenied("Cannot view this run")
            return
        }
        
        // Navigate to run detail (handled by parent coordinator)
        print("Opening run: \(runId)")
    }
    
    func openCalendar() {
        // Navigate to calendar view (handled by parent coordinator)
        print("Opening calendar")
    }
    
    func createRun() {
        // Validate permission to create runs
        guard PermissionValidator.hasPermission(role: roleContext.role, for: .createRun) else {
            error = .permissionDenied("Cannot create runs")
            return
        }
        
        // Navigate to run creation (handled by parent coordinator)
        print("Creating new run")
    }
    
    func openActivity() {
        // Navigate to activity stream (handled by parent coordinator)
        print("Opening activity stream")
    }
    
    // MARK: - Public Interface
    
    /// Refresh dashboard data
    func refresh() async {
        refreshing = true
        defer { refreshing = false }
        
        await loadDashboardData()
    }
    
    /// Get available actions for current user role
    func getAvailableActions() -> [HomeDashboardAction] {
        return availableActions
    }
    
    /// Get role-appropriate runs for display
    func getDisplayRuns() -> [Run] {
        return filteredRuns
    }
    
    /// Get filtered run data for display based on role
    func getFilteredRunData(for run: Run) -> FilteredRunData {
        return RoleBasedDataFilter.filterRunDataForDisplay(run, roleContext: roleContext)
    }
    
    /// Get available actions for a specific run
    func getRunActions(for run: Run) -> RunActionSet {
        return RoleBasedDataFilter.getAvailableActions(for: run, roleContext: roleContext)
    }
    
    /// Check if user can perform a specific action
    func canPerformAction(_ action: HomeDashboardAction) -> Bool {
        return availableActions.contains { actionType in
            switch (action, actionType) {
            case (.openRun(let id1), .openRun(let id2)):
                return id1 == id2
            case (.openCalendar, .openCalendar),
                 (.createRun, .createRun),
                 (.openActivity, .openActivity):
                return true
            default:
                return false
            }
        }
    }
    
    /// Start a run by processing the startRun driver action
    func startRun(runId: String) async throws {
        try await runEventService.processDriverAction(.startRun, runId: runId)
        
        // Reload dashboard to reflect the new active run
        await loadDashboardData()
    }
    
    // MARK: - Private Methods
    
    private func setupDataBinding() {
        // Listen to run events for real-time updates
        runEventService.eventPublisher
            .sink { [weak self] event in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleRunEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Listen to state changes
        runEventService.stateChangePublisher
            .sink { [weak self] stateChange in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleStateChange(stateChange)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadDashboardData()
        }
    }
    
    private func loadDashboardData() async {
        isLoading = true
        error = nil
        
        // Load runs based on user role - Requirements 5.2, 5.3, 5.4
        await loadRoleBasedRuns()
        
        // Load today's events
        await loadTodayEvents()
        
        // Update available actions based on role
        updateAvailableActions()
        
        isLoading = false
    }
    
    /// Load runs filtered by user role - Requirements 5.2, 5.3, 5.4
    private func loadRoleBasedRuns() async {
        // Load all runs from service (this would be a real service call)
        let allRuns = await loadAllRunsFromService()
        
        // DIAGNOSTIC: Log role context
        print("🔍 DIAGNOSTIC: Role context - userId: \(roleContext.userId), role: \(roleContext.role), familyId: \(roleContext.familyId)")
        print("🔍 DIAGNOSTIC: All runs count before filtering: \(allRuns.count)")
        
        // Filter runs based on user role using RoleBasedDataFilter
        filteredRuns = RoleBasedDataFilter.filterRuns(allRuns, for: roleContext)
        
        print("🔍 DIAGNOSTIC: Filtered runs count after filtering: \(filteredRuns.count)")
        for run in filteredRuns {
            print("   - Filtered run: \(run.title) (id: \(run.id), status: \(run.status.displayName), scheduledTime: \(run.scheduledTime))")
        }
        
        // Update next and active runs from filtered results
        updateNextAndActiveRuns()
    }
    
    private func loadAllRunsFromService() async -> [Run] {
        do {
            // Fetch runs for the user's family from Firebase service
            print("📋 Loading runs for familyId: \(roleContext.familyId)")
            let runs = try await firebaseService.listRuns(forFamilyId: roleContext.familyId)
            print("📋 Loaded \(runs.count) runs from service")
            for run in runs {
                print("   - Run: \(run.title) (id: \(run.id), status: \(run.status.displayName))")
            }
            return runs
        } catch {
            print("❌ Error loading runs: \(error.localizedDescription)")
            self.error = .loadingFailed(error.localizedDescription)
            return []
        }
    }
    
    private func loadTodayEvents() async {
        // Load today's events from runs and other sources
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        print("🔍 DIAGNOSTIC: Today's range: \(today) to \(tomorrow)")
        print("🔍 DIAGNOSTIC: Checking \(filteredRuns.count) filtered runs for today's events")
        
        let allEvents: [Event] = filteredRuns.compactMap { run in
            let isToday = run.scheduledTime >= today && run.scheduledTime < tomorrow
            print("   - Run '\(run.title)' scheduled at \(run.scheduledTime): isToday=\(isToday)")
            
            guard isToday else { return nil }
            
            let eventType: EventType
            switch run.status {
            case .scheduled:
                eventType = .runScheduled
            case .activeEnroute, .arrivedAtStop:
                eventType = .runStarted
            case .completed:
                eventType = .runCompleted
            case .cancelled:
                eventType = .runCancelled
            case .paused:
                eventType = run.isDelayed ? .runDelayed : .runStarted
            }
            
            return Event(
                title: run.title,
                time: run.scheduledTime,
                type: eventType,
                runId: run.id
            )
        }
        
        print("🔍 DIAGNOSTIC: Today events before role filter: \(allEvents.count)")
        
        // Filter events based on role using RoleBasedDataFilter
        _todayEvents = RoleBasedDataFilter.filterDashboardData(
            runs: filteredRuns,
            events: allEvents,
            roleContext: roleContext
        ).events
        
        print("🔍 DIAGNOSTIC: Today events after role filter: \(_todayEvents.count)")
        
        // Sort events by time
        _todayEvents.sort { $0.time < $1.time }
    }
    
    private func updateNextAndActiveRuns() {
        // DIAGNOSTIC: Log current time and candidates
        let now = Date()
        print("🔍 DIAGNOSTIC: Current time: \(now)")
        print("🔍 DIAGNOSTIC: Checking for next run from \(filteredRuns.count) filtered runs")
        
        let scheduledFutureRuns = filteredRuns.filter { $0.status == .scheduled && $0.scheduledTime > Date() }
        print("🔍 DIAGNOSTIC: Scheduled future runs count: \(scheduledFutureRuns.count)")
        for run in scheduledFutureRuns {
            print("   - Candidate: \(run.title) scheduled at \(run.scheduledTime) (in \(run.scheduledTime.timeIntervalSince(now)) seconds)")
        }
        
        // Find next scheduled run
        _nextRun = filteredRuns
            .filter { $0.status == .scheduled && $0.scheduledTime > Date() }
            .min { $0.scheduledTime < $1.scheduledTime }
        
        print("🔍 DIAGNOSTIC: Next run selected: \(_nextRun?.title ?? "nil")")
        
        // Find active run
        _activeRun = filteredRuns.first { $0.status.isActive }
        
        print("🔍 DIAGNOSTIC: Active run selected: \(_activeRun?.title ?? "nil")")
    }
    
    /// Update available actions based on user role - Requirements 5.2, 5.3, 5.4
    private func updateAvailableActions() {
        // Use RoleBasedDataFilter to get dashboard actions
        let dashboardData = RoleBasedDataFilter.filterDashboardData(
            runs: filteredRuns,
            events: _todayEvents,
            roleContext: roleContext
        )
        
        availableActions = dashboardData.availableActions
        
        // Add open run actions for accessible runs
        for run in filteredRuns {
            if PermissionValidator.canPerformOperation(.viewRunDetails, role: roleContext.role, userId: roleContext.userId, run: run) {
                availableActions.append(.openRun(runId: run.id))
            }
        }
    }
    
    private func handleRunEvent(_ event: RunEvent) async {
        // Update dashboard when relevant events occur
        if event.runId == _activeRun?.id || event.runId == _nextRun?.id {
            await loadDashboardData()
        }
    }
    
    private func handleStateChange(_ stateChange: RunStateChange) async {
        // Update dashboard when run states change
        if stateChange.runId == _activeRun?.id || stateChange.runId == _nextRun?.id {
            await loadDashboardData()
        }
    }
}

// MARK: - Error Types

enum HomeDashboardError: LocalizedError {
    case loadingFailed(String)
    case runNotFound(String)
    case permissionDenied(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Failed to load dashboard: \(message)"
        case .runNotFound(let runId):
            return "Run not found: \(runId)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}