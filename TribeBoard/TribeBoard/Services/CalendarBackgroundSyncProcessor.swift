import Foundation
import UIKit
import SwiftData
import BackgroundTasks

/// Centralized service for processing all calendar background operations
/// This service coordinates background sync, cleanup, and maintenance tasks
@MainActor
class CalendarBackgroundSyncProcessor: ObservableObject {
    
    // MARK: - Background Processing Configuration
    
    private struct BackgroundConfig {
        static let backgroundTaskIdentifier = "com.tribeboard.calendar.background-sync"
        static let maxBackgroundExecutionTime: TimeInterval = 25 // iOS allows ~30 seconds
        static let batchSize = 20
        static let maxRetryAttempts = 3
        static let retryDelaySeconds: TimeInterval = 2
    }
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var lastBackgroundSync: Date?
    @Published var backgroundSyncStats = BackgroundSyncStats()
    
    // MARK: - Private Properties
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var processingQueue: [SyncOperation] = []
    private var isRegistered = false
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let calendarSyncService: CalendarSyncService
    private let networkMonitor: NetworkMonitor
    private let cacheService: CalendarEventCacheService
    private weak var calendarService: CalendarService?
    
    // MARK: - Background Task Coordination
    
    private var backgroundTaskCoordinator: BackgroundTaskCoordinator?
    private var backupService: CalendarBackupService?
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        calendarSyncService: CalendarSyncService,
        networkMonitor: NetworkMonitor,
        cacheService: CalendarEventCacheService,
        calendarService: CalendarService? = nil
    ) {
        self.modelContext = modelContext
        self.calendarSyncService = calendarSyncService
        self.networkMonitor = networkMonitor
        self.cacheService = cacheService
        self.calendarService = calendarService
        
        print("🔄 CalendarBackgroundSyncProcessor: Initialized as centralized background coordinator")
        
        // Initialize background task coordination
        self.backgroundTaskCoordinator = BackgroundTaskCoordinator()
        
        // Register for background processing
        registerBackgroundTasks()
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Setup periodic maintenance
        setupPeriodicMaintenance()
    }
    
    /// Sets the calendar service for centralized coordination
    func setCalendarService(_ calendarService: CalendarService) {
        self.calendarService = calendarService
    }
    
    /// Sets the backup service for background backup coordination
    func setBackupService(_ backupService: CalendarBackupService) {
        self.backupService = backupService
    }
    
    // MARK: - Public Background Sync Interface
    
    /// Schedules background sync processing
    func scheduleBackgroundSync() {
        guard !isProcessing else {
            print("⏳ CalendarBackgroundSyncProcessor: Already processing, skipping schedule")
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: BackgroundConfig.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ CalendarBackgroundSyncProcessor: Background sync scheduled")
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Failed to schedule background sync: \(error.localizedDescription)")
        }
    }
    
    /// Processes pending sync operations immediately (foreground)
    func processPendingSyncOperations() async {
        guard !isProcessing else {
            print("⏳ CalendarBackgroundSyncProcessor: Already processing")
            return
        }
        
        print("🔄 CalendarBackgroundSyncProcessor: Starting foreground sync processing")
        
        await performSyncProcessing(isBackground: false)
    }
    
    /// Forces a complete background sync for a user
    func forceBackgroundSync(for userId: UUID) async {
        print("🔄 CalendarBackgroundSyncProcessor: Forcing background sync for user: \(userId)")
        
        // Start background task
        beginBackgroundTask()
        
        defer {
            endBackgroundTask()
        }
        
        do {
            // Get pending operations for user
            let pendingOperations = try await getPendingSyncOperations(for: userId)
            
            if pendingOperations.isEmpty {
                print("ℹ️ CalendarBackgroundSyncProcessor: No pending operations for user")
                return
            }
            
            // Process operations
            await processSyncOperations(pendingOperations, isBackground: true)
            
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Failed to force background sync: \(error.localizedDescription)")
            backgroundSyncStats.recordError()
        }
    }
    
    /// Gets current background sync status
    func getBackgroundSyncStatus() -> BackgroundSyncStatus {
        return BackgroundSyncStatus(
            isProcessing: isProcessing,
            progress: processingProgress,
            lastSync: lastBackgroundSync,
            pendingOperations: processingQueue.count,
            stats: backgroundSyncStats
        )
    }
    
    /// Clears all pending background operations
    func clearPendingOperations() {
        processingQueue.removeAll()
        print("🗑️ CalendarBackgroundSyncProcessor: Cleared all pending operations")
    }
    
    // MARK: - Private Background Processing Implementation
    
    private func registerBackgroundTasks() {
        guard !isRegistered else { return }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundConfig.backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }
        
        isRegistered = true
        print("✅ CalendarBackgroundSyncProcessor: Registered for background tasks")
    }
    
    private func handleBackgroundSync(task: BGAppRefreshTask) async {
        print("🔄 CalendarBackgroundSyncProcessor: Background sync task started")
        
        // Schedule next background sync
        scheduleBackgroundSync()
        
        // Set expiration handler
        task.expirationHandler = {
            Task { @MainActor in
                print("⏰ CalendarBackgroundSyncProcessor: Background task expired")
                self.isProcessing = false
                self.processingProgress = 0
                task.setTaskCompleted(success: false)
            }
        }
        
        // Perform background sync
        await performSyncProcessing(isBackground: true)
        
        // Mark task as completed
        task.setTaskCompleted(success: true)
        print("✅ CalendarBackgroundSyncProcessor: Background sync task completed")
    }
    
    private func performSyncProcessing(isBackground: Bool) async {
        guard networkMonitor.isConnected else {
            print("📱 CalendarBackgroundSyncProcessor: No network connection, skipping sync")
            return
        }
        
        isProcessing = true
        processingProgress = 0
        
        let startTime = Date()
        
        defer {
            isProcessing = false
            processingProgress = 0
            lastBackgroundSync = Date()
        }
        
        do {
            // Get all pending sync operations
            let pendingOperations = try await getAllPendingSyncOperations()
            
            if pendingOperations.isEmpty {
                print("ℹ️ CalendarBackgroundSyncProcessor: No pending sync operations")
                return
            }
            
            print("🔄 CalendarBackgroundSyncProcessor: Processing \(pendingOperations.count) pending operations")
            
            // Process operations in batches
            await processSyncOperations(pendingOperations, isBackground: isBackground)
            
            // Update statistics
            let executionTime = Date().timeIntervalSince(startTime)
            backgroundSyncStats.recordSuccessfulSync(
                operationsProcessed: pendingOperations.count,
                executionTime: executionTime
            )
            
            // Invalidate relevant caches
            invalidateAffectedCaches(for: pendingOperations)
            
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Sync processing failed: \(error.localizedDescription)")
            backgroundSyncStats.recordError()
        }
    }
    
    private func processSyncOperations(_ operations: [SyncOperation], isBackground: Bool) async {
        let totalOperations = operations.count
        var processedOperations = 0
        
        // Process in batches to avoid timeout
        let batches = operations.chunked(into: BackgroundConfig.batchSize)
        
        for batch in batches {
            // Check if we should continue (especially important for background)
            if isBackground && shouldStopBackgroundProcessing() {
                print("⏰ CalendarBackgroundSyncProcessor: Stopping due to time constraints")
                break
            }
            
            await processBatch(batch)
            
            processedOperations += batch.count
            processingProgress = Double(processedOperations) / Double(totalOperations)
            
            print("📊 CalendarBackgroundSyncProcessor: Processed \(processedOperations)/\(totalOperations) operations")
        }
    }
    
    private func processBatch(_ operations: [SyncOperation]) async {
        await withTaskGroup(of: Void.self) { group in
            for operation in operations {
                group.addTask {
                    await self.processSingleOperation(operation)
                }
            }
        }
    }
    
    private func processSingleOperation(_ operation: SyncOperation) async {
        var retryCount = 0
        
        while retryCount < BackgroundConfig.maxRetryAttempts {
            do {
                // Look up the event by ID
                guard let eventId = operation.eventId,
                      let event = try await getEvent(by: eventId) else {
                    print("⚠️ CalendarBackgroundSyncProcessor: Event not found for operation \(operation.id)")
                    return
                }
                
                switch operation.type {
                case .create:
                    try await calendarSyncService.syncEventToAppleCalendar(event, userId: operation.userId)
                case .update:
                    try await calendarSyncService.updateEventInAppleCalendar(event, userId: operation.userId)
                case .delete:
                    try await calendarSyncService.deleteEventFromAppleCalendar(event, userId: operation.userId)
                case .sync:
                    // Full sync operation - handle differently
                    print("ℹ️ CalendarBackgroundSyncProcessor: Full sync operations not handled in single operation processing")
                    return
                }
                
                // Mark operation as completed
                try await markOperationCompleted(operation)
                
                print("✅ CalendarBackgroundSyncProcessor: Completed operation \(operation.id)")
                return
                
            } catch {
                retryCount += 1
                print("⚠️ CalendarBackgroundSyncProcessor: Operation \(operation.id) failed (attempt \(retryCount)): \(error.localizedDescription)")
                
                if retryCount < BackgroundConfig.maxRetryAttempts {
                    // Wait before retry
                    try? await Task.sleep(nanoseconds: UInt64(BackgroundConfig.retryDelaySeconds * 1_000_000_000))
                } else {
                    // Mark as failed after max retries
                    try? await markOperationFailed(operation, error: error)
                }
            }
        }
    }
    
    private func getAllPendingSyncOperations() async throws -> [SyncOperation] {
        // Query for events that need sync
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { event in
                event.needsEventKitSync && !event.isDeleted
            }
        )
        
        let events = try modelContext.fetch(descriptor)
        
        // Convert to sync operations
        return events.compactMap { (event: CalendarEvent) -> SyncOperation? in
            guard let operationType = determineSyncOperationType(for: event) else {
                return nil
            }
            
            return SyncOperation(
                id: UUID(),
                type: operationType,
                eventId: event.id,
                timestamp: Date(),
                userId: event.createdBy,
                retryCount: 0,
                status: .pending
            )
        }
    }
    
    private func getPendingSyncOperations(for userId: UUID) async throws -> [SyncOperation] {
        let allOperations = try await getAllPendingSyncOperations()
        return allOperations.filter { $0.userId == userId }
    }
    
    private func determineSyncOperationType(for event: CalendarEvent) -> SyncOperationType? {
        if event.eventKitIdentifier == nil {
            return .create
        } else if event.isDeleted {
            return .delete
        } else {
            return .update
        }
    }
    
    private func markOperationCompleted(_ operation: SyncOperation) async throws {
        // Update the event to mark sync as completed
        guard let eventId = operation.eventId,
              let event = try await getEvent(by: eventId) else {
            print("⚠️ CalendarBackgroundSyncProcessor: Event not found when marking operation completed")
            return
        }
        
        event.needsEventKitSync = false
        event.lastSyncDate = Date()
        
        try modelContext.save()
    }
    
    private func markOperationFailed(_ operation: SyncOperation, error: Error) async throws {
        // For now, we'll just log the failure
        // In a full implementation, you might want to store failed operations for later retry
        print("❌ CalendarBackgroundSyncProcessor: Operation \(operation.id) permanently failed: \(error.localizedDescription)")
    }
    
    private func shouldStopBackgroundProcessing() -> Bool {
        // Check if we're running out of background execution time
        // This is a simplified check - in a real implementation, you'd track actual background time
        return false
    }
    
    private func invalidateAffectedCaches(for operations: [SyncOperation]) {
        let affectedUserIds = Set(operations.map { $0.userId })
        
        // Use centralized cache coordination to eliminate duplication
        for userId in affectedUserIds {
            cacheService.coordinateInvalidation(userId: userId, familyId: nil, eventId: nil)
        }
        
        print("🗑️ CalendarBackgroundSyncProcessor: Coordinated cache invalidation for \(affectedUserIds.count) users")
    }
    
    /// Helper method to get an event by ID
    private func getEvent(by id: UUID) async throws -> CalendarEvent? {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let events = try modelContext.fetch(descriptor)
        return events.first { $0.id == id }
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network changes to trigger sync when connection is restored
        NotificationCenter.default.addObserver(
            forName: .networkStatusChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if self.networkMonitor.isConnected && !self.isProcessing {
                    print("🌐 CalendarBackgroundSyncProcessor: Network restored, scheduling sync")
                    await self.processPendingSyncOperations()
                }
            }
        }
    }
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CalendarSync") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Centralized Background Processing Coordination
    
    /// Processes all background operations - centralized entry point
    func processAllBackgroundOperations() async {
        print("🔄 CalendarBackgroundSyncProcessor: Starting comprehensive background processing")
        
        guard !isProcessing else {
            print("⏳ CalendarBackgroundSyncProcessor: Already processing background operations")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Start background task
        beginBackgroundTask()
        defer { endBackgroundTask() }
        
        do {
            // Step 1: Process pending sync operations
            await processPendingSyncOperations()
            
            // Step 2: Perform cache maintenance
            await performCacheMaintenance()
            
            // Step 3: Clean up old data
            await performDataCleanup()
            
            // Step 4: Perform backup if needed
            await performBackgroundBackup()
            
            // Step 5: Update statistics
            await updateBackgroundStats()
            
            print("✅ CalendarBackgroundSyncProcessor: Completed comprehensive background processing")
            
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Background processing failed: \(error.localizedDescription)")
            backgroundSyncStats.recordError()
        }
    }
    
    /// Performs cache maintenance in background
    private func performCacheMaintenance() async {
        print("🧹 CalendarBackgroundSyncProcessor: Performing cache maintenance")
        
        do {
            // Clear expired cache entries
            cacheService.clearExpiredEntries()
            
            // Optimize cache storage
            await cacheService.optimizeStorage()
            
            print("✅ CalendarBackgroundSyncProcessor: Cache maintenance completed")
            
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Cache maintenance failed: \(error.localizedDescription)")
        }
    }
    
    /// Performs data cleanup in background
    private func performDataCleanup() async {
        print("🧹 CalendarBackgroundSyncProcessor: Performing data cleanup")
        
        do {
            // Clean up old deleted events (older than 30 days)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate<CalendarEvent> { event in
                    event.isDeleted && event.deletedAt != nil && event.deletedAt! < cutoffDate
                }
            )
            
            let oldDeletedEvents = try modelContext.fetch(descriptor)
            
            for event in oldDeletedEvents {
                modelContext.delete(event)
            }
            
            if !oldDeletedEvents.isEmpty {
                try modelContext.save()
                print("🗑️ CalendarBackgroundSyncProcessor: Cleaned up \(oldDeletedEvents.count) old deleted events")
            }
            
            print("✅ CalendarBackgroundSyncProcessor: Data cleanup completed")
            
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Data cleanup failed: \(error.localizedDescription)")
        }
    }
    
    /// Performs background backup if needed
    private func performBackgroundBackup() async {
        print("📅 CalendarBackgroundSyncProcessor: Checking if background backup is needed")
        
        guard let backupService = backupService else {
            print("ℹ️ CalendarBackgroundSyncProcessor: No backup service configured")
            return
        }
        
        await backupService.performBackgroundBackup()
    }
    
    /// Updates background processing statistics
    private func updateBackgroundStats() async {
        print("📊 CalendarBackgroundSyncProcessor: Updating background statistics")
        
        // Update last background processing time
        lastBackgroundSync = Date()
        
        // Reset processing progress
        processingProgress = 0
        
        print("✅ CalendarBackgroundSyncProcessor: Statistics updated")
    }
    
    /// Sets up periodic maintenance tasks
    private func setupPeriodicMaintenance() {
        print("⏰ CalendarBackgroundSyncProcessor: Setting up periodic maintenance")
        
        // Schedule periodic cache cleanup (every 6 hours)
        Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCacheMaintenance()
            }
        }
        
        // Schedule periodic data cleanup (daily)
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performDataCleanup()
            }
        }
    }
    
    /// Coordinates background sync with CalendarService
    func coordinateBackgroundSyncWithCalendarService(for userId: UUID) async {
        print("🔄 CalendarBackgroundSyncProcessor: Coordinating background sync with CalendarService")
        
        guard let calendarService = calendarService else {
            print("⚠️ CalendarBackgroundSyncProcessor: CalendarService not available, using direct sync")
            await forceBackgroundSync(for: userId)
            return
        }
        
        // Start background task
        beginBackgroundTask()
        defer { endBackgroundTask() }
        
        do {
            // Use CalendarService for centralized sync logic
            try await calendarService.performFullBidirectionalSync(for: userId)
            
            // Update our statistics
            backgroundSyncStats.recordSuccessfulSync(
                operationsProcessed: processingQueue.count,
                executionTime: 0 // CalendarService handles timing
            )
            
            print("✅ CalendarBackgroundSyncProcessor: Coordinated background sync completed")
            
        } catch {
            print("❌ CalendarBackgroundSyncProcessor: Coordinated background sync failed: \(error.localizedDescription)")
            backgroundSyncStats.recordError()
        }
    }
    
    /// Gets comprehensive background processing status
    func getComprehensiveBackgroundStatus() -> ComprehensiveBackgroundStatus {
        return ComprehensiveBackgroundStatus(
            syncStatus: getBackgroundSyncStatus(),
            cacheStatus: cacheService.getCacheStatus(),
            lastMaintenance: lastBackgroundSync,
            isProcessing: isProcessing,
            processingProgress: processingProgress
        )
    }
}

