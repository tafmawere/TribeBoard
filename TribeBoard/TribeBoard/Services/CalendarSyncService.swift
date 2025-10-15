import Foundation
import SwiftData
import EventKit

/// Errors that can occur during calendar synchronization
enum CalendarSyncError: LocalizedError {
    case eventKitNotAvailable
    case syncConfigurationNotFound
    case syncDisabled
    case conflictDetected(CalendarEvent, EKEvent)
    case batchSyncFailed([String])
    case dataInconsistency(String)
    case unknownSyncError(String)
    
    var errorDescription: String? {
        switch self {
        case .eventKitNotAvailable:
            return "EventKit is not available or access is denied"
        case .syncConfigurationNotFound:
            return "Sync configuration not found for user"
        case .syncDisabled:
            return "Apple Calendar sync is disabled"
        case .conflictDetected(let localEvent, let remoteEvent):
            return "Sync conflict detected for event '\(localEvent.title)'"
        case .batchSyncFailed(let errors):
            return "Batch sync failed: \(errors.joined(separator: "; "))"
        case .dataInconsistency(let message):
            return "Data inconsistency detected: \(message)"
        case .unknownSyncError(let message):
            return "Unknown sync error: \(message)"
        }
    }
}

/// Service for coordinating calendar synchronization between TribeBoard and Apple Calendar
/// NOTE: This service now delegates to CalendarService for centralized sync logic
@MainActor
class CalendarSyncService: ObservableObject {
    
    // MARK: - Properties
    
    private let eventKitManager: EventKitManager
    private let modelContext: ModelContext
    private weak var calendarService: CalendarService?
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    // MARK: - Initialization
    
    init(eventKitManager: EventKitManager, modelContext: ModelContext, calendarService: CalendarService? = nil) {
        self.eventKitManager = eventKitManager
        self.modelContext = modelContext
        self.calendarService = calendarService
        print("🔄 CalendarSyncService: Initialized (delegates to CalendarService)")
    }
    
    /// Sets the calendar service for delegation
    func setCalendarService(_ calendarService: CalendarService) {
        self.calendarService = calendarService
    }
    
    // MARK: - Sync Configuration Management
    
    /// Gets the sync configuration for a user
    private func getSyncConfiguration(for userId: UUID) throws -> SyncConfiguration? {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let allConfigs = try modelContext.fetch(descriptor)
        
        return allConfigs.first { config in
            config.userId == userId
        }
    }
    
    /// Validates that sync is enabled and configured - delegates to centralized validation
    private func validateSyncConfiguration(for userId: UUID) throws -> SyncConfiguration {
        // Use centralized validation service to eliminate duplication
        let validationService = CalendarEventValidationService(
            modelContext: modelContext,
            permissionManager: CalendarPermissionManager(modelContext: modelContext)
        )
        
        return try validationService.validateSyncConfiguration(for: userId)
    }
    
    // MARK: - Event Sync Operations
    
    /// Syncs a single event to Apple Calendar - delegates to CalendarService
    func syncEventToAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        print("📤 CalendarSyncService: Delegating event sync to CalendarService - '\(event.title)'")
        
        guard let calendarService = calendarService else {
            print("❌ CalendarSyncService: CalendarService not available, falling back to direct sync")
            // Fallback to direct sync if CalendarService is not available
            try await directSyncEventToAppleCalendar(event, userId: userId)
            return
        }
        
