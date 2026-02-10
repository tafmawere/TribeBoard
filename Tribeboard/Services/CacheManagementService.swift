//
//  CacheManagementService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import CoreData
import Combine

/// Service for managing cache eviction policy and cleanup operations
/// Implements Requirements 10.3, 10.5 - cache management and app restart state restoration
@MainActor
class CacheManagementService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cacheSize: Int64 = 0
    @Published var isCleaningUp = false
    @Published var lastCleanupDate: Date?
    
    // MARK: - Configuration
    
    struct CacheConfiguration {
        let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
        let completedRunRetentionDays: Int = 7
        let cancelledRunRetentionDays: Int = 3
        let eventRetentionDays: Int = 30
        let cleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
        let maxActiveRuns: Int = 50
        let maxCompletedRuns: Int = 100
    }
    
    private let configuration = CacheConfiguration()
    
    // MARK: - Dependencies
    
    private let coreDataService: CoreDataService
    private let persistenceController: PersistenceController
    private let logger: PrivacyPreservingLogger
    
    // MARK: - Private Properties
    
    private var cleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(coreDataService: CoreDataService, persistenceController: PersistenceController, logger: PrivacyPreservingLogger) {
        self.coreDataService = coreDataService
        self.persistenceController = persistenceController
        self.logger = logger
        
        setupPeriodicCleanup()
        calculateCacheSize()
        restoreAppState()
    }
    
    // MARK: - Public Interface
    
    /// Perform cache cleanup based on eviction policy
    /// Implements Requirements 10.3 - cache eviction policy for completed runs
    func performCacheCleanup() async {
        guard !isCleaningUp else { return }
        
        isCleaningUp = true
        defer { isCleaningUp = false }
        
        logger.logInfo(
            message: "Starting cache cleanup",
            context: .cacheManagement,
            additionalInfo: ["cacheSize": String(cacheSize)]
        )
        
        do {
            // Step 1: Clean up old completed runs
            let completedRunsRemoved = try await cleanupCompletedRuns()
            
            // Step 2: Clean up old cancelled runs
            let cancelledRunsRemoved = try await cleanupCancelledRuns()
            
            // Step 3: Clean up old events
            let eventsRemoved = try await cleanupOldEvents()
            
            // Step 4: Enforce run count limits
            let excessRunsRemoved = try await enforceRunCountLimits()
            
            // Step 5: Check cache size and perform additional cleanup if needed
            calculateCacheSize()
            if cacheSize > configuration.maxCacheSize {
                let additionalCleanup = try await performSizeBasedCleanup()
                logger.logInfo(
                    message: "Additional size-based cleanup performed",
                    context: .cacheManagement,
                    additionalInfo: ["itemsRemoved": String(additionalCleanup)]
                )
            }
            
            lastCleanupDate = Date()
            
            logger.logInfo(
                message: "Cache cleanup completed successfully",
                context: .cacheManagement,
                additionalInfo: [
                    "completedRunsRemoved": String(completedRunsRemoved),
                    "cancelledRunsRemoved": String(cancelledRunsRemoved),
                    "eventsRemoved": String(eventsRemoved),
                    "excessRunsRemoved": String(excessRunsRemoved),
                    "finalCacheSize": String(cacheSize)
                ]
            )
            
        } catch {
            logger.logError(
                error,
                context: .cacheManagement,
                additionalInfo: ["operation": "cache_cleanup"]
            )
        }
    }
    
    /// Preserve active runs during cache cleanup
    /// Implements Requirements 10.3 - preserve active runs during cache cleanup
    func preserveActiveRuns() async throws -> [String] {
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "status IN %@",
                        [RunStatus.scheduled.rawValue, RunStatus.activeEnroute.rawValue, RunStatus.arrivedAtStop.rawValue, RunStatus.paused.rawValue]
                    )
                    
                    let activeRunEntities = try context.fetch(fetchRequest)
                    let activeRunIds = activeRunEntities.compactMap { $0.id }
                    
                    // Mark these runs as protected from cleanup
                    for entity in activeRunEntities {
                        entity.isProtectedFromCleanup = true
                    }
                    
                    try context.save()
                    continuation.resume(returning: activeRunIds)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Handle app restart state restoration
    /// Implements Requirements 10.5 - handle app restart state restoration
    func restoreAppState() {
        Task { @MainActor in
            do {
                // Restore active runs
                let activeRuns = try await restoreActiveRuns()
                
                // Restore user preferences
                restoreUserPreferences()
                
                // Restore navigation state
                restoreNavigationState()
                
                // Validate cache integrity
                try await validateCacheIntegrity()
                
                logger.logInfo(
                    message: "App state restored successfully",
                    context: .appLifecycle,
                    additionalInfo: [
                        "activeRunsRestored": String(activeRuns.count),
                        "cacheSize": String(cacheSize)
                    ]
                )
                
            } catch {
                logger.logError(
                    error,
                    context: .appLifecycle,
                    additionalInfo: ["operation": "state_restoration"]
                )
            }
        }
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> CacheStatistics {
        let context = persistenceController.container.viewContext
        
        var stats = CacheStatistics()
        
        context.performAndWait {
            // Count runs by status
            let runFetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
            
            do {
                let allRuns = try context.fetch(runFetchRequest)
                
                for run in allRuns {
                    guard let statusString = run.status,
                          let status = RunStatus(rawValue: statusString) else { continue }
                    
                    switch status {
                    case .scheduled, .activeEnroute, .arrivedAtStop, .paused:
                        stats.activeRunsCount += 1
                    case .completed:
                        stats.completedRunsCount += 1
                    case .cancelled:
                        stats.cancelledRunsCount += 1
                    }
                }
                
                // Count events
                let eventFetchRequest: NSFetchRequest<RunEventEntity> = RunEventEntity.fetchRequest()
                stats.eventsCount = try context.count(for: eventFetchRequest)
                
            } catch {
                logger.logError(
                    error,
                    context: .cacheManagement,
                    additionalInfo: ["operation": "cache_statistics"]
                )
            }
        }
        
        stats.totalCacheSize = cacheSize
        stats.lastCleanupDate = lastCleanupDate
        
        return stats
    }
    
    /// Force immediate cache cleanup
    func forceCleanup() async {
        await performCacheCleanup()
    }
    
    /// Clear all cache data (for testing or reset)
    func clearAllCache() async throws {
        isCleaningUp = true
        defer { isCleaningUp = false }
        
        let context = persistenceController.container.viewContext
        
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Delete all runs
                    let runFetchRequest: NSFetchRequest<NSFetchRequestResult> = RunEntity.fetchRequest()
                    let runDeleteRequest = NSBatchDeleteRequest(fetchRequest: runFetchRequest)
                    try context.execute(runDeleteRequest)
                    
                    // Delete all events
                    let eventFetchRequest: NSFetchRequest<NSFetchRequestResult> = RunEventEntity.fetchRequest()
                    let eventDeleteRequest = NSBatchDeleteRequest(fetchRequest: eventFetchRequest)
                    try context.execute(eventDeleteRequest)
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        calculateCacheSize()
        
        logger.logInfo(
            message: "All cache data cleared",
            context: .cacheManagement,
            additionalInfo: ["finalCacheSize": String(cacheSize)]
        )
    }
    
    // MARK: - Private Methods
    
    private func setupPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: configuration.cleanupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performCacheCleanup()
            }
        }
    }
    
    private func calculateCacheSize() {
        let context = persistenceController.container.viewContext
        
        context.performAndWait {
            do {
                // Calculate approximate cache size
                let runFetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                let runs = try context.fetch(runFetchRequest)
                
                let eventFetchRequest: NSFetchRequest<RunEventEntity> = RunEventEntity.fetchRequest()
                let events = try context.fetch(eventFetchRequest)
                
                // Rough estimation: each run ~2KB, each event ~1KB
                let runSize = Int64(runs.count * 2048)
                let eventSize = Int64(events.count * 1024)
                
                Task { @MainActor in
                    self.cacheSize = runSize + eventSize
                }
                
            } catch {
                Task { @MainActor in
                    self.logger.logError(
                        error,
                        context: .cacheManagement,
                        additionalInfo: ["operation": "cache_size_calculation"]
                    )
                }
            }
        }
    }
    
    /// Clean up old completed runs
    /// Implements Requirements 10.3 - cache eviction policy for completed runs
    private func cleanupCompletedRuns() async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -configuration.completedRunRetentionDays, to: Date()) ?? Date()
        
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "status == %@ AND scheduledTime < %@ AND isProtectedFromCleanup != YES",
                        RunStatus.completed.rawValue,
                        cutoffDate as NSDate
                    )
                    
                    let oldCompletedRuns = try context.fetch(fetchRequest)
                    let count = oldCompletedRuns.count
                    
                    // Delete associated events first
                    for run in oldCompletedRuns {
                        if let runId = run.id {
                            try self.deleteEventsForRun(runId: runId, context: context)
                        }
                    }
                    
                    // Delete the runs
                    oldCompletedRuns.forEach { context.delete($0) }
                    
                    try context.save()
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Clean up old cancelled runs
    /// Implements Requirements 10.3 - cache eviction policy for cancelled runs
    private func cleanupCancelledRuns() async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -configuration.cancelledRunRetentionDays, to: Date()) ?? Date()
        
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "status == %@ AND scheduledTime < %@ AND isProtectedFromCleanup != YES",
                        RunStatus.cancelled.rawValue,
                        cutoffDate as NSDate
                    )
                    
                    let oldCancelledRuns = try context.fetch(fetchRequest)
                    let count = oldCancelledRuns.count
                    
                    // Delete associated events first
                    for run in oldCancelledRuns {
                        if let runId = run.id {
                            try self.deleteEventsForRun(runId: runId, context: context)
                        }
                    }
                    
                    // Delete the runs
                    oldCancelledRuns.forEach { context.delete($0) }
                    
                    try context.save()
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Clean up old events
    private func cleanupOldEvents() async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -configuration.eventRetentionDays, to: Date()) ?? Date()
        
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEventEntity> = RunEventEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "timestamp < %@",
                        cutoffDate as NSDate
                    )
                    
                    let oldEvents = try context.fetch(fetchRequest)
                    let count = oldEvents.count
                    
                    oldEvents.forEach { context.delete($0) }
                    
                    try context.save()
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Enforce run count limits
    private func enforceRunCountLimits() async throws -> Int {
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    var totalRemoved = 0
                    
                    // Limit completed runs
                    let completedFetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    completedFetchRequest.predicate = NSPredicate(
                        format: "status == %@ AND isProtectedFromCleanup != YES",
                        RunStatus.completed.rawValue
                    )
                    completedFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RunEntity.scheduledTime, ascending: false)]
                    
                    let completedRuns = try context.fetch(completedFetchRequest)
                    if completedRuns.count > self.configuration.maxCompletedRuns {
                        let excessCompleted = Array(completedRuns.dropFirst(self.configuration.maxCompletedRuns))
                        
                        for run in excessCompleted {
                            if let runId = run.id {
                                try self.deleteEventsForRun(runId: runId, context: context)
                            }
                            context.delete(run)
                        }
                        
                        totalRemoved += excessCompleted.count
                    }
                    
                    try context.save()
                    continuation.resume(returning: totalRemoved)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Perform size-based cleanup when cache exceeds maximum size
    private func performSizeBasedCleanup() async throws -> Int {
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    var totalRemoved = 0
                    
                    // Remove oldest completed runs first
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "status IN %@ AND isProtectedFromCleanup != YES",
                        [RunStatus.completed.rawValue, RunStatus.cancelled.rawValue]
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RunEntity.scheduledTime, ascending: true)]
                    fetchRequest.fetchLimit = 20 // Remove up to 20 runs at a time
                    
                    let oldRuns = try context.fetch(fetchRequest)
                    
                    for run in oldRuns {
                        if let runId = run.id {
                            try self.deleteEventsForRun(runId: runId, context: context)
                        }
                        context.delete(run)
                        totalRemoved += 1
                    }
                    
                    try context.save()
                    continuation.resume(returning: totalRemoved)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Delete events for a specific run
    nonisolated private func deleteEventsForRun(runId: String, context: NSManagedObjectContext) throws {
        let eventFetchRequest = NSFetchRequest<RunEventEntity>(entityName: "RunEventEntity")
        eventFetchRequest.predicate = NSPredicate(format: "runId == %@", runId)
        
        let events = try context.fetch(eventFetchRequest)
        events.forEach { context.delete($0) }
    }
    
    /// Restore active runs after app restart
    /// Implements Requirements 10.5 - handle app restart state restoration
    private func restoreActiveRuns() async throws -> [Run] {
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "status IN %@",
                        [RunStatus.scheduled.rawValue, RunStatus.activeEnroute.rawValue, RunStatus.arrivedAtStop.rawValue, RunStatus.paused.rawValue]
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RunEntity.scheduledTime, ascending: true)]
                    
                    let activeRunEntities = try context.fetch(fetchRequest)
                    let activeRuns = try activeRunEntities.compactMap { try self.coreDataService.convertToRunFromCache($0) }
                    
                    continuation.resume(returning: activeRuns)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Restore user preferences
    private func restoreUserPreferences() {
        // Restore user preferences from UserDefaults or other storage
        if let lastCleanupTimestamp = UserDefaults.standard.object(forKey: "lastCacheCleanup") as? Date {
            lastCleanupDate = lastCleanupTimestamp
        }
    }
    
    /// Restore navigation state
    private func restoreNavigationState() {
        // Restore navigation state if needed
        // This would typically involve restoring the last viewed screen, active run, etc.
    }
    
    /// Validate cache integrity
    private func validateCacheIntegrity() async throws {
        let context = persistenceController.container.viewContext
        
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Check for orphaned events (events without corresponding runs)
                    let eventFetchRequest: NSFetchRequest<RunEventEntity> = RunEventEntity.fetchRequest()
                    let allEvents = try context.fetch(eventFetchRequest)
                    
                    let runFetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    let allRuns = try context.fetch(runFetchRequest)
                    let runIds = Set(allRuns.compactMap { $0.id })
                    
                    var orphanedEvents: [RunEventEntity] = []
                    for event in allEvents {
                        if let runId = event.runId, !runIds.contains(runId) {
                            orphanedEvents.append(event)
                        }
                    }
                    
                    // Remove orphaned events
                    if !orphanedEvents.isEmpty {
                        let orphanedCount = orphanedEvents.count
                        orphanedEvents.forEach { context.delete($0) }
                        try context.save()
                        
                        Task { @MainActor in
                            self.logger.logInfo(
                                message: "Removed orphaned events during cache validation",
                                context: .cacheManagement,
                                additionalInfo: ["orphanedEventsCount": String(orphanedCount)]
                            )
                        }
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
        
        // Save last cleanup date synchronously
        UserDefaults.standard.set(Date(), forKey: "lastCacheCleanup")
    }
}