// MARK: - Background Task Coordinator

/// Coordinates different types of background tasks
private class BackgroundTaskCoordinator {
    private var activeTasks: Set<UIBackgroundTaskIdentifier> = []
    
    func beginTask(name: String) -> UIBackgroundTaskIdentifier {
        let taskId = UIApplication.shared.beginBackgroundTask(withName: name) {
            // Task expiration handler
            print("⏰ BackgroundTaskCoordinator: Task '\(name)' expired")
        }
        
        activeTasks.insert(taskId)
        return taskId
    }
    
    func endTask(_ taskId: UIBackgroundTaskIdentifier) {
        if activeTasks.contains(taskId) {
            UIApplication.shared.endBackgroundTask(taskId)
            activeTasks.remove(taskId)
        }
    }
    
    func endAllTasks() {
        for taskId in activeTasks {
            UIApplication.shared.endBackgroundTask(taskId)
        }
        activeTasks.removeAll()
    }
}

// MARK: - Comprehensive Background Status

/// Comprehensive status of all background operations
struct ComprehensiveBackgroundStatus {
    let syncStatus: BackgroundSyncStatus
    let cacheStatus: CacheStatus
    let lastMaintenance: Date?
    let isProcessing: Bool
    let processingProgress: Double
    
    var overallStatus: String {
        if isProcessing {
            return "Processing... (\(Int(processingProgress * 100))%)"
        } else if syncStatus.pendingOperations > 0 {
            return "Pending (\(syncStatus.pendingOperations) operations)"
        } else {
            return "Up to date"
        }
    }
}