        // Delegate to centralized CalendarService
        try await calendarService.syncEventToAppleCalendar(event, userId: userId)
    }
    
    /// Direct sync fallback method (for backward compatibility)
    private func directSyncEventToAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarSyncService: Sync direction doesn't allow TribeBoard to Apple sync")
            return
        }
        
        do {
            // Sync to EventKit
            let eventKitIdentifier = try await eventKitManager.syncEventToAppleCalendar(event)
            
            // Update the event with EventKit information
            event.markAsEventKitSynced(
                eventIdentifier: eventKitIdentifier,
                calendarIdentifier: eventKitManager.getCalendarIdentifier(for: event.privacyLevel) ?? ""
            )
            
            // Save changes
            try modelContext.save()
            
            print("✅ CalendarSyncService: Successfully synced event to Apple Calendar (direct)")
            
        } catch {
            print("❌ CalendarSyncService: Failed to sync event to Apple Calendar: \(error.localizedDescription)")
            
            // Record sync error in configuration
            config.recordSyncError("Event sync failed: \(error.localizedDescription)")
            try modelContext.save()
            
            throw error
        }
    }
    
    /// Updates an event in Apple Calendar - delegates to CalendarService
    func updateEventInAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        print("📝 CalendarSyncService: Delegating event update to CalendarService - '\(event.title)'")
        
        guard let calendarService = calendarService else {
            print("❌ CalendarSyncService: CalendarService not available, falling back to direct update")
            try await directUpdateEventInAppleCalendar(event, userId: userId)
            return
        }
        
        // Delegate to centralized CalendarService
        try await calendarService.updateEventInAppleCalendar(event, userId: userId)
    }
    
    /// Direct update fallback method (for backward compatibility)
    private func directUpdateEventInAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarSyncService: Sync direction doesn't allow TribeBoard to Apple sync")
            return
        }
        
        do {
            // Update in EventKit
            try await eventKitManager.updateEventInAppleCalendar(event)
            
            // Mark as synced
            event.needsEventKitSync = false
            
            // Save changes
            try modelContext.save()
            
            print("✅ CalendarSyncService: Successfully updated event in Apple Calendar (direct)")
            
        } catch {
            print("❌ CalendarSyncService: Failed to update event in Apple Calendar: \(error.localizedDescription)")
            
            // Record sync error in configuration
            config.recordSyncError("Event update failed: \(error.localizedDescription)")
            try modelContext.save()
            
            throw error
        }
    }
    
    /// Deletes an event from Apple Calendar - delegates to CalendarService
    func deleteEventFromAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        print("🗑️ CalendarSyncService: Delegating event deletion to CalendarService - '\(event.title)'")
        
        guard let calendarService = calendarService else {
            print("❌ CalendarSyncService: CalendarService not available, falling back to direct deletion")
            try await directDeleteEventFromAppleCalendar(event, userId: userId)
            return
        }
        
        // Delegate to centralized CalendarService
        try await calendarService.deleteEventFromAppleCalendar(event, userId: userId)
    }
    
    /// Direct deletion fallback method (for backward compatibility)
    private func directDeleteEventFromAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarSyncService: Sync direction doesn't allow TribeBoard to Apple sync")
            return
        }
        
        guard let eventKitIdentifier = event.eventKitIdentifier else {
            print("ℹ️ CalendarSyncService: Event has no EventKit identifier, skipping Apple Calendar deletion")
            return
        }
        
        do {
            // Delete from EventKit
            try await eventKitManager.deleteEventFromAppleCalendar(eventKitIdentifier)
            
            // Clear EventKit information
            event.eventKitIdentifier = nil
            event.eventKitCalendarIdentifier = nil
            event.needsEventKitSync = false
            
            // Save changes
            try modelContext.save()
            
            print("✅ CalendarSyncService: Successfully deleted event from Apple Calendar (direct)")
            
        } catch {
            print("❌ CalendarSyncService: Failed to delete event from Apple Calendar: \(error.localizedDescription)")
            
            // Record sync error in configuration
            config.recordSyncError("Event deletion failed: \(error.localizedDescription)")
            try modelContext.save()
            
            throw error
        }
    }
    
    // MARK: - Batch Sync Operations
    
    /// Syncs all pending events to Apple Calendar - delegates to CalendarService
    func syncPendingEventsToAppleCalendar(userId: UUID) async throws {
        print("📤 CalendarSyncService: Delegating pending events sync to CalendarService")
        
        guard let calendarService = calendarService else {
            print("❌ CalendarSyncService: CalendarService not available, performing direct sync")
            try await directSyncPendingEventsToAppleCalendar(userId: userId)
            return
        }
        
        // Delegate to centralized CalendarService
        // Note: CalendarService handles this internally in performFullBidirectionalSync
        try await calendarService.performFullBidirectionalSync(for: userId)
    }
    
    /// Direct pending events sync fallback method (for backward compatibility)
    private func directSyncPendingEventsToAppleCalendar(userId: UUID) async throws {
        isSyncing = true
        syncProgress = 0.0
        syncError = nil
        
        defer {
            isSyncing = false
            syncProgress = 0.0
        }
        
        do {
            // Validate sync configuration
            let config = try validateSyncConfiguration(for: userId)
            
            // Get pending events
            let pendingEvents = try getPendingEventKitSyncEvents(for: userId)
            
            guard !pendingEvents.isEmpty else {
                print("ℹ️ CalendarSyncService: No pending events to sync")
                return
            }
            
            print("📊 CalendarSyncService: Found \(pendingEvents.count) pending events")
            
            var successCount = 0
            var errors: [String] = []
            
            // Sync events one by one with progress updates
            for (index, event) in pendingEvents.enumerated() {
                do {
                    if event.isDeleted {
                        // Handle deleted events
                        if let eventKitId = event.eventKitIdentifier {
                            try await eventKitManager.deleteEventFromAppleCalendar(eventKitId)
                        }
                        event.needsEventKitSync = false
                    } else if event.eventKitIdentifier != nil {
                        // Update existing event
                        try await eventKitManager.updateEventInAppleCalendar(event)
                        event.needsEventKitSync = false
                    } else {
                        // Create new event
                        let eventKitId = try await eventKitManager.syncEventToAppleCalendar(event)
                        event.markAsEventKitSynced(
                            eventIdentifier: eventKitId,
                            calendarIdentifier: eventKitManager.getCalendarIdentifier(for: event.privacyLevel) ?? ""
                        )
                    }
                    
                    successCount += 1
                    
                } catch {
                    errors.append("Event '\(event.title)': \(error.localizedDescription)")
                }
                
                // Update progress
                syncProgress = Double(index + 1) / Double(pendingEvents.count)
            }
            
            // Save all changes
            try modelContext.save()
            
            // Update sync configuration
            if errors.isEmpty {
                config.recordSuccessfulSync()
                lastSyncDate = Date()
            } else {
                config.recordSyncError("Batch sync partially failed: \(errors.joined(separator: "; "))")
                syncError = CalendarSyncError.batchSyncFailed(errors)
            }
            
            try modelContext.save()
            
            print("✅ CalendarSyncService: Batch sync completed - \(successCount) successful, \(errors.count) failed")
            
            if !errors.isEmpty {
                throw CalendarSyncError.batchSyncFailed(errors)
            }
            
        } catch {
            syncError = error
            throw error
        }
    }
    
    /// Retrieves events from Apple Calendar and syncs to TribeBoard
    func syncEventsFromAppleCalendar(userId: UUID, dateRange: DateInterval) async throws {
        print("📥 CalendarSyncService: Syncing events from Apple Calendar")
        
        isSyncing = true
        syncProgress = 0.0
        syncError = nil
        
        defer {
            isSyncing = false
            syncProgress = 0.0
        }
        
        do {
            // Validate sync configuration
            let config = try validateSyncConfiguration(for: userId)
            
            // Check sync direction
            guard config.syncDirection == .bidirectional || config.syncDirection == .appleToTribeBoard else {
                print("ℹ️ CalendarSyncService: Sync direction doesn't allow Apple to TribeBoard sync")
                return
            }
            
            // Fetch events from Apple Calendar
            let appleEvents = try await eventKitManager.fetchEventsFromAppleCalendar(for: dateRange)
            
            guard !appleEvents.isEmpty else {
                print("ℹ️ CalendarSyncService: No events found in Apple Calendar")
                config.recordSuccessfulSync()
                try modelContext.save()
                return
            }
            
            print("📊 CalendarSyncService: Found \(appleEvents.count) events in Apple Calendar")
            
            // Get existing TribeBoard events
            let existingEvents = try getExistingCalendarEvents(for: userId, in: dateRange)
            
            var processedCount = 0
            var errors: [String] = []
            
            // Process each Apple Calendar event
            for (index, appleEvent) in appleEvents.enumerated() {
                do {
                    try processAppleCalendarEvent(appleEvent, existingEvents: existingEvents, userId: userId, config: config)
                    processedCount += 1
                } catch {
                    errors.append("Event '\(appleEvent.title ?? "Untitled")': \(error.localizedDescription)")
                }
                
                // Update progress
                syncProgress = Double(index + 1) / Double(appleEvents.count)
            }
            
            // Save all changes
            try modelContext.save()
            
            // Update sync configuration
            if errors.isEmpty {
                config.recordSuccessfulSync()
                lastSyncDate = Date()
            } else {
                config.recordSyncError("Apple Calendar sync partially failed: \(errors.joined(separator: "; "))")
                syncError = CalendarSyncError.batchSyncFailed(errors)
            }
            
            try modelContext.save()
            
            print("✅ CalendarSyncService: Apple Calendar sync completed - \(processedCount) processed, \(errors.count) failed")
            
            if !errors.isEmpty {
                throw CalendarSyncError.batchSyncFailed(errors)
            }
            
        } catch {
            syncError = error
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets events that need EventKit sync
    private func getPendingEventKitSyncEvents(for userId: UUID) throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        return allEvents.filter { event in
            event.needsEventKitSync && (event.createdBy == userId || event.privacyLevel == .familyShared)
        }
    }
    
    /// Gets existing calendar events for a user in a date range
    private func getExistingCalendarEvents(for userId: UUID, in dateRange: DateInterval) throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        return allEvents.filter { event in
            !event.isDeleted &&
            (event.createdBy == userId || event.privacyLevel == .familyShared) &&
            event.startDate >= dateRange.start &&
            event.startDate <= dateRange.end
        }
    }
    
    /// Processes a single Apple Calendar event
    private func processAppleCalendarEvent(
        _ appleEvent: EKEvent,
        existingEvents: [CalendarEvent],
        userId: UUID,
        config: SyncConfiguration
    ) throws {
        
        // Check if this is a TribeBoard event
        if let tribeBoardEventId = CalendarEvent.extractTribeBoardEventId(from: appleEvent) {
            // Find matching TribeBoard event
            if let existingEvent = existingEvents.first(where: { $0.id == tribeBoardEventId }) {
                // Check for conflicts
                if existingEvent.lastModified > appleEvent.lastModified ?? Date.distantPast {
                    // TribeBoard event is newer - handle conflict
                    try handleSyncConflict(localEvent: existingEvent, remoteEvent: appleEvent, config: config)
                } else {
                    // Apple Calendar event is newer - update TribeBoard event
                    existingEvent.updateFromEKEvent(appleEvent, modifiedBy: userId)
                }
            } else {
                // TribeBoard event not found - it may have been deleted
                print("⚠️ CalendarSyncService: TribeBoard event not found for Apple Calendar event")
            }
        } else {
            // This is a new event from Apple Calendar - import it
            let newEvent = CalendarEvent.fromEKEvent(
                appleEvent,
                createdBy: userId,
                familyId: nil, // Will be determined by privacy level
                defaultPrivacyLevel: .personal
            )
            
            modelContext.insert(newEvent)
        }
    }
    
    /// Handles sync conflicts between local and remote events
    private func handleSyncConflict(
        localEvent: CalendarEvent,
        remoteEvent: EKEvent,
        config: SyncConfiguration
    ) throws {
        
        switch config.syncConflictResolution {
        case .lastModifiedWins:
            // Already handled in processAppleCalendarEvent
            break
            
        case .tribeBoardWins:
            // Keep TribeBoard version, update Apple Calendar
            try Task { @MainActor in
                try await eventKitManager.updateEventInAppleCalendar(localEvent)
            }.value
            
        case .appleCalendarWins:
            // Keep Apple Calendar version, update TribeBoard
            localEvent.updateFromEKEvent(remoteEvent, modifiedBy: localEvent.createdBy)
            
        case .askUser:
            // For now, use last modified wins as fallback
            // In a full implementation, this would trigger a UI prompt
            print("⚠️ CalendarSyncService: Conflict detected - using last modified wins as fallback")
            throw CalendarSyncError.conflictDetected(localEvent, remoteEvent)
        }
    }
    
    // MARK: - Full Bidirectional Sync
    
    /// Performs a complete bidirectional sync - delegates to CalendarService
    func performFullSync(userId: UUID, dateRange: DateInterval? = nil) async throws {
        print("🔄 CalendarSyncService: Delegating full sync to CalendarService")
        
        guard let calendarService = calendarService else {
            print("❌ CalendarSyncService: CalendarService not available, performing direct full sync")
            try await directPerformFullSync(userId: userId, dateRange: dateRange)
            return
        }
        
        // Delegate to centralized CalendarService
        try await calendarService.performFullBidirectionalSync(for: userId, dateRange: dateRange)
    }
    
    /// Direct full sync fallback method (for backward compatibility)
    private func directPerformFullSync(userId: UUID, dateRange: DateInterval? = nil) async throws {
        print("🔄 CalendarSyncService: Performing full bidirectional sync (direct)")
        
        let syncDateRange = dateRange ?? DateInterval(
            start: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            end: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        )
        
        // First sync pending TribeBoard events to Apple Calendar
        try await directSyncPendingEventsToAppleCalendar(userId: userId)
        
        // Then sync events from Apple Calendar to TribeBoard
        try await syncEventsFromAppleCalendar(userId: userId, dateRange: syncDateRange)
        
        print("✅ CalendarSyncService: Full bidirectional sync completed (direct)")
    }
}

