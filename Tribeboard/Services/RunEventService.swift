//
//  RunEventService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine
import Network

/// Service responsible for real-time synchronization of run events and state changes
/// Implements Firebase listeners for run state changes and event broadcasting to all observers
/// Handles network connectivity and offline queuing as per Requirements 1.5, 7.1, 7.2, 7.3
@MainActor
class RunEventService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = true
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var error: RunEventError?
    
    // MARK: - Private Properties
    
    private let firebaseService: MockFirebaseRunService
    private let offlineSyncService: OfflineSyncService
    private let errorHandlingService: ErrorHandlingService
    private let logger: PrivacyPreservingLogger
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "network.monitor")
    
    // Event broadcasting
    private let eventSubject = PassthroughSubject<RunEvent, Never>()
    private let stateChangeSubject = PassthroughSubject<RunStateChange, Never>()
    
    // Listener management
    private var activeListeners: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    
    // Demo playback controller (strong reference, only used in demo mode)
    private var demoPlaybackController: DemoRunPlaybackController?
    
    // MARK: - Test Support
    
    #if DEBUG
    /// Test-only access to active listeners
    var testActiveListeners: Set<String> {
        return activeListeners
    }
    #endif
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService, errorHandlingService: ErrorHandlingService? = nil, logger: PrivacyPreservingLogger? = nil) {
        self.firebaseService = firebaseService
        self.offlineSyncService = OfflineSyncService(firebaseService: firebaseService)
        self.errorHandlingService = errorHandlingService ?? ErrorHandlingService()
        self.logger = logger ?? PrivacyPreservingLogger()
        
        // DEBUG: Log ObjectIdentifier for retention verification
        #if DEBUG
        print("RunEventService init")
        #endif
        
        setupNetworkMonitoring()
        setupStateChangeMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Set the demo playback controller for automatic playback management
    /// This should be called by DependencyContainer during initialization
    func setDemoPlaybackController(_ controller: DemoRunPlaybackController) {
        self.demoPlaybackController = controller
        
        // DEBUG: Log ObjectIdentifier for retention verification
        #if DEBUG
        print("RunEventService: setDemoPlaybackController ObjectIdentifier=\(ObjectIdentifier(controller))")
        #endif
    }
    
    /// Publisher for real-time run events
    var eventPublisher: AnyPublisher<RunEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for run state changes
    var stateChangePublisher: AnyPublisher<RunStateChange, Never> {
        stateChangeSubject.eraseToAnyPublisher()
    }
    
    /// Start listening to real-time updates for a specific run
    func startListening(to runId: String) {
        guard !activeListeners.contains(runId) else { return }
        
        activeListeners.insert(runId)
        
        if isConnected {
            setupFirebaseListeners(for: runId)
        } else {
            // We'll setup listeners when connectivity is restored
            print("Offline: Will setup listener for \(runId) when connectivity is restored")
        }
    }
    
    /// Stop listening to updates for a specific run
    nonisolated func stopListening(to runId: String) {
        Task { @MainActor in
            activeListeners.remove(runId)
            // Firebase listeners will be cleaned up automatically
        }
    }
    
    /// Broadcast a run event to all observers
    func broadcastEvent(_ event: RunEvent) {
        eventSubject.send(event)
        
        // Also broadcast as state change if it's a state transition
        if let stateBefore = event.stateBefore {
            let stateChange = RunStateChange(
                runId: event.runId,
                fromState: stateBefore,
                toState: event.stateAfter,
                timestamp: event.timestamp,
                actorId: event.actorId,
                eventType: event.type
            )
            stateChangeSubject.send(stateChange)
            
            // Handle demo playback based on state transitions
            handleDemoPlaybackForStateChange(stateChange)
        }
    }
    
    /// Handle demo playback controller based on state changes
    /// Starts playback when run enters .activeEnroute
    /// Stops playback when run enters terminal states
    private func handleDemoPlaybackForStateChange(_ stateChange: RunStateChange) {
        guard AppConfig.isDemoPlaybackEnabled else { return }
        guard let playbackController = demoPlaybackController else { return }
        
        // Start playback when run becomes active
        if stateChange.toState == .activeEnroute && stateChange.fromState != .activeEnroute {
            logger.logInfo(
                message: "Starting demo playback for run entering activeEnroute state",
                context: .stateTransition,
                additionalInfo: ["runId": stateChange.runId]
            )
            playbackController.startPlayback()
        }
        
        // Stop playback when run reaches terminal state
        if stateChange.toState.isTerminal {
            logger.logInfo(
                message: "Stopping demo playback for run entering terminal state",
                context: .stateTransition,
                additionalInfo: ["runId": stateChange.runId, "state": stateChange.toState.displayName]
            )
            playbackController.stopPlayback()
        }
    }
    
    /// Process a driver action with offline support and error handling
    /// Implements Requirements 7.2, 7.3 - queue when offline, sync in order when online
    /// Implements Requirements 9.1, 9.2 - comprehensive error handling with retry
    func processDriverAction(_ action: DriverAction, runId: String, location: CLLocationCoordinate2D? = nil) async throws {
        let operation = NetworkOperation(
            type: .driverAction,
            runId: runId,
            description: "Process driver action: \(action)"
        )
        
        if isConnected {
            // Process immediately when online with error handling
            do {
                try await firebaseService.processDriverAction(action, runId: runId, location: location)
                lastSyncTime = Date()
                logger.logInfo(
                    message: "Driver action processed successfully",
                    context: .stateTransition,
                    additionalInfo: ["action": String(describing: action), "runId": runId]
                )
            } catch {
                logger.logError(
                    error,
                    context: .networkOperation,
                    additionalInfo: ["operation": operation.description, "runId": runId]
                )
                
                // Use error handling service for network errors
                await errorHandlingService.handleNetworkError(error, operation: operation) {
                    try await self.firebaseService.processDriverAction(action, runId: runId, location: location)
                }
                throw error
            }
        } else {
            // Queue the action for offline synchronization - Requirement 7.2
            offlineSyncService.queueDriverAction(action, runId: runId, location: location)
            logger.logInfo(
                message: "Driver action queued for offline sync",
                context: .dataSync,
                additionalInfo: ["action": String(describing: action), "runId": runId]
            )
        }
    }
    
    /// Process an admin action with offline support and error handling
    /// Implements Requirements 7.2, 7.3 - queue when offline, sync in order when online
    /// Implements Requirements 9.1, 9.2 - comprehensive error handling with retry
    func processAdminAction(_ action: AdminAction, runId: String) async throws {
        let operation = NetworkOperation(
            type: .adminAction,
            runId: runId,
            description: "Process admin action: \(action)"
        )
        
        if isConnected {
            // Process immediately when online with error handling
            do {
                try await firebaseService.processAdminAction(action, runId: runId)
                lastSyncTime = Date()
                logger.logInfo(
                    message: "Admin action processed successfully",
                    context: .stateTransition,
                    additionalInfo: ["action": String(describing: action), "runId": runId]
                )
            } catch {
                logger.logError(
                    error,
                    context: .networkOperation,
                    additionalInfo: ["operation": operation.description, "runId": runId]
                )
                
                // Use error handling service for network errors
                await errorHandlingService.handleNetworkError(error, operation: operation) {
                    try await self.firebaseService.processAdminAction(action, runId: runId)
                }
                throw error
            }
        } else {
            // Queue the action for offline synchronization - Requirement 7.2
            offlineSyncService.queueAdminAction(action, runId: runId)
            logger.logInfo(
                message: "Admin action queued for offline sync",
                context: .dataSync,
                additionalInfo: ["action": String(describing: action), "runId": runId]
            )
        }
    }
    
    /// Update driver location with offline support
    /// Implements Requirements 7.2, 7.3 - queue when offline, sync in order when online
    func updateDriverLocation(runId: String, location: CLLocationCoordinate2D) async throws {
        if isConnected {
            // Update immediately when online
            try await firebaseService.updateDriverLocation(runId: runId, location: location)
            lastSyncTime = Date()
        } else {
            // Queue the location update for offline synchronization - Requirement 7.2
            offlineSyncService.queueLocationUpdate(runId: runId, location: location)
            print("Queued location update for run \(runId) - will sync when online")
        }
    }
    
    /// Force synchronization of offline queue
    /// Implements Requirements 7.3, 7.4 - sync in correct order and handle conflicts
    func forceSynchronization() async {
        guard isConnected else { 
            print("Cannot sync: device is offline")
            return 
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("Starting offline queue synchronization...")
        await offlineSyncService.synchronizeQueue()
        lastSyncTime = Date()
        print("Offline queue synchronization completed")
    }
    
    /// Get the number of queued actions for a specific run
    func getQueuedActionsCount(for runId: String) -> Int {
        return offlineSyncService.getQueuedActions(for: runId).count
    }
    
    /// Check if there are pending actions for a specific run
    func hasPendingActions(for runId: String) -> Bool {
        return offlineSyncService.hasPendingActions(for: runId)
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                
                // If we just came back online, sync offline queue - Requirement 7.3
                if !wasConnected && path.status == .satisfied {
                    print("Network connectivity restored - starting synchronization")
                    await self?.forceSynchronization()
                    await self?.restoreActiveListeners()
                } else if wasConnected && path.status != .satisfied {
                    print("Network connectivity lost - entering offline mode")
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupStateChangeMonitoring() {
        // Subscribe to state changes to manage demo playback
        stateChangePublisher
            .sink { [weak self] stateChange in
                self?.handleDemoPlaybackForStateChange(stateChange)
            }
            .store(in: &cancellables)
    }
    
    private func setupFirebaseListeners(for runId: String) {
        // Listen to run state changes
        firebaseService.listenToRun(runId: runId)
        
        // Listen to run events
        firebaseService.listenToRunEvents(runId: runId)
        
        // Subscribe to Firebase service updates and broadcast them
        firebaseService.$currentRun
            .compactMap { $0 }
            .filter { $0.id == runId }
            .sink { [weak self] run in
                // Create a state change event if this is a state transition
                // This would normally come from Firebase, but we're simulating it
                let stateChange = RunStateChange(
                    runId: run.id,
                    fromState: run.status, // In real implementation, we'd track previous state
                    toState: run.status,
                    timestamp: Date(),
                    actorId: "system",
                    eventType: .locationUpdated
                )
                self?.stateChangeSubject.send(stateChange)
            }
            .store(in: &cancellables)
        
        firebaseService.$runEvents
            .sink { [weak self] events in
                // Broadcast new events
                for event in events {
                    if event.runId == runId {
                        self?.broadcastEvent(event)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func queueAction(_ action: QueuedAction) {
        // This method is no longer needed as we use OfflineSyncService
        // Keeping for backward compatibility but it's deprecated
    }
    
    private func processQueuedAction(_ action: QueuedAction) async throws {
        // This method is no longer needed as we use OfflineSyncService
        // Keeping for backward compatibility but it's deprecated
    }
    
    private func restoreActiveListeners() async {
        for runId in activeListeners {
            setupFirebaseListeners(for: runId)
        }
    }
    
    deinit {
        networkMonitor.cancel()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

struct RunStateChange {
    let runId: String
    let fromState: RunStatus
    let toState: RunStatus
    let timestamp: Date
    let actorId: String
    let eventType: RunEventType
}

enum QueuedAction {
    // Deprecated: Use OfflineSyncService instead
    case driverAction(action: DriverAction, runId: String, location: CLLocationCoordinate2D?)
    case adminAction(action: AdminAction, runId: String)
    case startListener(runId: String)
}

enum RunEventError: LocalizedError {
    case networkUnavailable
    case syncFailed(Error)
    case listenerSetupFailed(String)
    case invalidEvent(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .syncFailed(let error):
            return "Synchronization failed: \(error.localizedDescription)"
        case .listenerSetupFailed(let runId):
            return "Failed to setup listener for run: \(runId)"
        case .invalidEvent(let message):
            return "Invalid event: \(message)"
        }
    }
}

// MARK: - Core Location Extension

import CoreLocation

extension CLLocationCoordinate2D {
    var isValid: Bool {
        return CLLocationCoordinate2DIsValid(self)
    }
}