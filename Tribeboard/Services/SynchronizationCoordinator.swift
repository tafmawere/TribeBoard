//
//  SynchronizationCoordinator.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine
import CoreLocation

/// Coordinates real-time synchronization and offline queue management
/// Provides a unified interface for run state management with offline support
/// Implements conflict resolution by deferring to backend state as per Requirements 7.2, 7.3, 7.4
@MainActor
class SynchronizationCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isOnline: Bool = true
    @Published var isSyncing: Bool = false
    @Published var pendingActionsCount: Int = 0
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    
    private let runEventService: RunEventService
    private let offlineSyncService: OfflineSyncService
    private let coreDataService: CoreDataService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Test Support
    
    #if DEBUG
    /// Test-only access to run event service for controlling network state
    var testRunEventService: RunEventService {
        return runEventService
    }
    #endif
    
    // MARK: - Initialization
    
    init(
        runEventService: RunEventService,
        offlineSyncService: OfflineSyncService,
        coreDataService: CoreDataService
    ) {
        self.runEventService = runEventService
        self.offlineSyncService = offlineSyncService
        self.coreDataService = coreDataService
        
        setupBindings()
    }
    
    convenience init() {
        let firebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: firebaseService)
        let offlineSyncService = OfflineSyncService(firebaseService: firebaseService)
        let coreDataService = CoreDataService()
        
        self.init(
            runEventService: runEventService,
            offlineSyncService: offlineSyncService,
            coreDataService: coreDataService
        )
    }
    
    // MARK: - Public Interface
    
    /// Start monitoring a run for real-time updates
    func startMonitoring(runId: String) {
        runEventService.startListening(to: runId)
    }
    
    /// Stop monitoring a run
    func stopMonitoring(runId: String) {
        runEventService.stopListening(to: runId)
    }
    
    /// Process a driver action with full offline support and conflict resolution
    /// Implements Requirements 7.2, 7.3, 7.4
    func processDriverAction(_ action: DriverAction, runId: String, location: CLLocationCoordinate2D? = nil) async throws {
        // Always update local cache optimistically first - Requirement 7.2
        if var localRun = try? await coreDataService.fetchRun(runId: runId) {
            let result = RunStateMachine.processDriverAction(action, for: &localRun)
            
            switch result {
            case .success:
                // Save optimistic update to local cache
                try await coreDataService.saveRun(localRun)
                
                // Process through event service (handles online/offline automatically)
                try await runEventService.processDriverAction(action, runId: runId, location: location)
                
            case .failure(let error):
                throw SyncCoordinatorError.stateTransitionFailed(error.localizedDescription)
            }
        } else {
            // No local cache, process directly (will queue if offline)
            try await runEventService.processDriverAction(action, runId: runId, location: location)
        }
    }
    
    /// Process an admin action with full offline support
    /// Implements Requirements 7.2, 7.3, 7.4
    func processAdminAction(_ action: AdminAction, runId: String) async throws {
        // Always update local cache optimistically first - Requirement 7.2
        if var localRun = try? await coreDataService.fetchRun(runId: runId) {
            let result = RunStateMachine.processAdminAction(action, for: &localRun)
            
            switch result {
            case .success:
                // Save optimistic update to local cache
                try await coreDataService.saveRun(localRun)
                
                // Process through event service (handles online/offline automatically)
                try await runEventService.processAdminAction(action, runId: runId)
                
            case .failure(let error):
                throw SyncCoordinatorError.stateTransitionFailed(error.localizedDescription)
            }
        } else {
            // No local cache, process directly (will queue if offline)
            try await runEventService.processAdminAction(action, runId: runId)
        }
    }
    
    /// Update driver location with offline support
    /// Implements Requirements 7.2, 7.3
    func updateDriverLocation(runId: String, location: CLLocationCoordinate2D) async throws {
        // Update local cache immediately - Requirement 7.2
        if var localRun = try? await coreDataService.fetchRun(runId: runId) {
            localRun.lastLocation = GeoPoint(latitude: location.latitude, longitude: location.longitude)
            localRun.lastLocationUpdatedAt = Date()
            try await coreDataService.saveRun(localRun)
        }
        
        // Process through event service (will queue if offline)
        try await runEventService.updateDriverLocation(runId: runId, location: location)
    }
    
    /// Force synchronization of all offline data
    /// Implements Requirements 7.3, 7.4 - synchronize in correct order and resolve conflicts
    func forceSynchronization() async {
        syncStatus = .syncing
        isSyncing = true
        
        defer {
            syncStatus = .idle
            isSyncing = false
        }
        
        // Step 1: Sync offline queue in chronological order - Requirement 7.3
        await runEventService.forceSynchronization()
        
        // Step 2: Resolve any conflicts between local and backend data - Requirement 7.4
        await resolveDataConflicts()
        
        // Step 3: Validate data consistency
        await validateDataConsistency()
        
        lastSyncTime = Date()
        syncStatus = .completed
    }
    
    /// Get synchronization status for a specific run
    func getSyncStatus(for runId: String) -> RunSyncStatus {
        let pendingActions = runEventService.getQueuedActionsCount(for: runId)
        let hasPendingActions = runEventService.hasPendingActions(for: runId)
        
        if !isOnline && hasPendingActions {
            return .offline(pendingActions: pendingActions)
        } else if hasPendingActions {
            return .syncing(pendingActions: pendingActions)
        } else {
            return .synced
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor online status
        runEventService.$isConnected
            .assign(to: \.isOnline, on: self)
            .store(in: &cancellables)
        
        // Monitor sync status
        runEventService.$isSyncing
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
        
        // Monitor pending actions count
        offlineSyncService.$queuedActionsCount
            .assign(to: \.pendingActionsCount, on: self)
            .store(in: &cancellables)
        
        // Monitor last sync time
        runEventService.$lastSyncTime
            .assign(to: \.lastSyncTime, on: self)
            .store(in: &cancellables)
        
        // Listen to run events and update local cache
        runEventService.eventPublisher
            .sink { [weak self] event in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleRunEvent(event)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRunEvent(_ event: RunEvent) async {
        // Update local cache when we receive run events
        do {
            if var localRun = try? await coreDataService.fetchRun(runId: event.runId) {
                // Apply the event to the local run
                localRun.status = event.stateAfter
                
                if let location = event.location {
                    localRun.lastLocation = location
                    localRun.lastLocationUpdatedAt = event.timestamp
                }
                
                try await coreDataService.saveRun(localRun)
            }
        } catch {
            print("Failed to update local cache for event: \(error)")
        }
    }
    
    private func resolveDataConflicts() async {
        // Get all runs from local cache
        do {
            let localRuns = try await coreDataService.fetchAllRuns()
            
            for localRun in localRuns {
                // Only resolve conflicts for active runs to avoid unnecessary backend calls
                guard localRun.status.isActive || localRun.status == .scheduled else {
                    continue
                }
                
                // Fetch latest from backend if online - Requirement 7.4
                if isOnline {
                    do {
                        let backendRun = try await MockFirebaseRunService().fetchRun(runId: localRun.id)
                        
                        // Resolve conflicts using offline sync service - defers to backend state
                        let resolvedRun = offlineSyncService.resolveConflicts(
                            localRun: localRun,
                            backendRun: backendRun
                        )
                        
                        // Update local cache with resolved data only if there were actual changes
                        if !areRunsEqual(localRun, resolvedRun) {
                            try await coreDataService.saveRun(resolvedRun)
                            print("Resolved conflict for run \(localRun.id): backend state applied")
                        }
                        
                    } catch {
                        // Backend fetch failed, keep local data and log the issue
                        print("Failed to fetch backend data for conflict resolution: \(error)")
                        // Don't throw - we want to continue with other runs
                    }
                }
            }
        } catch {
            print("Failed to resolve data conflicts: \(error)")
        }
    }
    
    /// Validate that local data is consistent after synchronization
    private func validateDataConsistency() async {
        do {
            let localRuns = try await coreDataService.fetchAllRuns()
            
            for run in localRuns {
                // Validate run state consistency
                if run.status.isTerminal && run.currentStopIndex < run.stops.count - 1 {
                    print("Warning: Run \(run.id) is in terminal state but not all stops completed")
                }
                
                // Validate passenger status consistency
                for passenger in run.passengers {
                    if passenger.status == .onboard && run.status == .completed {
                        print("Warning: Run \(run.id) completed but passenger \(passenger.id) still onboard")
                    }
                }
            }
        } catch {
            print("Failed to validate data consistency: \(error)")
        }
    }
    
    /// Helper to compare runs for equality (ignoring timestamps)
    private func areRunsEqual(_ run1: Run, _ run2: Run) -> Bool {
        return run1.id == run2.id &&
               run1.status == run2.status &&
               run1.currentStopIndex == run2.currentStopIndex &&
               run1.driverId == run2.driverId &&
               run1.isDelayed == run2.isDelayed &&
               run1.passengers.map(\.status) == run2.passengers.map(\.status)
    }
}

// MARK: - Supporting Types

enum SyncStatus {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Synced"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

enum RunSyncStatus {
    case synced
    case syncing(pendingActions: Int)
    case offline(pendingActions: Int)
    
    var description: String {
        switch self {
        case .synced:
            return "Synced"
        case .syncing(let count):
            return "Syncing (\(count) pending)"
        case .offline(let count):
            return "Offline (\(count) queued)"
        }
    }
    
    var isFullySynced: Bool {
        if case .synced = self {
            return true
        }
        return false
    }
}

enum SyncCoordinatorError: LocalizedError {
    case stateTransitionFailed(String)
    case conflictResolutionFailed(String)
    case cacheUpdateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .stateTransitionFailed(let message):
            return "State transition failed: \(message)"
        case .conflictResolutionFailed(let message):
            return "Conflict resolution failed: \(message)"
        case .cacheUpdateFailed(let message):
            return "Cache update failed: \(message)"
        }
    }
}