// MARK: - Cache Status (placeholder)

/// Cache status information
struct CacheStatus {
    let totalEntries: Int
    let expiredEntries: Int
    let cacheHitRate: Double
    let lastCleanup: Date?
    
    var statusDescription: String {
        return "Cache: \(totalEntries) entries, \(String(format: "%.1f", cacheHitRate * 100))% hit rate"
    }
}

// MARK: - Supporting Types

// Note: SyncOperation and SyncOperationType are now defined in CalendarService.swift
// This file uses the canonical types and looks up events by ID when needed

/// Background sync statistics
struct BackgroundSyncStats {
    private(set) var totalSyncs: Int = 0
    private(set) var successfulSyncs: Int = 0
    private(set) var failedSyncs: Int = 0
    private(set) var totalOperationsProcessed: Int = 0
    private(set) var totalExecutionTime: TimeInterval = 0
    private(set) var lastSyncDate: Date?
    
    var successRate: Double {
        guard totalSyncs > 0 else { return 0 }
        return Double(successfulSyncs) / Double(totalSyncs)
    }
    
    var averageExecutionTime: TimeInterval {
        guard successfulSyncs > 0 else { return 0 }
        return totalExecutionTime / Double(successfulSyncs)
    }
    
    var averageOperationsPerSync: Double {
        guard successfulSyncs > 0 else { return 0 }
        return Double(totalOperationsProcessed) / Double(successfulSyncs)
    }
    
