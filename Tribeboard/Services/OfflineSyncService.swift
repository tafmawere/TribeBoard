//
//  OfflineSyncService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine
import CoreLocation

/// Service responsible for offline synchronization logic
/// Queues state changes when offline, synchronizes in correct order when connectivity restored
/// Resolves conflicts by deferring to backend state as per Requirements 7.2, 7.3, 7.4
@MainActor
class OfflineSyncService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var queuedActionsCount: Int = 0
    @Published var isSyncing: Bool = false
    @Published var lastSyncAttempt: Date?
    @Published var syncErrors: [SyncError] = []
    
    // MARK: - Private Properties
    
    private var actionQueue: [QueuedSyncAction] = [] {
        didSet {
            queuedActionsCount = actionQueue.count
        }
    }
    
    private let firebaseService: MockFirebaseRunService
    private let maxRetryAttempts = 3
    private let syncRetryDelay: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService) {
        self.firebaseService = firebaseService
        loadPersistedQueue()
    }
    
    // MARK: - Public Interface
    
    /// Queue a driver action for offline synchronization
    func queueDriverAction(_ action: DriverAction, runId: String, location: CLLocationCoordinate2D? = nil) {
        let queuedAction = QueuedSyncAction(
            id: UUID().uuidString,
            type: .driverAction(action, runId, location),
            timestamp: Date(),
            retryCount: 0
        )
        
        actionQueue.append(queuedAction)
        persistQueue()
    }
    
    /// Queue an admin action for offline synchronization
    func queueAdminAction(_ action: AdminAction, runId: String) {
        let queuedAction = QueuedSyncAction(
            id: UUID().uuidString,
            type: .adminAction(action, runId),
            timestamp: Date(),
            retryCount: 0
        )
        
        actionQueue.append(queuedAction)
        persistQueue()
    }
    
    /// Queue a location update for offline synchronization
    func queueLocationUpdate(runId: String, location: CLLocationCoordinate2D) {
        let queuedAction = QueuedSyncAction(
            id: UUID().uuidString,
            type: .locationUpdate(runId, location),
            timestamp: Date(),
            retryCount: 0
        )
        
        actionQueue.append(queuedAction)
        persistQueue()
    }
    
    /// Synchronize all queued actions when connectivity is restored
    /// Processes actions in chronological order and handles conflicts by deferring to backend state
    func synchronizeQueue() async {
        guard !isSyncing && !actionQueue.isEmpty else { return }
        
        isSyncing = true
        lastSyncAttempt = Date()
        
        defer {
            isSyncing = false
            persistQueue()
        }
        
        // Process actions in chronological order (FIFO) - Requirement 7.3
        let actionsToSync = actionQueue.sorted { $0.timestamp < $1.timestamp }
        var successfulActions: [String] = []
        var failedActions: [String] = []
        
        for action in actionsToSync {
            do {
                // Add small delay between actions to prevent overwhelming the backend
                if !successfulActions.isEmpty {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
                try await processQueuedAction(action)
                successfulActions.append(action.id)
                
                // Remove successful action from queue immediately
                actionQueue.removeAll { $0.id == action.id }
                
            } catch {
                // Handle sync failure - Requirement 7.4 (conflict resolution)
                await handleSyncFailure(action, error: error)
                
                // If this was a conflict error, mark as failed but continue with other actions
                if isConflictError(error) {
                    failedActions.append(action.id)
                    actionQueue.removeAll { $0.id == action.id }
                }
            }
        }
        
        // Clear any resolved errors
        if !successfulActions.isEmpty {
            syncErrors.removeAll { error in
                successfulActions.contains(error.actionId)
            }
        }
        
        // Log synchronization results
        print("Sync completed: \(successfulActions.count) successful, \(failedActions.count) failed due to conflicts")
    }
    
    /// Clear all queued actions (use with caution)
    func clearQueue() {
        actionQueue.removeAll()
        syncErrors.removeAll()
        persistQueue()
    }
    
    /// Get queued actions for a specific run
    func getQueuedActions(for runId: String) -> [QueuedSyncAction] {
        return actionQueue.filter { action in
            switch action.type {
            case .driverAction(_, let id, _), .adminAction(_, let id), .locationUpdate(let id, _):
                return id == runId
            }
        }
    }
    
    /// Get synchronization statistics for monitoring
    func getSyncStatistics() -> SyncStatistics {
        let totalActions = actionQueue.count
        let oldestAction = actionQueue.min(by: { $0.timestamp < $1.timestamp })
        let newestAction = actionQueue.max(by: { $0.timestamp < $1.timestamp })
        
        return SyncStatistics(
            totalQueuedActions: totalActions,
            errorCount: syncErrors.count,
            oldestActionAge: oldestAction?.age,
            newestActionAge: newestAction?.age,
            lastSyncAttempt: lastSyncAttempt
        )
    }
    
    /// Remove actions older than specified time interval to prevent queue bloat
    func cleanupOldActions(olderThan timeInterval: TimeInterval = 86400) { // 24 hours default
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        let initialCount = actionQueue.count
        
        actionQueue.removeAll { action in
            action.timestamp < cutoffDate && action.retryCount >= maxRetryAttempts
        }
        
        let removedCount = initialCount - actionQueue.count
        if removedCount > 0 {
            print("Cleaned up \(removedCount) old failed actions from sync queue")
            persistQueue()
        }
    }
    
    /// Check if there are pending actions for a specific run
    func hasPendingActions(for runId: String) -> Bool {
        return !getQueuedActions(for: runId).isEmpty
    }
    
    /// Get detailed queue information for debugging
    func getQueueDetails() -> [QueueActionDetail] {
        return actionQueue.map { action in
            QueueActionDetail(
                id: action.id,
                type: action.type.description,
                timestamp: action.timestamp,
                retryCount: action.retryCount,
                age: action.age
            )
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Private Methods
    
    private func processQueuedAction(_ action: QueuedSyncAction) async throws {
        switch action.type {
        case .driverAction(let driverAction, let runId, let location):
            try await firebaseService.processDriverAction(driverAction, runId: runId, location: location)
            
        case .adminAction(let adminAction, let runId):
            try await firebaseService.processAdminAction(adminAction, runId: runId)
            
        case .locationUpdate(let runId, let location):
            try await firebaseService.updateDriverLocation(runId: runId, location: location)
        }
    }
    
    private func handleSyncFailure(_ action: QueuedSyncAction, error: Error) async {
        var updatedAction = action
        updatedAction.retryCount += 1
        
        if updatedAction.retryCount >= maxRetryAttempts {
            // Max retries reached, add to error list and remove from queue
            let syncError = SyncError(
                actionId: action.id,
                actionType: action.type.description,
                error: error,
                timestamp: Date(),
                retryCount: updatedAction.retryCount
            )
            
            syncErrors.append(syncError)
            actionQueue.removeAll { $0.id == action.id }
            
        } else {
            // Update retry count and keep in queue
            if let index = actionQueue.firstIndex(where: { $0.id == action.id }) {
                actionQueue[index] = updatedAction
            }
            
            // Wait before next retry attempt
            try? await Task.sleep(nanoseconds: UInt64(syncRetryDelay * 1_000_000_000))
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflicts by deferring to backend state - Requirement 7.4
    func resolveConflicts(localRun: Run, backendRun: Run) -> Run {
        // Backend state always takes precedence as per Requirements 7.4
        var resolvedRun = backendRun
        
        // However, preserve any local changes that haven't been synced yet
        // This implements intelligent conflict resolution while maintaining backend authority
        
        // If local run has newer location data and it's not synced, preserve it temporarily
        if let localLocation = localRun.lastLocation,
           let localLocationTime = localRun.lastLocationUpdatedAt,
           let backendLocationTime = backendRun.lastLocationUpdatedAt,
           localLocationTime > backendLocationTime {
            
            // Check if we have a pending location update for this run
            let hasPendingLocationUpdate = actionQueue.contains { action in
                if case .locationUpdate(let runId, _) = action.type {
                    return runId == localRun.id
                }
                return false
            }
            
            if hasPendingLocationUpdate {
                resolvedRun.lastLocation = localLocation
                resolvedRun.lastLocationUpdatedAt = localLocationTime
            }
        }
        
        // Preserve any local passenger status changes that are queued for sync
        for queuedAction in actionQueue {
            if case .driverAction(let driverAction, let runId, _) = queuedAction.type,
               runId == localRun.id {
                switch driverAction {
                case .confirmPickup(let passengerId):
                    // If we have a queued pickup confirmation, preserve the local passenger status
                    if let localPassengerIndex = localRun.passengers.firstIndex(where: { $0.id == passengerId }),
                       let resolvedPassengerIndex = resolvedRun.passengers.firstIndex(where: { $0.id == passengerId }),
                       localRun.passengers[localPassengerIndex].status == .onboard {
                        resolvedRun.passengers[resolvedPassengerIndex].status = .onboard
                    }
                    
                case .confirmDropoff(let passengerId):
                    // If we have a queued dropoff confirmation, preserve the local passenger status
                    if let localPassengerIndex = localRun.passengers.firstIndex(where: { $0.id == passengerId }),
                       let resolvedPassengerIndex = resolvedRun.passengers.firstIndex(where: { $0.id == passengerId }),
                       localRun.passengers[localPassengerIndex].status == .droppedOff {
                        resolvedRun.passengers[resolvedPassengerIndex].status = .droppedOff
                    }
                    
                default:
                    break
                }
            }
        }
        
        return resolvedRun
    }
    
    /// Check if an error represents a conflict that should be resolved by deferring to backend
    private func isConflictError(_ error: Error) -> Bool {
        if let firebaseError = error as? FirebaseError {
            switch firebaseError {
            case .invalidTransition, .stateTransitionFailed:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    // MARK: - Persistence
    
    private func persistQueue() {
        do {
            let data = try JSONEncoder().encode(actionQueue)
            UserDefaults.standard.set(data, forKey: "offline_sync_queue")
        } catch {
            print("Failed to persist offline sync queue: \(error)")
        }
    }
    
    private func loadPersistedQueue() {
        guard let data = UserDefaults.standard.data(forKey: "offline_sync_queue") else { return }
        
        do {
            actionQueue = try JSONDecoder().decode([QueuedSyncAction].self, from: data)
        } catch {
            print("Failed to load persisted offline sync queue: \(error)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: "offline_sync_queue")
        }
    }
}

// MARK: - Supporting Types

struct QueuedSyncAction: Codable, Identifiable {
    let id: String
    let type: SyncActionType
    let timestamp: Date
    var retryCount: Int
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

enum SyncActionType: Codable {
    case driverAction(DriverAction, String, CLLocationCoordinate2D?)
    case adminAction(AdminAction, String)
    case locationUpdate(String, CLLocationCoordinate2D)
    
    var description: String {
        switch self {
        case .driverAction(let action, _, _):
            return "Driver Action: \(action)"
        case .adminAction(let action, _):
            return "Admin Action: \(action)"
        case .locationUpdate(_, _):
            return "Location Update"
        }
    }
}

struct SyncError: Identifiable {
    let id = UUID()
    let actionId: String
    let actionType: String
    let error: Error
    let timestamp: Date
    let retryCount: Int
    
    var errorDescription: String {
        error.localizedDescription
    }
}

struct SyncStatistics {
    let totalQueuedActions: Int
    let errorCount: Int
    let oldestActionAge: TimeInterval?
    let newestActionAge: TimeInterval?
    let lastSyncAttempt: Date?
    
    var hasOldActions: Bool {
        guard let oldestAge = oldestActionAge else { return false }
        return oldestAge > 3600 // More than 1 hour old
    }
}

struct QueueActionDetail {
    let id: String
    let type: String
    let timestamp: Date
    let retryCount: Int
    let age: TimeInterval
    
    var isStale: Bool {
        age > 1800 // More than 30 minutes old
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: @retroactive Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}