// MARK: - Supporting Types

struct CacheStatistics {
    var activeRunsCount: Int = 0
    var completedRunsCount: Int = 0
    var cancelledRunsCount: Int = 0
    var eventsCount: Int = 0
    var totalCacheSize: Int64 = 0
    var lastCleanupDate: Date?
    
    var totalRunsCount: Int {
        return activeRunsCount + completedRunsCount + cancelledRunsCount
    }
    
    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalCacheSize)
    }
}

// MARK: - Core Data Extensions

extension RunEntity {
    @NSManaged var isProtectedFromCleanup: Bool
}

// MARK: - CoreDataService Extension

extension CoreDataService {
    func convertToRunFromCache(_ entity: RunEntity) throws -> Run {
        guard let id = entity.id,
              let title = entity.title,
              let scheduledTime = entity.scheduledTime,
              let driverId = entity.driverId,
              let statusString = entity.status,
              let status = RunStatus(rawValue: statusString),
              let createdBy = entity.createdBy,
              let familyId = entity.familyId,
              let stopsData = entity.stopsData,
              let passengersData = entity.passengersData else {
            throw CoreDataError.invalidData
        }
        
        let stops = try JSONDecoder().decode([RunStop].self, from: stopsData)
        let passengers = try JSONDecoder().decode([MemberSummary].self, from: passengersData)
        
        var lastLocation: GeoPoint?
        if entity.lastLocationLatitude != 0 || entity.lastLocationLongitude != 0 {
            lastLocation = GeoPoint(latitude: entity.lastLocationLatitude, longitude: entity.lastLocationLongitude)
        }
        
        return Run(
            id: id,
            title: title,
            scheduledTime: scheduledTime,
            driverId: driverId,
            status: status,
            stops: stops,
            passengers: passengers,
            createdBy: createdBy,
            familyId: familyId,
            isDelayed: entity.isDelayed,
            delayReason: entity.delayReason,
            currentStopIndex: Int(entity.currentStopIndex),
            lastLocation: lastLocation,
            lastLocationUpdatedAt: entity.lastLocationUpdatedAt,
            startTime: entity.startTime
        )
    }
}