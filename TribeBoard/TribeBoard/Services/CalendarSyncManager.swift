import Foundation
import SwiftData
import EventKit
import Combine

/// Comprehensive sync manager for coordinating calendar data sources
@MainActor
class CalendarSyncManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0.0
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingOperationsCount: Int = 0
    @Published var syncError: Error?
    
    // MARK: - Types
    
    enum SyncStatus {
        case idle
        case syncing
        case conflict
        case error
        case offline
        
        var displayName: String {
            switch self {
            case .idle:
                return "Up to date"
            case .syncing:
                return "Syncing..."
            case .conflict:
                return "Conflict detected"
            case .error:
                return "Sync error"
            case .offline:
                return "Offline"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let modelContext: ModelContext
    private let eventKitManager: EventKitManager
    private let calendarSyncService: CalendarSyncService
    private let networkMonitor: NetworkMonitor
    
    private var syncQueue: [SyncOperation] = []
    private var isProcessingQueue: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        eventKitManager: EventKitManager,
        calendarSyncService: CalendarSyncService,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.modelContext = modelContext
        self.eventKitManager = eventKitManager
        self.calendarSyncService = calendarSyncService
        self.networkMonitor = networkMonitor
        
        setupNetworkMonitoring()
        setupAutoSync()
        
        print("🔄 CalendarSyncManager: Initialized")
    }
    
    deinit {
        retryTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Public Sync Methods
    
    /// Queues an event for sync (handles offline scenarios)
    func queueEventForSync(_ event: CalendarEvent, operation: SyncOperationType, userId: UUID) {
        let syncOperation = SyncOperation(
            id: UUID(),
            type: operation,
            eventId: event.id,
            timestamp: Date(),
            userId: userId,
            retryCount: 0,
            status: .pending
        )
        
        // Add to queue
        syncQueue.append(syncOperation)
        syncQueue.sort { $0.priority > $1.priority }
        
        // Update pending count
        pendingOperationsCount = syncQueue.count
        
        // Mark event as needing sync
        event.needsSync = true
        event.needsEventKitSync = true
        
        // Save to persistence
        do {
            try modelContext.save()
            try persistSyncQueue()
        } catch {
            print("❌ CalendarSyncManager: Failed to save sync queue: \(error)")
        }
        
        print("📝 CalendarSyncManager: Queued \(operation.displayName) for event '\(event.title)'")
        
        // Process queue if online
        if networkMonitor.isConnected {
            Task {
                await processNextSyncOperation()
            }
        }
    }
    
    /// Performs full bidirectional sync for a user
    func performFullSync(for userId: UUID, dateRange: DateInterval? = nil) async throws {
        print("🔄 CalendarSyncManager: Starting full sync for user: \(userId)")
        
        guard networkMonitor.isConnected else {
            syncStatus = .offline
            throw CalendarSyncError.networkUnavailable
        }
        
        isSyncing = true
        syncStatus = .syncing
        syncProgress = 0.0
        syncError = nil
        
        defer {
            isSyncing = false
            syncProgress = 0.0
        }
        
        do {
            // Step 1: Process pending queue operations (25% of progress)
            syncProgress = 0.1
            try await processAllPendingOperations(for: userId)
            syncProgress = 0.25
            
            // Step 2: Sync pending events to Apple Calendar (50% of progress)
            try await calendarSyncService.syncPendingEventsToAppleCalendar(userId: userId)
            syncProgress = 0.5
            
            // Step 3: Sync events from Apple Calendar (75% of progress)
            let syncDateRange = dateRange ?? getDefaultSyncDateRange()
            try await calendarSyncService.syncEventsFromAppleCalendar(userId: userId, dateRange: syncDateRange)
            syncProgress = 0.75
            
            // Step 4: Detect and resolve conflicts (100% of progress)
            try await detectAndResolveConflicts(for: userId, in: syncDateRange)
            syncProgress = 1.0
            
            // Update sync status
            lastSyncDate = Date()
            syncStatus = .idle
            
            // Update sync configuration
            if let config = try getSyncConfiguration(for: userId) {
                config.recordSuccessfulSync()
                try modelContext.save()
            }
            
            print("✅ CalendarSyncManager: Full sync completed successfully")
            
        } catch {
            syncStatus = .error
            syncError = error
            
            // Record error in configuration
            if let config = try getSyncConfiguration(for: userId) {
                config.recordSyncError(error.localizedDescription)
                try modelContext.save()
            }
            
            print("❌ CalendarSyncManager: Full sync failed: \(error)")
            throw error
        }
    }
    
    /// Detects conflicts between local and Apple Calendar events
    func detectAndResolveConflicts(for userId: UUID, in dateRange: DateInterval) async throws {
        print("🔍 CalendarSyncManager: Detecting conflicts for user: \(userId)")
        
        guard let config = try getSyncConfiguration(for: userId) else {
            throw CalendarSyncError.syncConfigurationNotFound
        }
        
        // Get local events
        let localEvents = try getLocalEvents(for: userId, in: dateRange)
        
        // Get Apple Calendar events
        let appleEvents = try await eventKitManager.fetchEventsFromAppleCalendar(for: dateRange)
        
        var conflicts: [SyncConflict] = []
        
        // Check for conflicts
        for localEvent in localEvents {
            if let eventKitId = localEvent.eventKitIdentifier,
               let appleEvent = appleEvents.first(where: { $0.eventIdentifier == eventKitId }) {
                
                // Compare modification dates
                let localModified = localEvent.lastModified
                let appleModified = appleEvent.lastModified ?? Date.distantPast
                
                // Check if there's a significant difference (more than 1 second to account for precision)
                if abs(localModified.timeIntervalSince(appleModified)) > 1.0 {
                    let conflict = SyncConflict(
                        localEvent: localEvent,
                        appleEvent: appleEvent,
                        conflictType: .modificationConflict,
                        detectedAt: Date()
                    )
                    conflicts.append(conflict)
                }
            }
        }
        
        if !conflicts.isEmpty {
            print("⚠️ CalendarSyncManager: Found \(conflicts.count) conflicts")
            syncStatus = .conflict
            
            // Resolve conflicts based on configuration
            for conflict in conflicts {
                try await resolveConflict(conflict, strategy: config.syncConflictResolution, userId: userId)
            }
        }
        
        print("✅ CalendarSyncManager: Conflict detection completed")
    }
    
    // MARK: - Offline Management
    
    /// Processes all pending sync operations
    func processAllPendingOperations(for userId: UUID) async throws {
        print("📤 CalendarSyncManager: Processing pending operations for user: \(userId)")
        
        guard networkMonitor.isConnected else {
            print("📱 CalendarSyncManager: Offline - operations will be processed when connection is restored")
            return
        }
        
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        // Load persisted queue
        try loadPersistedSyncQueue()
        
        // Filter operations for this user
        let userOperations = syncQueue.filter { $0.userId == userId }
        
        guard !userOperations.isEmpty else {
            print("ℹ️ CalendarSyncManager: No pending operations for user")
            return
        }
        
        print("📊 CalendarSyncManager: Processing \(userOperations.count) pending operations")
        
        var processedCount = 0
        var failedOperations: [SyncOperation] = []
        
        for operation in userOperations {
            do {
                try await processSyncOperation(operation)
                
                // Remove from queue on success
                if let index = syncQueue.firstIndex(where: { $0.id == operation.id }) {
                    syncQueue.remove(at: index)
                }
                
                processedCount += 1
                
            } catch {
                print("❌ CalendarSyncManager: Failed to process operation \(operation.id): \(error)")
                
                // Increment retry count
                operation.retryCount += 1
                operation.lastAttempt = Date()
                
                // Check if we should retry or give up
                if operation.retryCount >= operation.maxRetries {
                    print("⚠️ CalendarSyncManager: Operation \(operation.id) exceeded max retries, removing from queue")
                    if let index = syncQueue.firstIndex(where: { $0.id == operation.id }) {
                        syncQueue.remove(at: index)
                    }
                } else {
                    failedOperations.append(operation)
                }
            }
        }
        
        // Update pending count
        pendingOperationsCount = syncQueue.count
        
        // Persist updated queue
        try persistSyncQueue()
        
        print("✅ CalendarSyncManager: Processed \(processedCount) operations, \(failedOperations.count) failed")
        
        // Schedule retry for failed operations
        if !failedOperations.isEmpty {
            scheduleRetry()
        }
    }
    
    /// Processes the next sync operation in the queue
    func processNextSyncOperation() async {
        guard !isProcessingQueue && !syncQueue.isEmpty && networkMonitor.isConnected else {
            return
        }
        
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        // Get highest priority operation
        guard let operation = syncQueue.first else {
            return
        }
        
        do {
            try await processSyncOperation(operation)
            
            // Remove from queue on success
            syncQueue.removeFirst()
            pendingOperationsCount = syncQueue.count
            
            try persistSyncQueue()
            
        } catch {
            print("❌ CalendarSyncManager: Failed to process operation: \(error)")
            
            // Increment retry count
            operation.retryCount += 1
            operation.lastAttempt = Date()
            
            // Check if we should retry or give up
            if operation.retryCount >= operation.maxRetries {
                syncQueue.removeFirst()
                pendingOperationsCount = syncQueue.count
            } else {
                // Move to end of queue for retry
                let failedOperation = syncQueue.removeFirst()
                syncQueue.append(failedOperation)
                scheduleRetry()
            }
            
            try persistSyncQueue()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        // Monitor connection status changes
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    await self?.handleNetworkStatusChange(isConnected: isConnected)
                }
            }
            .store(in: &cancellables)
        
        // Monitor connection type changes (for sync strategy adjustments)
        networkMonitor.$connectionType
            .sink { [weak self] connectionType in
                Task { @MainActor in
                    await self?.handleConnectionTypeChange(connectionType)
                }
            }
            .store(in: &cancellables)
        
        // Monitor expensive connection status (cellular data)
        networkMonitor.$isExpensive
            .sink { [weak self] isExpensive in
                Task { @MainActor in
                    await self?.handleExpensiveConnectionChange(isExpensive)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkStatusChange(isConnected: Bool) async {
        if isConnected {
            print("🌐 CalendarSyncManager: Network connection restored")
            syncStatus = .idle
            
            // Cancel any pending retry timers
            retryTimer?.invalidate()
            
            // Wait a moment for connection to stabilize
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Process pending operations when connection is restored
            if !syncQueue.isEmpty {
                print("🔄 CalendarSyncManager: Processing \(syncQueue.count) queued operations after reconnection")
                await processNextSyncOperation()
            }
        } else {
            print("📱 CalendarSyncManager: Network connection lost")
            syncStatus = .offline
            
            // Cancel any ongoing sync operations
            if isSyncing {
                print("⏸️ CalendarSyncManager: Pausing sync operations due to network loss")
                // Note: Actual cancellation would depend on the specific sync operation
            }
        }
    }
    
    private func handleConnectionTypeChange(_ connectionType: NetworkMonitor.ConnectionType) async {
        print("📶 CalendarSyncManager: Connection type changed to \(connectionType.displayName)")
        
        // Adjust sync behavior based on connection type
        switch connectionType {
        case .wifi, .ethernet:
            // Full sync capabilities on fast connections
            break
        case .cellular:
            // Consider limiting sync operations on cellular
            print("📱 CalendarSyncManager: On cellular connection - sync operations may be limited")
        case .unknown:
            // Conservative approach for unknown connections
            break
        }
    }
    
    private func handleExpensiveConnectionChange(_ isExpensive: Bool) async {
        if isExpensive {
            print("💰 CalendarSyncManager: Connection is expensive (cellular data)")
            // Could implement logic to pause non-critical sync operations
            // or ask user for permission to sync on cellular
        } else {
            print("🆓 CalendarSyncManager: Connection is not expensive")
        }
    }
    
    private func setupAutoSync() {
        // Set up periodic sync check
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkAndPerformAutoSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAndPerformAutoSync() async {
        guard networkMonitor.isConnected && !isSyncing else {
            return
        }
        
        // Check if any user needs auto sync
        do {
            let descriptor = FetchDescriptor<SyncConfiguration>()
            let configs = try modelContext.fetch(descriptor)
            
            for config in configs where config.autoSyncEnabled && config.isSyncOverdue {
                print("🔄 CalendarSyncManager: Auto sync triggered for user: \(config.userId)")
                try await performFullSync(for: config.userId)
            }
        } catch {
            print("❌ CalendarSyncManager: Auto sync check failed: \(error)")
        }
    }
    
    private func processSyncOperation(_ operation: SyncOperation) async throws {
        print("⚙️ CalendarSyncManager: Processing \(operation.type.displayName) operation for event: \(operation.eventId ?? UUID())")
        
        // Get the event
        guard let eventId = operation.eventId,
              let event = try getEvent(by: eventId) else {
            throw CalendarSyncError.dataInconsistency("Event not found: \(operation.eventId?.uuidString ?? "nil")")
        }
        
        // Process based on operation type
        switch operation.type {
        case .create:
            try await calendarSyncService.syncEventToAppleCalendar(event, userId: operation.userId)
            
        case .update:
            try await calendarSyncService.updateEventInAppleCalendar(event, userId: operation.userId)
            
        case .delete:
            try await calendarSyncService.deleteEventFromAppleCalendar(event, userId: operation.userId)
            
        case .sync:
            // Full sync operation - handle differently
            print("ℹ️ CalendarSyncManager: Full sync operations not handled in single operation processing")
        }
        
        print("✅ CalendarSyncManager: Successfully processed \(operation.type.displayName) operation")
    }
    
    private func resolveConflict(_ conflict: SyncConflict, strategy: SyncConfiguration.ConflictResolutionStrategy, userId: UUID) async throws {
        print("🔧 CalendarSyncManager: Resolving conflict using \(strategy.displayName) strategy")
        
        switch strategy {
        case .lastModifiedWins:
            let localModified = conflict.localEvent.lastModified
            let appleModified = conflict.appleEvent.lastModified ?? Date.distantPast
            
            if localModified > appleModified {
                // Local wins - update Apple Calendar
                try await eventKitManager.updateEventInAppleCalendar(conflict.localEvent)
            } else {
                // Apple wins - update local event
                conflict.localEvent.updateFromEKEvent(conflict.appleEvent, modifiedBy: userId)
                try modelContext.save()
            }
            
        case .tribeBoardWins:
            // Always keep TribeBoard version
            try await eventKitManager.updateEventInAppleCalendar(conflict.localEvent)
            
        case .appleCalendarWins:
            // Always keep Apple Calendar version
            conflict.localEvent.updateFromEKEvent(conflict.appleEvent, modifiedBy: userId)
            try modelContext.save()
            
        case .askUser:
            // For now, fall back to last modified wins
            // In a full implementation, this would trigger a UI prompt
            print("⚠️ CalendarSyncManager: User resolution not implemented, using last modified wins")
            try await resolveConflict(conflict, strategy: .lastModifiedWins, userId: userId)
        }
        
        print("✅ CalendarSyncManager: Conflict resolved")
    }
    
    private func scheduleRetry() {
        retryTimer?.invalidate()
        
        // Get the operation with the highest retry count to determine backoff
        let maxRetryCount = getMaxRetryCount()
        
        // Exponential backoff with jitter: base * (2^retryCount) + random(0, base)
        let baseDelay: TimeInterval = 30 // 30 seconds base
        let maxDelay: TimeInterval = 15 * 60 // 15 minutes max
        let jitter = TimeInterval.random(in: 0...baseDelay)
        
        let exponentialDelay = baseDelay * pow(2, Double(maxRetryCount))
        let nextRetryDelay = min(exponentialDelay + jitter, maxDelay)
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: nextRetryDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.processNextSyncOperation()
            }
        }
        
        print("⏰ CalendarSyncManager: Scheduled retry in \(Int(nextRetryDelay)) seconds (attempt \(maxRetryCount + 1))")
    }
    
    private func getMaxRetryCount() -> Int {
        return syncQueue.map { $0.retryCount }.max() ?? 0
    }
    
    private func getDefaultSyncDateRange() -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let end = calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        return DateInterval(start: start, end: end)
    }
    
    // MARK: - Data Access Helpers
    
    private func getSyncConfiguration(for userId: UUID) throws -> SyncConfiguration? {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let configs = try modelContext.fetch(descriptor)
        return configs.first { $0.userId == userId }
    }
    
    private func getEvent(by id: UUID) throws -> CalendarEvent? {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let events = try modelContext.fetch(descriptor)
        return events.first { $0.id == id }
    }
    
    private func getLocalEvents(for userId: UUID, in dateRange: DateInterval) throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        return allEvents.filter { event in
            !event.isDeleted &&
            (event.createdBy == userId || event.privacyLevel == .familyShared) &&
            event.startDate >= dateRange.start &&
            event.startDate <= dateRange.end
        }
    }
    
    // MARK: - Queue Persistence
    
    private func persistSyncQueue() throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(syncQueue)
            UserDefaults.standard.set(data, forKey: "CalendarSyncQueue")
            
            // Also persist a backup with timestamp
            let backupKey = "CalendarSyncQueue_Backup_\(Int(Date().timeIntervalSince1970))"
            UserDefaults.standard.set(data, forKey: backupKey)
            
            // Clean up old backups (keep only last 3)
            cleanupOldBackups()
            
        } catch {
            print("❌ CalendarSyncManager: Failed to persist sync queue: \(error)")
            throw error
        }
    }
    
    private func loadPersistedSyncQueue() throws {
        guard let data = UserDefaults.standard.data(forKey: "CalendarSyncQueue") else {
            print("ℹ️ CalendarSyncManager: No persisted sync queue found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            syncQueue = try decoder.decode([SyncOperation].self, from: data)
            pendingOperationsCount = syncQueue.count
            
            // Validate and clean up the loaded queue
            validateAndCleanupQueue()
            
            print("✅ CalendarSyncManager: Loaded \(syncQueue.count) operations from persistence")
            
        } catch {
            print("❌ CalendarSyncManager: Failed to load persisted sync queue: \(error)")
            
            // Try to recover from backup
            if tryRecoverFromBackup() {
                print("✅ CalendarSyncManager: Recovered sync queue from backup")
            } else {
                print("⚠️ CalendarSyncManager: Could not recover sync queue, starting fresh")
                syncQueue = []
                pendingOperationsCount = 0
            }
        }
    }
    
    private func validateAndCleanupQueue() {
        let originalCount = syncQueue.count
        
        // Remove operations that are too old (older than 7 days)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        syncQueue.removeAll { $0.createdAt < cutoffDate }
        
        // Remove operations that have exceeded maximum retries
        syncQueue.removeAll { $0.retryCount >= $0.maxRetries }
        
        // Sort by priority
        syncQueue.sort { $0.priority > $1.priority }
        
        pendingOperationsCount = syncQueue.count
        
        if syncQueue.count != originalCount {
            print("🧹 CalendarSyncManager: Cleaned up sync queue: \(originalCount) → \(syncQueue.count) operations")
            try? persistSyncQueue()
        }
    }
    
    private func tryRecoverFromBackup() -> Bool {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Find backup keys
        let backupKeys = allKeys.filter { $0.hasPrefix("CalendarSyncQueue_Backup_") }
            .sorted(by: >)  // Most recent first
        
        for backupKey in backupKeys.prefix(3) {  // Try last 3 backups
            guard let data = userDefaults.data(forKey: backupKey) else { continue }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                syncQueue = try decoder.decode([SyncOperation].self, from: data)
                pendingOperationsCount = syncQueue.count
                
                // Validate recovered data
                validateAndCleanupQueue()
                
                return true
            } catch {
                print("⚠️ CalendarSyncManager: Backup \(backupKey) is also corrupted: \(error)")
                continue
            }
        }
        
        return false
    }
    
    private func cleanupOldBackups() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        let backupKeys = allKeys.filter { $0.hasPrefix("CalendarSyncQueue_Backup_") }
            .sorted(by: >)  // Most recent first
        
        // Remove all but the 3 most recent backups
        for oldBackupKey in backupKeys.dropFirst(3) {
            userDefaults.removeObject(forKey: oldBackupKey)
        }
    }
    
    /// Clears all persisted sync data (use with caution)
    func clearPersistedSyncData() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove main queue
        userDefaults.removeObject(forKey: "CalendarSyncQueue")
        
        // Remove all backups
        let backupKeys = allKeys.filter { $0.hasPrefix("CalendarSyncQueue_Backup_") }
        for backupKey in backupKeys {
            userDefaults.removeObject(forKey: backupKey)
        }
        
        // Clear in-memory queue
        syncQueue.removeAll()
        pendingOperationsCount = 0
        
        print("🧹 CalendarSyncManager: Cleared all persisted sync data")
    }
}

// MARK: - Supporting Types

// Note: SyncOperation and SyncOperationType are now defined in CalendarService.swift

/// Extension to SyncOperation for CalendarSyncManager-specific functionality
extension SyncOperation {
    var operationType: SyncOperationType { type }
    var createdAt: Date { timestamp }
    var priority: Int { type.priority }
    let maxRetries: Int = 5
    var lastAttempt: Date? {
        // This would need to be tracked separately or added to the canonical struct
        return nil
    }
}

/// Represents a sync conflict between local and remote events
struct SyncConflict {
    let localEvent: CalendarEvent
    let appleEvent: EKEvent
    let conflictType: ConflictType
    let detectedAt: Date
    
    enum ConflictType {
        case modificationConflict
        case deletionConflict
        case creationConflict
    }
}

// MARK: - Error Extensions

extension CalendarSyncError {
    static let networkUnavailable = CalendarSyncError.dataInconsistency("Network connection not available")
}