    mutating func recordSuccessfulSync(operationsProcessed: Int, executionTime: TimeInterval) {
        totalSyncs += 1
        successfulSyncs += 1
        totalOperationsProcessed += operationsProcessed
        totalExecutionTime += executionTime
        lastSyncDate = Date()
    }
    
    mutating func recordError() {
        totalSyncs += 1
        failedSyncs += 1
    }
    
    mutating func reset() {
        totalSyncs = 0
        successfulSyncs = 0
        failedSyncs = 0
        totalOperationsProcessed = 0
        totalExecutionTime = 0
        lastSyncDate = nil
    }
    
    var description: String {
        return """
        Background Sync Stats:
        - Total Syncs: \(totalSyncs)
        - Success Rate: \(String(format: "%.1f", successRate * 100))%
        - Operations Processed: \(totalOperationsProcessed)
        - Average Execution Time: \(String(format: "%.2f", averageExecutionTime))s
        - Average Operations/Sync: \(String(format: "%.1f", averageOperationsPerSync))
        - Last Sync: \(lastSyncDate?.formatted() ?? "Never")
        """
    }
}

/// Current background sync status
struct BackgroundSyncStatus {
    let isProcessing: Bool
    let progress: Double
    let lastSync: Date?
    let pendingOperations: Int
    let stats: BackgroundSyncStats
    
    var statusDescription: String {
        if isProcessing {
            return "Processing... (\(Int(progress * 100))%)"
        } else if pendingOperations > 0 {
            return "Pending (\(pendingOperations) operations)"
        } else {
            return "Up to date"
        }
    }
}

// MARK: - Extensions