// MARK: - Sync Status and Monitoring

extension CalendarSyncService {
    
    /// Gets the current sync status for a user
    func getSyncStatus(for userId: UUID) throws -> CalendarSyncStatus {
        guard let config = try getSyncConfiguration(for: userId) else {
            return CalendarSyncStatus(
                isEnabled: false,
                isHealthy: false,
                lastSyncDate: nil,
                pendingOperations: 0,
                errorMessage: "Sync not configured"
            )
        }
        
        let pendingEvents = try getPendingEventKitSyncEvents(for: userId)
        
        return CalendarSyncStatus(
            isEnabled: config.isAppleCalendarSyncEnabled,
            isHealthy: config.isSyncHealthy,
            lastSyncDate: config.lastSuccessfulSyncDate,
            pendingOperations: pendingEvents.count,
            errorMessage: config.lastSyncError
        )
    }
    
    /// Checks if sync is needed for a user
    func isSyncNeeded(for userId: UUID) throws -> Bool {
        guard let config = try getSyncConfiguration(for: userId) else {
            return false
        }
        
        guard config.isAppleCalendarSyncEnabled else {
            return false
        }
        
        // Check if there are pending events
        let pendingEvents = try getPendingEventKitSyncEvents(for: userId)
        if !pendingEvents.isEmpty {
            return true
        }
        
        // Check if sync is overdue
        return config.isSyncOverdue
    }
}

// MARK: - Sync Status Model

struct CalendarSyncStatus {
    let isEnabled: Bool
    let isHealthy: Bool
    let lastSyncDate: Date?
    let pendingOperations: Int
    let errorMessage: String?
    
    var statusDescription: String {
        if !isEnabled {
            return "Disabled"
        } else if !isHealthy {
            return "Error"
        } else if pendingOperations > 0 {
            return "Pending (\(pendingOperations))"
        } else {
            return "Up to date"
        }
    }
}