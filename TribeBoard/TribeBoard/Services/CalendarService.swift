import Foundation
import SwiftData
import EventKit

/// Protocol for calendar service operations
protocol CalendarServiceProtocol {
    func createEvent(_ event: CalendarEvent) async throws -> CalendarEvent
    func updateEvent(_ event: CalendarEvent) async throws -> CalendarEvent
    func deleteEvent(_ event: CalendarEvent) async throws
    func fetchEvents(for dateRange: DateInterval) async throws -> [CalendarEvent]
    func fetchFamilyEvents(for familyId: UUID, dateRange: DateInterval) async throws -> [CalendarEvent]
    func fetchPersonalEvents(for userId: UUID, dateRange: DateInterval) async throws -> [CalendarEvent]
    func syncWithAppleCalendar(userId: UUID) async throws
    func enableAppleCalendarSync(userId: UUID) async throws
    func disableAppleCalendarSync(userId: UUID) async throws
}

/// Family calendar permissions structure
struct FamilyCalendarPermissions {
    let hasAccess: Bool
    let canCreate: Bool
    let canModifyAll: Bool
    let canDeleteAll: Bool
    let isAdmin: Bool
    
    var description: String {
        var permissions: [String] = []
        if hasAccess { permissions.append("View") }
        if canCreate { permissions.append("Create") }
        if canModifyAll { permissions.append("Modify All") }
        if canDeleteAll { permissions.append("Delete All") }
        if isAdmin { permissions.append("Admin") }
        
        return permissions.isEmpty ? "No Access" : permissions.joined(separator: ", ")
    }
}

/// Family calendar statistics structure
struct FamilyCalendarStats {
    let totalEvents: Int
    let upcomingEvents: Int
    let pastEvents: Int
    let todayEvents: Int
    let uniqueCreators: Int
    let eventsByCreator: [UUID: Int]
    let dateRange: DateInterval
    
    var description: String {
        return """
        Family Calendar Stats (\(dateRange.start) - \(dateRange.end)):
        - Total Events: \(totalEvents)
        - Upcoming: \(upcomingEvents)
        - Past: \(pastEvents)
        - Today: \(todayEvents)
        - Active Members: \(uniqueCreators)
        """
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

/// Service for managing calendar events with EventKit integration and performance optimizations
@MainActor
class CalendarService: ObservableObject, CalendarServiceProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let eventKitManager: EventKitManager
    private let calendarSyncService: CalendarSyncService
    private let syncManager: CalendarSyncManager
    private let offlineEventManager: OfflineEventManager
    private let networkMonitor: NetworkMonitor
    private let permissionManager: CalendarPermissionManager
    
    // Performance optimization components
    private lazy var performanceService: CalendarPerformanceService = {
        CalendarPerformanceService(
            modelContext: modelContext,
            calendarService: self,
            calendarSyncService: calendarSyncService,
            networkMonitor: networkMonitor
        )
    }()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext, 
        eventKitManager: EventKitManager, 
        calendarSyncService: CalendarSyncService,
        syncManager: CalendarSyncManager,
        offlineEventManager: OfflineEventManager,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.modelContext = modelContext
        self.eventKitManager = eventKitManager
        self.calendarSyncService = calendarSyncService
        self.syncManager = syncManager
        self.offlineEventManager = offlineEventManager
        self.networkMonitor = networkMonitor
        self.permissionManager = CalendarPermissionManager(modelContext: modelContext)
        print("📅 CalendarService: Initialized with sync coordination and permission management")
    }
    
    // MARK: - Event CRUD Operations
    
    /// Creates a new calendar event with comprehensive validation and error handling
    func createEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
        let context = CalendarErrorContext(
            userId: event.createdBy.uuidString,
            familyId: event.familyId?.uuidString,
            eventId: event.id.uuidString,
            operation: "createEvent",
            additionalInfo: [
                "eventTitle": event.title,
                "privacyLevel": event.privacyLevel.rawValue,
                "isAllDay": event.isAllDay
            ]
        )
        
        print("📝 CalendarService: Creating new event - '\(event.title)' with privacy level: \(event.privacyLevel.displayName)")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Comprehensive event validation
            try await validateEventForCreation(event, context: context)
            
            // Validate privacy level and permissions
            try await validatePrivacyLevelAndPermissions(event, context: context)
            
            // Validate user permissions for creating this type of event
            if event.privacyLevel == .familyShared, let familyId = event.familyId {
                guard try await canCreateFamilyEvents(userId: event.createdBy, familyId: familyId) else {
                    let permissionError = CalendarError.insufficientPermissions(
                        operation: "create family event",
                        required: "calendar create permission"
                    )
                    CalendarErrorLogger.shared.logError(permissionError, context: context)
                    throw permissionError
                }
            }
            
            // Check for duplicate events
            try await validateNoDuplicateEvent(event, context: context)
            
            // Set creation metadata
            event.createdAt = Date()
            event.lastModified = Date()
            event.needsSync = true
            event.needsEventKitSync = true
            event.version = 1
            
            // Insert into local database with error handling
            do {
                modelContext.insert(event)
                try modelContext.save()
                print("✅ CalendarService: Event created in local database with ID: \(event.id)")
            } catch {
                let dbError = CalendarError.databaseOperationFailed(
                    operation: "insert event",
                    error: error.localizedDescription
                )
                CalendarErrorLogger.shared.logError(dbError, context: context)
                throw dbError
            }
            
            // Handle sync coordination with comprehensive error handling
            if shouldSyncToAppleCalendar(event) {
                await handleEventSyncWithErrorHandling(event, operation: .create, context: context)
            }
            
            return event
            
        } catch let calendarError as CalendarError {
            self.error = calendarError
            CalendarErrorLogger.shared.logError(calendarError, context: context)
            print("❌ CalendarService: Failed to create event: \(calendarError.localizedDescription)")
            throw calendarError
        } catch {
            let wrappedError = CalendarError.databaseOperationFailed(
                operation: "createEvent",
                error: error.localizedDescription
            )
            self.error = wrappedError
            CalendarErrorLogger.shared.logError(wrappedError, context: context)
            print("❌ CalendarService: Failed to create event: \(wrappedError.localizedDescription)")
            throw wrappedError
        }
    }
    
    /// Updates an existing calendar event with comprehensive validation and error handling
    func updateEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
        let context = CalendarErrorContext(
            userId: (event.modifiedBy ?? event.createdBy).uuidString,
            familyId: event.familyId?.uuidString,
            eventId: event.id.uuidString,
            operation: "updateEvent",
            additionalInfo: [
                "eventTitle": event.title,
                "privacyLevel": event.privacyLevel.rawValue,
                "version": event.version
            ]
        )
        
        print("📝 CalendarService: Updating event - '\(event.title)' (ID: \(event.id))")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Comprehensive event validation
            try await validateEventForUpdate(event, context: context)
            
            // Check permissions for updating this event
            try await validateUpdatePermissions(for: event, context: context)
            
            // Validate user permissions for modifying this event
            let userId = event.modifiedBy ?? event.createdBy
            guard try await canModifyFamilyEvent(event, userId: userId) else {
                let permissionError = CalendarError.insufficientPermissions(
                    operation: "update event",
                    required: "event modify permission"
                )
                CalendarErrorLogger.shared.logError(permissionError, context: context)
                throw permissionError
            }
            
            // Validate privacy level changes
            try await validatePrivacyLevelAndPermissions(event, context: context)
            
            // Check for scheduling conflicts after update
            try await validateSchedulingConflicts(event, context: context)
            
            // Update modification tracking
            event.lastModified = Date()
            event.version += 1
            event.needsSync = true
            event.needsEventKitSync = true
            
            // Save to local database with error handling
            do {
                try modelContext.save()
                print("✅ CalendarService: Event updated in local database (version: \(event.version))")
            } catch {
                let dbError = CalendarError.databaseOperationFailed(
                    operation: "update event",
                    error: error.localizedDescription
                )
                CalendarErrorLogger.shared.logError(dbError, context: context)
                throw dbError
            }
            
            // Handle sync coordination
            if shouldSyncToAppleCalendar(event) {
                if networkMonitor.isConnected {
                    // Online - sync immediately
                    do {
                        try await calendarSyncService.updateEventInAppleCalendar(event, userId: event.createdBy)
                        print("✅ CalendarService: Event updated in Apple Calendar")
                    } catch {
                        print("⚠️ CalendarService: Failed to update in Apple Calendar, queuing for retry: \(error.localizedDescription)")
                        // Queue for retry via sync manager
                        syncManager.queueEventForSync(event, operation: .update, userId: event.createdBy)
                    }
                } else {
                    // Offline - queue for later sync
                    print("📱 CalendarService: Offline - queuing event update for sync when connection is restored")
                    syncManager.queueEventForSync(event, operation: .update, userId: event.createdBy)
                }
            }
            
            return event
            
        } catch {
            self.error = error
            print("❌ CalendarService: Failed to update event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes a calendar event with sync coordination
    func deleteEvent(_ event: CalendarEvent) async throws {
        print("🗑️ CalendarService: Deleting event - '\(event.title)' (ID: \(event.id))")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Check permissions for deleting this event
            try validateDeletePermissions(for: event)
            
            // Validate user permissions for deleting this event
            guard try await canDeleteFamilyEvent(event, userId: event.createdBy) else {
                throw CalendarPermissionError.insufficientPermissions
            }
            
            // Handle sync coordination for deletion
            if shouldSyncToAppleCalendar(event) {
                if networkMonitor.isConnected {
                    // Online - sync immediately
                    do {
                        try await calendarSyncService.deleteEventFromAppleCalendar(event, userId: event.createdBy)
                        print("✅ CalendarService: Event deleted from Apple Calendar")
                    } catch {
                        print("⚠️ CalendarService: Failed to delete from Apple Calendar, queuing for retry: \(error.localizedDescription)")
                        // Queue for retry via sync manager (after local deletion)
                    }
                } else {
                    // Offline - will queue after local deletion
                    print("📱 CalendarService: Offline - will queue deletion for sync when connection is restored")
                }
            }
            
            // Mark as deleted (soft delete) to maintain sync integrity
            event.markAsDeleted(by: event.createdBy)
            
            // Save the soft delete
            try modelContext.save()
            
            print("✅ CalendarService: Event marked as deleted in local database")
            
            // Queue for sync if needed and not already synced
            if shouldSyncToAppleCalendar(event) && (!networkMonitor.isConnected || event.eventKitIdentifier != nil) {
                syncManager.queueEventForSync(event, operation: .delete, userId: event.createdBy)
            }
            
            // Optionally perform hard delete after a delay for sync purposes
            // For now, we'll keep soft delete to maintain data integrity
            
        } catch {
            self.error = error
            print("❌ CalendarService: Failed to delete event: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Event Fetching Operations
    
    /// Fetches events within a date range with privacy filtering (performance optimized)
    func fetchEvents(for dateRange: DateInterval) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Fetching events for date range: \(dateRange.start) to \(dateRange.end)")
        
        // Use performance service for optimized loading
        let result = try await performanceService.loadEventsOptimized(dateRange: dateRange)
        
        print("📊 CalendarService: Found \(result.events.count) events in date range (from \(result.isFromCache ? "cache" : "database"))")
        return result.events
    }
    
    /// Fetches events with pagination support for large datasets
    func fetchEventsPaginated(
        for dateRange: DateInterval,
        pageSize: Int = 50,
        sortBy: EventSortOption = .startDate
    ) async throws -> PaginatedEventResult {
        print("📄 CalendarService: Fetching paginated events for date range: \(dateRange.start) to \(dateRange.end)")
        
        return try await performanceService.loadEventsPaginated(
            dateRange: dateRange,
            pageSize: pageSize,
            sortBy: sortBy
        )
    }
    
    /// Loads next page of events for pagination
    func fetchNextPage(
        for dateRange: DateInterval,
        sortBy: EventSortOption = .startDate
    ) async throws -> [CalendarEvent] {
        return try await performanceService.loadNextPage(
            dateRange: dateRange,
            sortBy: sortBy
        )
    }
    
    /// Fetches events for a specific user with privacy filtering (performance optimized)
    func fetchEventsForUser(_ userId: UUID, dateRange: DateInterval, includeFamily: Bool = true) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Fetching events for user: \(userId), includeFamily: \(includeFamily)")
        
        // Use performance service for optimized loading
        let result = try await performanceService.loadEventsOptimized(
            dateRange: dateRange,
            userId: userId
        )
        
        // Filter for family events if requested
        let filteredEvents = includeFamily ? result.events : result.events.filter { $0.createdBy == userId }
        
        print("📊 CalendarService: Found \(filteredEvents.count) events for user (from \(result.isFromCache ? "cache" : "database"))")
        return filteredEvents
    }
    
    /// Fetches events for a user with pagination support
    func fetchEventsForUserPaginated(
        _ userId: UUID,
        dateRange: DateInterval,
        includeFamily: Bool = true,
        pageSize: Int = 50,
        sortBy: EventSortOption = .startDate
    ) async throws -> PaginatedEventResult {
        print("📄 CalendarService: Fetching paginated events for user: \(userId)")
        
        return try await performanceService.loadEventsPaginated(
            dateRange: dateRange,
            userId: userId,
            pageSize: pageSize,
            sortBy: sortBy
        )
    }
    
    /// Fetches family events for a specific family with visibility logic (performance optimized)
    func fetchFamilyEvents(for familyId: UUID, dateRange: DateInterval) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Fetching family events for family: \(familyId)")
        
        // Use performance service for optimized loading
        let result = try await performanceService.loadEventsOptimized(
            dateRange: dateRange,
            familyId: familyId,
            privacyLevel: .familyShared
        )
        
        print("📊 CalendarService: Found \(result.events.count) family events (from \(result.isFromCache ? "cache" : "database"))")
        return result.events
    }
    
    /// Fetches family events with pagination support
    func fetchFamilyEventsPaginated(
        for familyId: UUID,
        dateRange: DateInterval,
        pageSize: Int = 50,
        sortBy: EventSortOption = .startDate
    ) async throws -> PaginatedEventResult {
        print("📄 CalendarService: Fetching paginated family events for family: \(familyId)")
        
        return try await performanceService.loadEventsPaginated(
            dateRange: dateRange,
            familyId: familyId,
            privacyLevel: .familyShared,
            pageSize: pageSize,
            sortBy: sortBy
        )
    }
    
    /// Fetches family events visible to a specific user
    func fetchFamilyEventsForUser(_ userId: UUID, familyId: UUID, dateRange: DateInterval) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Fetching family events for user: \(userId) in family: \(familyId)")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // First check if user has access to family events
            guard try await hasAccessToFamilyEvents(userId: userId, familyId: familyId) else {
                print("❌ CalendarService: User \(userId) does not have access to family \(familyId) events")
                throw CalendarSyncError.dataInconsistency("User does not have access to family events")
            }
            
            let familyEvents = try await fetchFamilyEvents(for: familyId, dateRange: dateRange)
            
            // Apply additional filtering based on user permissions if needed
            let visibleEvents = try filterEventsForUserVisibility(familyEvents, userId: userId, familyId: familyId)
            
            print("📊 CalendarService: User can see \(visibleEvents.count) of \(familyEvents.count) family events")
            return visibleEvents
            
        } catch {
            self.error = error
            print("❌ CalendarService: Failed to fetch family events for user: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches personal events for a specific user (performance optimized)
    func fetchPersonalEvents(for userId: UUID, dateRange: DateInterval) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Fetching personal events for user: \(userId)")
        
        // Use performance service for optimized loading
        let result = try await performanceService.loadEventsOptimized(
            dateRange: dateRange,
            userId: userId,
            privacyLevel: .personal
        )
        
        print("📊 CalendarService: Found \(result.events.count) personal events (from \(result.isFromCache ? "cache" : "database"))")
        return result.events
    }
    
    /// Fetches personal events with pagination support
    func fetchPersonalEventsPaginated(
        for userId: UUID,
        dateRange: DateInterval,
        pageSize: Int = 50,
        sortBy: EventSortOption = .startDate
    ) async throws -> PaginatedEventResult {
        print("📄 CalendarService: Fetching paginated personal events for user: \(userId)")
        
        return try await performanceService.loadEventsPaginated(
            dateRange: dateRange,
            userId: userId,
            privacyLevel: .personal,
            pageSize: pageSize,
            sortBy: sortBy
        )
    }
    
    // MARK: - Family Event Sharing Operations
    
    /// Creates a family shared event
    func createFamilyEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        createdBy: UUID,
        familyId: UUID
    ) async throws -> CalendarEvent {
        print("👨‍👩‍👧‍👦 CalendarService: Creating family shared event - '\(title)'")
        
        // Validate family access
        guard try await hasAccessToFamilyEvents(userId: createdBy, familyId: familyId) else {
            throw CalendarSyncError.dataInconsistency("User does not have access to create family events")
        }
        
        // Check family event creation permissions
        guard try await canCreateFamilyEvents(userId: createdBy, familyId: familyId) else {
            throw CalendarSyncError.dataInconsistency("User does not have permission to create family events")
        }
        
        let event = CalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            privacyLevel: .familyShared,
            createdBy: createdBy,
            familyId: familyId
        )
        
        return try await createEvent(event)
    }
    
    /// Shares an existing personal event with family
    func shareEventWithFamily(_ event: CalendarEvent, familyId: UUID, sharedBy: UUID) async throws -> CalendarEvent {
        print("📤 CalendarService: Sharing event '\(event.title)' with family: \(familyId)")
        
        // Validate permissions
        guard event.createdBy == sharedBy else {
            throw CalendarSyncError.dataInconsistency("Only event creator can share with family")
        }
        
        guard event.privacyLevel == .personal else {
            throw CalendarSyncError.dataInconsistency("Event is already shared or not personal")
        }
        
        // Check family access
        guard try await hasAccessToFamilyEvents(userId: sharedBy, familyId: familyId) else {
            throw CalendarSyncError.dataInconsistency("User does not have access to share with this family")
        }
        
        // Update event privacy level
        event.privacyLevel = .familyShared
        event.familyId = familyId
        
        return try await updateEvent(event)
    }
    
    /// Removes family sharing from an event (makes it personal)
    func unshareEventFromFamily(_ event: CalendarEvent, unsharedBy: UUID) async throws -> CalendarEvent {
        print("📥 CalendarService: Unsharing event '\(event.title)' from family")
        
        // Validate permissions
        guard try await canModifyFamilyEvent(event, userId: unsharedBy) else {
            throw CalendarSyncError.dataInconsistency("User does not have permission to unshare this event")
        }
        
        guard event.privacyLevel == .familyShared else {
            throw CalendarSyncError.dataInconsistency("Event is not currently shared with family")
        }
        
        // Update event privacy level
        event.privacyLevel = .personal
        event.familyId = nil
        
        return try await updateEvent(event)
    }
    
    /// Gets all family members who can see a specific event
    func getFamilyMembersWithEventAccess(_ event: CalendarEvent) async throws -> [UUID] {
        guard event.privacyLevel == .familyShared,
              let familyId = event.familyId else {
            return [event.createdBy] // Only creator for personal events
        }
        
        // TODO: Integrate with family service to get actual family members
        // For now, return placeholder logic
        print("📊 CalendarService: Getting family members with access to event: \(event.id)")
        
        // This would be replaced with actual family service integration
        return [event.createdBy] // Placeholder - would return all family members
    }
    
    /// Filters events based on user's family membership and permissions
    func filterEventsForUserVisibility(_ events: [CalendarEvent], userId: UUID, familyId: UUID) throws -> [CalendarEvent] {
        return events.filter { event in
            switch event.privacyLevel {
            case .personal:
                // User can only see their own personal events
                return event.createdBy == userId
                
            case .familyShared:
                // User can see family events if they belong to the same family
                return event.familyId == familyId
            }
        }
    }
    
    // MARK: - Family Permission Management
    
    /// Checks if a user has access to family events
    func hasAccessToFamilyEvents(userId: UUID, familyId: UUID) async throws -> Bool {
        print("🔐 CalendarService: Checking family access for user: \(userId), family: \(familyId)")
        return try permissionManager.hasPermission(
            userId: userId,
            familyId: familyId,
            permission: .viewFamilyEvents
        )
    }
    
    /// Checks if a user can create family events
    func canCreateFamilyEvents(userId: UUID, familyId: UUID) async throws -> Bool {
        print("🔐 CalendarService: Checking family event creation permission for user: \(userId)")
        return try permissionManager.hasPermission(
            userId: userId,
            familyId: familyId,
            permission: .createEvents
        )
    }
    
    /// Checks if a user can modify a specific family event
    func canModifyFamilyEvent(_ event: CalendarEvent, userId: UUID) async throws -> Bool {
        // Event creator can always modify their own events if they have basic permissions
        if event.createdBy == userId {
            guard let familyId = event.familyId else { return true } // Personal events
            return try permissionManager.hasPermission(
                userId: userId,
                familyId: familyId,
                permission: .editOwnEvents
            )
        }
        
        // For family events, check if user can edit all family events
        if event.privacyLevel == .familyShared,
           let familyId = event.familyId {
            return try permissionManager.hasPermission(
                userId: userId,
                familyId: familyId,
                permission: .editFamilyEvents
            )
        }
        
        return false
    }
    
    /// Checks if a user can delete a specific family event
    func canDeleteFamilyEvent(_ event: CalendarEvent, userId: UUID) async throws -> Bool {
        // Event creator can delete their own events if they have basic permissions
        if event.createdBy == userId {
            guard let familyId = event.familyId else { return true } // Personal events
            return try permissionManager.hasPermission(
                userId: userId,
                familyId: familyId,
                permission: .deleteOwnEvents
            )
        }
        
        // For family events, check if user can delete all family events
        if event.privacyLevel == .familyShared,
           let familyId = event.familyId {
            return try permissionManager.hasPermission(
                userId: userId,
                familyId: familyId,
                permission: .deleteFamilyEvents
            )
        }
        
        return false
    }
    
    /// Checks if a user is a family calendar administrator
    func isFamilyCalendarAdmin(userId: UUID, familyId: UUID) async throws -> Bool {
        print("🔐 CalendarService: Checking family calendar admin status for user: \(userId)")
        return try permissionManager.hasPermission(
            userId: userId,
            familyId: familyId,
            permission: .managePermissions
        )
    }
    
    /// Gets family calendar permissions for a user
    func getFamilyCalendarPermissions(userId: UUID, familyId: UUID) async throws -> FamilyCalendarPermissions {
        let hasAccess = try await hasAccessToFamilyEvents(userId: userId, familyId: familyId)
        let canCreate = try await canCreateFamilyEvents(userId: userId, familyId: familyId)
        let isAdmin = try await isFamilyCalendarAdmin(userId: userId, familyId: familyId)
        
        return FamilyCalendarPermissions(
            hasAccess: hasAccess,
            canCreate: canCreate,
            canModifyAll: isAdmin,
            canDeleteAll: isAdmin,
            isAdmin: isAdmin
        )
    }
    
    /// Bulk updates family event permissions (admin only)
    func updateFamilyEventPermissions(
        familyId: UUID,
        adminUserId: UUID,
        memberPermissions: [UUID: FamilyCalendarPermissions]
    ) async throws {
        print("🔐 CalendarService: Updating family event permissions for family: \(familyId)")
        
        // Validate admin permissions
        guard try await isFamilyCalendarAdmin(userId: adminUserId, familyId: familyId) else {
            throw CalendarSyncError.dataInconsistency("Only family calendar admins can update permissions")
        }
        
        // TODO: Integrate with family service to update permissions
        // For now, just log the operation
        print("📊 CalendarService: Would update permissions for \(memberPermissions.count) family members")
    }
    
    /// Gets statistics about family calendar usage
    func getFamilyCalendarStats(familyId: UUID, dateRange: DateInterval) async throws -> FamilyCalendarStats {
        print("📊 CalendarService: Getting family calendar statistics for family: \(familyId)")
        
        let familyEvents = try await fetchFamilyEvents(for: familyId, dateRange: dateRange)
        
        let eventsByCreator = Dictionary(grouping: familyEvents) { $0.createdBy }
        let totalEvents = familyEvents.count
        let uniqueCreators = eventsByCreator.keys.count
        
        let upcomingEvents = familyEvents.filter { $0.isUpcoming }.count
        let pastEvents = familyEvents.filter { $0.isPast }.count
        let todayEvents = familyEvents.filter { $0.isToday }.count
        
        return FamilyCalendarStats(
            totalEvents: totalEvents,
            upcomingEvents: upcomingEvents,
            pastEvents: pastEvents,
            todayEvents: todayEvents,
            uniqueCreators: uniqueCreators,
            eventsByCreator: eventsByCreator.mapValues { $0.count },
            dateRange: dateRange
        )
    }
    
    // MARK: - Helper Methods
    
    /// Determines if an event should sync to Apple Calendar
    private func shouldSyncToAppleCalendar(_ event: CalendarEvent) -> Bool {
        // Check if user has Apple Calendar sync enabled
        do {
            if let config = try getSyncConfiguration(for: event.createdBy) {
                return config.isAppleCalendarSyncEnabled && config.eventKitPermissionGranted
            }
        } catch {
            print("⚠️ CalendarService: Failed to check sync configuration: \(error)")
        }
        return false
    }
    
    /// Gets sync configuration for a user
    private func getSyncConfiguration(for userId: UUID) throws -> SyncConfiguration? {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let configs = try modelContext.fetch(descriptor)
        return configs.first { $0.userId == userId }
    }
    
    /// Gets or creates sync configuration for a user
    private func getOrCreateSyncConfiguration(for userId: UUID) throws -> SyncConfiguration {
        if let existing = try getSyncConfiguration(for: userId) {
            return existing
        }
        
        let newConfig = SyncConfiguration(userId: userId)
        modelContext.insert(newConfig)
        return newConfig
    }
    
    // MARK: - Offline Event Operations
    
    /// Creates an event with offline support
    func createEventWithOfflineSupport(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel = .personal,
        createdBy: UUID,
        familyId: UUID? = nil
    ) async throws -> CalendarEvent {
        
        if networkMonitor.isConnected {
            // Online - use regular creation
            let event = CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                privacyLevel: privacyLevel,
                createdBy: createdBy,
                familyId: familyId
            )
            return try await createEvent(event)
        } else {
            // Offline - use offline event manager
            return try offlineEventManager.createEventOffline(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                privacyLevel: privacyLevel,
                createdBy: createdBy,
                familyId: familyId
            )
        }
    }
    
    /// Updates an event with offline support
    func updateEventWithOfflineSupport(
        _ event: CalendarEvent,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool? = nil,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        modifiedBy: UUID
    ) async throws -> CalendarEvent {
        
        if networkMonitor.isConnected {
            // Online - use regular update
            event.updateEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                privacyLevel: privacyLevel,
                modifiedBy: modifiedBy
            )
            return try await updateEvent(event)
        } else {
            // Offline - use offline event manager
            return try offlineEventManager.updateEventOffline(
                event,
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                privacyLevel: privacyLevel,
                modifiedBy: modifiedBy
            )
        }
    }
    
    /// Deletes an event with offline support
    func deleteEventWithOfflineSupport(_ event: CalendarEvent, deletedBy: UUID) async throws {
        if networkMonitor.isConnected {
            // Online - use regular deletion
            try await deleteEvent(event)
        } else {
            // Offline - use offline event manager
            try offlineEventManager.deleteEventOffline(event, deletedBy: deletedBy)
        }
    }
    
    /// Gets sync status for a user
    func getSyncStatus(for userId: UUID) throws -> SyncStatusInfo {
        let offlineStats = try offlineEventManager.getOfflineStatistics(for: userId)
        
        return SyncStatusInfo(
            isOnline: networkMonitor.isConnected,
            isSyncing: syncManager.isSyncing,
            syncProgress: syncManager.syncProgress,
            lastSyncDate: syncManager.lastSyncDate,
            pendingOperations: syncManager.pendingOperationsCount,
            offlineStatistics: offlineStats,
            syncError: syncManager.syncError?.localizedDescription
        )
    }
    
    // MARK: - Apple Calendar Sync Operations
    
    /// Syncs with Apple Calendar - centralized sync entry point
    func syncWithAppleCalendar(userId: UUID) async throws {
        print("🔄 CalendarService: Starting comprehensive Apple Calendar sync")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Perform full bidirectional sync
            try await performFullBidirectionalSync(for: userId)
            print("✅ CalendarService: Apple Calendar sync completed")
            
        } catch {
            self.error = error
            print("❌ CalendarService: Apple Calendar sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Performs comprehensive bidirectional sync - centralized sync logic
    func performFullBidirectionalSync(for userId: UUID, dateRange: DateInterval? = nil) async throws {
        print("🔄 CalendarService: Performing full bidirectional sync for user: \(userId)")
        
        guard networkMonitor.isConnected else {
            throw CalendarError.networkUnavailable
        }
        
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        let syncDateRange = dateRange ?? getDefaultSyncDateRange()
        
        // Step 1: Process pending local operations (25% of progress)
        try await processPendingLocalOperations(for: userId)
        
        // Step 2: Sync pending events to Apple Calendar (50% of progress)
        try await syncPendingEventsToAppleCalendar(userId: userId, config: config)
        
        // Step 3: Sync events from Apple Calendar to TribeBoard (75% of progress)
        try await syncEventsFromAppleCalendar(userId: userId, dateRange: syncDateRange, config: config)
        
        // Step 4: Detect and resolve conflicts (100% of progress)
        try await detectAndResolveConflicts(for: userId, in: syncDateRange, config: config)
        
        // Update sync configuration
        config.recordSuccessfulSync()
        try modelContext.save()
        
        print("✅ CalendarService: Full bidirectional sync completed")
    }
    
    /// Syncs a single event to Apple Calendar - centralized event sync
    func syncEventToAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        print("📤 CalendarService: Syncing event to Apple Calendar - '\(event.title)'")
        
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarService: Sync direction doesn't allow TribeBoard to Apple sync")
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
            
            print("✅ CalendarService: Successfully synced event to Apple Calendar")
            
        } catch {
            print("❌ CalendarService: Failed to sync event to Apple Calendar: \(error.localizedDescription)")
            
            // Record sync error in configuration
            config.recordSyncError("Event sync failed: \(error.localizedDescription)")
            try modelContext.save()
            
            throw error
        }
    }
    
    /// Updates an event in Apple Calendar - centralized event update
    func updateEventInAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        print("📝 CalendarService: Updating event in Apple Calendar - '\(event.title)'")
        
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarService: Sync direction doesn't allow TribeBoard to Apple sync")
            return
        }
        
        do {
            // Update in EventKit
            try await eventKitManager.updateEventInAppleCalendar(event)
            
            // Mark as synced
            event.needsEventKitSync = false
            
            // Save changes
            try modelContext.save()
            
            print("✅ CalendarService: Successfully updated event in Apple Calendar")
            
        } catch {
            print("❌ CalendarService: Failed to update event in Apple Calendar: \(error.localizedDescription)")
            
            // Record sync error in configuration
            config.recordSyncError("Event update failed: \(error.localizedDescription)")
            try modelContext.save()
            
            throw error
        }
    }
    
    /// Deletes an event from Apple Calendar - centralized event deletion
    func deleteEventFromAppleCalendar(_ event: CalendarEvent, userId: UUID) async throws {
        print("🗑️ CalendarService: Deleting event from Apple Calendar - '\(event.title)'")
        
        // Validate sync configuration
        let config = try validateSyncConfiguration(for: userId)
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarService: Sync direction doesn't allow TribeBoard to Apple sync")
            return
        }
        
        guard let eventKitIdentifier = event.eventKitIdentifier else {
            print("ℹ️ CalendarService: Event has no EventKit identifier, skipping Apple Calendar deletion")
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
            
            print("✅ CalendarService: Successfully deleted event from Apple Calendar")
            
        } catch {
            print("❌ CalendarService: Failed to delete event from Apple Calendar: \(error.localizedDescription)")
            
            // Record sync error in configuration
            config.recordSyncError("Event deletion failed: \(error.localizedDescription)")
            try modelContext.save()
            
            throw error
        }
    }
    
    /// Enables Apple Calendar sync for a user
    func enableAppleCalendarSync(userId: UUID) async throws {
        print("🔧 CalendarService: Enabling Apple Calendar sync")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Request EventKit access
            let hasAccess = try await eventKitManager.requestAccess()
            
            guard hasAccess else {
                throw CalendarSyncError.eventKitNotAvailable
            }
            
            // Set up TribeBoard calendars
            let calendars = try await eventKitManager.setupAllTribeBoardCalendars()
            
            // Get or create sync configuration
            let config = try getOrCreateSyncConfiguration(for: userId)
            
            // Enable sync with calendar identifiers
            config.enableAppleCalendarSync(
                calendarIdentifier: calendars.main.calendarIdentifier,
                familyCalendarIdentifier: calendars.family.calendarIdentifier,
                personalCalendarIdentifier: calendars.personal.calendarIdentifier
            )
            
            config.updateEventKitPermission(granted: true)
            
            // Save configuration
            try modelContext.save()
            
            print("✅ CalendarService: Apple Calendar sync enabled")
            
            // Perform initial sync
            try await syncWithAppleCalendar(userId: userId)
            
        } catch {
            self.error = error
            print("❌ CalendarService: Failed to enable Apple Calendar sync: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Disables Apple Calendar sync for a user
    func disableAppleCalendarSync(userId: UUID) async throws {
        print("🔧 CalendarService: Disabling Apple Calendar sync")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Get sync configuration
            guard let config = try getSyncConfiguration(for: userId) else {
                print("ℹ️ CalendarService: No sync configuration found, nothing to disable")
                return
            }
            
            // Disable sync
            config.disableAppleCalendarSync()
            
            // Save configuration
            try modelContext.save()
            
            print("✅ CalendarService: Apple Calendar sync disabled")
            
        } catch {
            self.error = error
            print("❌ CalendarService: Failed to disable Apple Calendar sync: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Comprehensive Validation Methods
    
    // MARK: - Centralized Service Dependencies (eliminates duplication)
    
    private lazy var validationService = CalendarEventValidationService(
        modelContext: modelContext,
        permissionManager: permissionManager
    )
    
    private lazy var businessRulesService = CalendarBusinessRulesService(
        modelContext: modelContext
    )
    
    private lazy var dataIntegrityService = CalendarDataIntegrityService(
        modelContext: modelContext
    )
    
    /// Validates an event for creation with comprehensive error handling
    private func validateEventForCreation(_ event: CalendarEvent, context: CalendarErrorContext) async throws {
        // Use comprehensive validation service
        let validationResult = try await validationService.validateEvent(
            event,
            operation: .create,
            context: context
        )
        
        // Check for validation errors
        if !validationResult.isValid {
            // Throw the first critical error found
            if let firstError = validationResult.errors.first {
                throw firstError
            }
        }
        
        // Log warnings but don't fail validation
        for warning in validationResult.warnings {
            CalendarErrorLogger.shared.logError(warning, context: context)
        }
        
        // Perform data integrity check
        let integrityIssues = try await dataIntegrityService.validateEventIntegrity(event)
        let criticalIntegrityIssues = integrityIssues.filter { $0.severity == .critical || $0.severity == .high }
        
        if !criticalIntegrityIssues.isEmpty {
            let issue = criticalIntegrityIssues.first!
            throw CalendarError.dataCorruption(issue.message)
        }
    }
    
    /// Validates an event for update with comprehensive error handling
    private func validateEventForUpdate(_ event: CalendarEvent, context: CalendarErrorContext) async throws {
        // Use comprehensive validation service
        let validationResult = try await validationService.validateEvent(
            event,
            operation: .update,
            context: context
        )
        
        // Check for validation errors
        if !validationResult.isValid {
            // Throw the first critical error found
            if let firstError = validationResult.errors.first {
                throw firstError
            }
        }
        
        // Log warnings but don't fail validation
        for warning in validationResult.warnings {
            CalendarErrorLogger.shared.logError(warning, context: context)
        }
        
        // Ensure event exists and is not deleted
        if event.isDeleted {
            throw CalendarError.eventModificationNotAllowed("Cannot update deleted event")
        }
        
        // Check if event exists in database
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == event.id }
        )
        
        do {
            let existingEvents = try modelContext.fetch(descriptor)
            if existingEvents.isEmpty {
                throw CalendarError.eventNotFound(event.id.uuidString)
            }
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "fetch event for validation",
                error: error.localizedDescription
            )
        }
    }
    
    /// Validates privacy level and permissions for an event
    private func validatePrivacyLevelAndPermissions(_ event: CalendarEvent, context: CalendarErrorContext) async throws {
        switch event.privacyLevel {
        case .personal:
            // Personal events don't need family ID but shouldn't have one
            if event.familyId != nil {
                throw CalendarError.invalidPrivacyLevel(
                    event.privacyLevel.rawValue,
                    context: "Personal events cannot have a family ID"
                )
            }
            
        case .familyShared:
            // Family events must have a family ID
            guard let familyId = event.familyId else {
                throw CalendarError.invalidPrivacyLevel(
                    event.privacyLevel.rawValue,
                    context: "Family shared events must have a valid family ID"
                )
            }
            
            // Validate family exists and user has access
            do {
                let hasAccess = try await validateFamilyAccess(
                    familyId: familyId,
                    userId: event.createdBy
                )
                
                if !hasAccess {
                    throw CalendarError.familyAccessDenied(
                        familyId: familyId.uuidString,
                        userId: event.createdBy.uuidString
                    )
                }
            } catch let calendarError as CalendarError {
                throw calendarError
            } catch {
                throw CalendarError.databaseOperationFailed(
                    operation: "validate family access",
                    error: error.localizedDescription
                )
            }
        }
    }
    
    /// Validates permissions for updating an event
    private func validateUpdatePermissions(for event: CalendarEvent, context: CalendarErrorContext) async throws {
        let userId = event.modifiedBy ?? event.createdBy
        
        switch event.privacyLevel {
        case .personal:
            // Personal events can only be updated by their creator
            if event.createdBy != userId {
                throw CalendarError.eventNotOwnedByUser(
                    eventId: event.id.uuidString,
                    userId: userId.uuidString
                )
            }
            
        case .familyShared:
            // Family events require proper permissions
            guard let familyId = event.familyId else {
                throw CalendarError.invalidPrivacyLevel(
                    event.privacyLevel.rawValue,
                    context: "Family shared event must have a family ID"
                )
            }
            
            // Check if user can modify family events
            let canModify = try await canModifyFamilyEvent(event, userId: userId)
            if !canModify {
                throw CalendarError.insufficientPermissions(
                    operation: "modify family event",
                    required: "event modify permission or event ownership"
                )
            }
        }
    }
    
    /// Validates permissions for deleting an event
    private func validateDeletePermissions(for event: CalendarEvent, context: CalendarErrorContext) async throws {
        let userId = event.modifiedBy ?? event.createdBy
        
        switch event.privacyLevel {
        case .personal:
            // Personal events can only be deleted by their creator
            if event.createdBy != userId {
                throw CalendarError.eventNotOwnedByUser(
                    eventId: event.id.uuidString,
                    userId: userId.uuidString
                )
            }
            
        case .familyShared:
            // Family events require proper permissions
            guard let familyId = event.familyId else {
                throw CalendarError.invalidPrivacyLevel(
                    event.privacyLevel.rawValue,
                    context: "Family shared event must have a family ID"
                )
            }
            
            // Check if user can delete family events
            let canDelete = try await canDeleteFamilyEvent(event, userId: userId)
            if !canDelete {
                throw CalendarError.insufficientPermissions(
                    operation: "delete family event",
                    required: "event delete permission or event ownership"
                )
            }
        }
    }
    
    /// Validates scheduling conflicts for an event
    private func validateSchedulingConflicts(_ event: CalendarEvent, context: CalendarErrorContext) async throws {
        // Only check conflicts for the event creator
        let userId = event.modifiedBy ?? event.createdBy
        
        // Fetch overlapping events for the user
        let startDate = event.startDate.addingTimeInterval(-1) // 1 second buffer
        let endDate = event.endDate.addingTimeInterval(1)
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { existingEvent in
                existingEvent.createdBy == userId &&
                existingEvent.id != event.id &&
                !existingEvent.isDeleted &&
                existingEvent.startDate < endDate &&
                existingEvent.endDate > startDate
            }
        )
        
        do {
            let conflictingEvents = try modelContext.fetch(descriptor)
            
            if !conflictingEvents.isEmpty {
                let conflictTitles = conflictingEvents.map { $0.title }
                throw CalendarError.schedulingConflict(conflictingEvents: conflictTitles)
            }
        } catch let calendarError as CalendarError {
            throw calendarError
        } catch {
            // Don't fail the operation for conflict check errors, just log
            CalendarErrorLogger.shared.logGenericError(
                error,
                operation: "validate scheduling conflicts",
                userId: userId.uuidString,
                eventId: event.id.uuidString
            )
        }
    }
    
    /// Validates that no duplicate event exists
    private func validateNoDuplicateEvent(_ event: CalendarEvent, context: CalendarErrorContext) async throws {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { existingEvent in
                existingEvent.title == event.title &&
                existingEvent.startDate == event.startDate &&
                existingEvent.endDate == event.endDate &&
                existingEvent.createdBy == event.createdBy &&
                existingEvent.id != event.id &&
                !existingEvent.isDeleted
            }
        )
        
        do {
            let duplicateEvents = try modelContext.fetch(descriptor)
            
            if let duplicate = duplicateEvents.first {
                throw CalendarError.duplicateEvent(existingEventId: duplicate.id.uuidString)
            }
        } catch let calendarError as CalendarError {
            throw calendarError
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "check for duplicate events",
                error: error.localizedDescription
            )
        }
    }
    
    /// Checks for scheduling conflicts with existing events
    private func checkForSchedulingConflicts(_ event: CalendarEvent) {
        // In a full implementation, this would check for overlapping events
        
        do {
            let descriptor = FetchDescriptor<CalendarEvent>()
            let allEvents = try modelContext.fetch(descriptor)
            
            let dateRange = DateInterval(start: event.startDate, end: event.endDate)
            let existingEvents = allEvents.filter { existingEvent in
                !existingEvent.isDeleted &&
                existingEvent.startDate >= dateRange.start &&
                existingEvent.startDate <= dateRange.end
            }
            
            let conflicts = existingEvents.filter { existingEvent in
                existingEvent.id != event.id && // Don't conflict with self
                existingEvent.createdBy == event.createdBy && // Only check user's own events
                eventsOverlap(event, existingEvent)
            }
            
            if !conflicts.isEmpty {
                print("⚠️ CalendarService: Potential scheduling conflicts detected with \(conflicts.count) events")
                // For now, we'll just warn. In a full implementation, this might throw an error
                // or provide conflict resolution options
            }
            
        } catch {
            // Don't fail event creation if conflict checking fails
            print("⚠️ CalendarService: Failed to check for scheduling conflicts: \(error.localizedDescription)")
        }
    }
    
    /// Checks if two events overlap in time
    private func eventsOverlap(_ event1: CalendarEvent, _ event2: CalendarEvent) -> Bool {
        let start1 = event1.startDate
        let end1 = event1.endDate
        let start2 = event2.startDate
        let end2 = event2.endDate
        
        // Events overlap if one starts before the other ends
        return start1 < end2 && start2 < end1
    }
    
    // MARK: - Helper Methods
    
    /// Gets the sync configuration for a user
    private func getSyncConfiguration(for userId: UUID) throws -> SyncConfiguration? {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let allConfigs = try modelContext.fetch(descriptor)
        
        return allConfigs.first { config in
            config.userId == userId
        }
    }
    
    /// Gets or creates a sync configuration for a user
    private func getOrCreateSyncConfiguration(for userId: UUID) throws -> SyncConfiguration {
        if let existingConfig = try getSyncConfiguration(for: userId) {
            return existingConfig
        }
        
        let newConfig = SyncConfiguration(userId: userId)
        modelContext.insert(newConfig)
        return newConfig
    }
    
    /// Determines if an event should be synced to Apple Calendar
    private func shouldSyncToAppleCalendar(_ event: CalendarEvent) -> Bool {
        // Check if the event can be synced
        guard event.canSyncToEventKit else {
            return false
        }
        
        // Check if sync is enabled for the user
        do {
            guard let config = try getSyncConfiguration(for: event.createdBy) else {
                return false
            }
            
            return config.isAppleCalendarSyncEnabled && config.isSyncConfigured
        } catch {
            print("⚠️ CalendarService: Failed to check sync configuration: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Sync Status
    
    /// Gets the sync status for a user
    func getSyncStatus(for userId: UUID) throws -> CalendarSyncStatus {
        return try calendarSyncService.getSyncStatus(for: userId)
    }
    
    /// Checks if sync is needed for a user
    func isSyncNeeded(for userId: UUID) throws -> Bool {
        return try calendarSyncService.isSyncNeeded(for: userId)
    }
    
    // MARK: - Error Handling Helper Methods
    
    /// Handles event sync with comprehensive error handling
    private func handleEventSyncWithErrorHandling(
        _ event: CalendarEvent,
        operation: SyncOperationType,
        context: CalendarErrorContext
    ) async {
        if networkMonitor.isConnected {
            // Online - sync immediately using centralized methods
            do {
                switch operation {
                case .create:
                    try await syncEventToAppleCalendar(event, userId: event.createdBy)
                case .update:
                    try await updateEventInAppleCalendar(event, userId: event.createdBy)
                case .delete:
                    try await deleteEventFromAppleCalendar(event, userId: event.createdBy)
                case .sync:
                    // Full sync operation
                    try await performFullBidirectionalSync(for: event.createdBy)
                }
                print("✅ CalendarService: Event synced to Apple Calendar")
            } catch {
                let syncError = CalendarError.syncOperationFailed(
                    operation: operation.rawValue,
                    reason: error.localizedDescription
                )
                CalendarErrorLogger.shared.logError(syncError, context: context)
                print("⚠️ CalendarService: Failed to sync to Apple Calendar, queuing for retry: \(error.localizedDescription)")
                
                // Queue for retry
                queueEventForSync(event, operation: operation, userId: event.createdBy)
            }
        } else {
            // Offline - queue for later sync
            let networkError = CalendarError.networkUnavailable
            CalendarErrorLogger.shared.logError(networkError, context: context)
            print("📱 CalendarService: Offline - queuing event for sync when connection is restored")
            queueEventForSync(event, operation: operation, userId: event.createdBy)
        }
    }
    
    // MARK: - Centralized Sync Queue Management
    
    /// Queues an event for sync - centralized queue management
    func queueEventForSync(_ event: CalendarEvent, operation: SyncOperationType, userId: UUID) {
        // Delegate to sync manager for now, but centralize the interface
        syncManager.queueEventForSync(event, operation: operation, userId: userId)
        
        print("📝 CalendarService: Queued \(operation.displayName) for event '\(event.title)'")
    }
    
    // MARK: - Private Sync Implementation Methods
    
    /// Validates sync configuration and ensures it's properly set up - uses centralized validation
    private func validateSyncConfiguration(for userId: UUID) throws -> SyncConfiguration {
        // Use centralized validation service to eliminate duplication
        return try validationService.validateSyncConfiguration(for: userId)
    }
    
    /// Processes pending local operations before sync
    private func processPendingLocalOperations(for userId: UUID) async throws {
        print("📤 CalendarService: Processing pending local operations for user: \(userId)")
        
        // Get events that need sync
        let pendingEvents = try getPendingEventKitSyncEvents(for: userId)
        
        guard !pendingEvents.isEmpty else {
            print("ℹ️ CalendarService: No pending local operations")
            return
        }
        
        print("📊 CalendarService: Found \(pendingEvents.count) pending local operations")
        
        // Process each pending event
        for event in pendingEvents {
            do {
                if event.isDeleted {
                    // Handle deleted events
                    if let eventKitId = event.eventKitIdentifier {
                        try await eventKitManager.deleteEventFromAppleCalendar(eventKitId)
                    }
                    event.needsEventKitSync = false
                } else if event.eventKitIdentifier != nil {
                    // Update existing event
                    try await updateEventInAppleCalendar(event, userId: userId)
                } else {
                    // Create new event
                    try await syncEventToAppleCalendar(event, userId: userId)
                }
            } catch {
                print("⚠️ CalendarService: Failed to process pending operation for event '\(event.title)': \(error.localizedDescription)")
                // Continue with other events
            }
        }
        
        // Save all changes
        try modelContext.save()
        
        print("✅ CalendarService: Completed processing pending local operations")
    }
    
    /// Syncs all pending events to Apple Calendar
    private func syncPendingEventsToAppleCalendar(userId: UUID, config: SyncConfiguration) async throws {
        print("📤 CalendarService: Syncing pending events to Apple Calendar")
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .tribeBoardToApple else {
            print("ℹ️ CalendarService: Sync direction doesn't allow TribeBoard to Apple sync")
            return
        }
        
        // Get pending events
        let pendingEvents = try getPendingEventKitSyncEvents(for: userId)
        
        guard !pendingEvents.isEmpty else {
            print("ℹ️ CalendarService: No pending events to sync")
            return
        }
        
        print("📊 CalendarService: Found \(pendingEvents.count) pending events")
        
        var successCount = 0
        var errors: [String] = []
        
        // Sync events one by one
        for event in pendingEvents {
            do {
                if event.isDeleted {
                    try await deleteEventFromAppleCalendar(event, userId: userId)
                } else if event.eventKitIdentifier != nil {
                    try await updateEventInAppleCalendar(event, userId: userId)
                } else {
                    try await syncEventToAppleCalendar(event, userId: userId)
                }
                
                successCount += 1
                
            } catch {
                errors.append("Event '\(event.title)': \(error.localizedDescription)")
            }
        }
        
        // Save all changes
        try modelContext.save()
        
        print("✅ CalendarService: Pending events sync completed - \(successCount) successful, \(errors.count) failed")
        
        if !errors.isEmpty {
            config.recordSyncError("Batch sync partially failed: \(errors.joined(separator: "; "))")
            try modelContext.save()
            throw CalendarError.batchSyncFailed(errors)
        }
    }
    
    /// Retrieves events from Apple Calendar and syncs to TribeBoard
    private func syncEventsFromAppleCalendar(userId: UUID, dateRange: DateInterval, config: SyncConfiguration) async throws {
        print("📥 CalendarService: Syncing events from Apple Calendar")
        
        // Check sync direction
        guard config.syncDirection == .bidirectional || config.syncDirection == .appleToTribeBoard else {
            print("ℹ️ CalendarService: Sync direction doesn't allow Apple to TribeBoard sync")
            return
        }
        
        // Fetch events from Apple Calendar
        let appleEvents = try await eventKitManager.fetchEventsFromAppleCalendar(for: dateRange)
        
        guard !appleEvents.isEmpty else {
            print("ℹ️ CalendarService: No events found in Apple Calendar")
            return
        }
        
        print("📊 CalendarService: Found \(appleEvents.count) events in Apple Calendar")
        
        // Get existing TribeBoard events
        let existingEvents = try getExistingCalendarEvents(for: userId, in: dateRange)
        
        var processedCount = 0
        var errors: [String] = []
        
        // Process each Apple Calendar event
        for appleEvent in appleEvents {
            do {
                try processAppleCalendarEvent(appleEvent, existingEvents: existingEvents, userId: userId, config: config)
                processedCount += 1
            } catch {
                errors.append("Event '\(appleEvent.title ?? "Untitled")': \(error.localizedDescription)")
            }
        }
        
        // Save all changes
        try modelContext.save()
        
        print("✅ CalendarService: Apple Calendar sync completed - \(processedCount) processed, \(errors.count) failed")
        
        if !errors.isEmpty {
            config.recordSyncError("Apple Calendar sync partially failed: \(errors.joined(separator: "; "))")
            try modelContext.save()
            throw CalendarError.batchSyncFailed(errors)
        }
    }
    
    /// Detects and resolves conflicts between local and Apple Calendar events
    private func detectAndResolveConflicts(for userId: UUID, in dateRange: DateInterval, config: SyncConfiguration) async throws {
        print("🔍 CalendarService: Detecting conflicts for user: \(userId)")
        
        // Get local events
        let localEvents = try getExistingCalendarEvents(for: userId, in: dateRange)
        
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
            print("⚠️ CalendarService: Found \(conflicts.count) conflicts")
            
            // Resolve conflicts based on configuration
            for conflict in conflicts {
                try await resolveConflict(conflict, strategy: config.syncConflictResolution, userId: userId)
            }
        }
        
        print("✅ CalendarService: Conflict detection completed")
    }
    
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
                    let conflict = SyncConflict(
                        localEvent: existingEvent,
                        appleEvent: appleEvent,
                        conflictType: .modificationConflict,
                        detectedAt: Date()
                    )
                    try Task { @MainActor in
                        try await resolveConflict(conflict, strategy: config.syncConflictResolution, userId: userId)
                    }.value
                } else {
                    // Apple Calendar event is newer - update TribeBoard event
                    existingEvent.updateFromEKEvent(appleEvent, modifiedBy: userId)
                }
            } else {
                // TribeBoard event not found - it may have been deleted
                print("⚠️ CalendarService: TribeBoard event not found for Apple Calendar event")
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
    
    /// Resolves sync conflicts between local and remote events
    private func resolveConflict(
        _ conflict: SyncConflict,
        strategy: SyncConfiguration.ConflictResolutionStrategy,
        userId: UUID
    ) async throws {
        
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
            print("⚠️ CalendarService: User resolution not implemented, using last modified wins")
            try await resolveConflict(conflict, strategy: .lastModifiedWins, userId: userId)
        }
        
        print("✅ CalendarService: Conflict resolved")
    }
    
    /// Gets the default sync date range
    private func getDefaultSyncDateRange() -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let end = calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        return DateInterval(start: start, end: end)
    }
    
    /// Validates family access for a user
    private func validateFamilyAccess(familyId: UUID, userId: UUID) async throws -> Bool {
        // This would integrate with the family service when available
        // For now, we'll assume access is valid if family ID is provided
        // In a real implementation, this would check family membership
        return true
    }
    
    /// Checks if user can delete a family event
    private func canDeleteFamilyEvent(_ event: CalendarEvent, userId: UUID) async throws -> Bool {
        // Event creator can always delete their own events
        if event.createdBy == userId {
            return true
        }
        
        // Check if user has admin permissions for the family
        guard let familyId = event.familyId else {
            return false
        }
        
        return try await permissionManager.hasPermission(
            userId: userId,
            familyId: familyId,
            permission: .deleteEvents
        )
    }
    
    // MARK: - Performance Optimization Methods
    
    /// Searches events with optimized text search
    func searchEvents(
        searchText: String,
        dateRange: DateInterval? = nil,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        limit: Int = 50
    ) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Searching events with text: '\(searchText)'")
        
        return try await performanceService.searchEventsOptimized(
            searchText: searchText,
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            limit: limit
        )
    }
    
    /// Gets calendar statistics with optimized aggregation
    func getCalendarStatistics(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil
    ) async throws -> CalendarAggregateStats {
        print("📈 CalendarService: Getting calendar statistics")
        
        return try await performanceService.getCalendarStatistics(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId
        )
    }
    
    /// Finds conflicting events efficiently
    func findConflictingEvents(
        for event: CalendarEvent,
        userId: UUID? = nil
    ) async throws -> [CalendarEvent] {
        print("🔍 CalendarService: Finding conflicting events")
        
        return try await performanceService.findConflictingEvents(
            for: event,
            userId: userId
        )
    }
    
    /// Preloads events around a date for better performance
    func preloadEvents(around date: Date, userId: UUID? = nil, familyId: UUID? = nil) async {
        await performanceService.preloadEvents(around: date, userId: userId, familyId: familyId)
    }
    
    /// Processes events in batches for large datasets
    func processBatchOperation(
        dateRange: DateInterval,
        batchSize: Int = 100,
        processor: @escaping ([CalendarEvent]) async throws -> Void
    ) async throws {
        try await performanceService.processBatchOperation(
            dateRange: dateRange,
            batchSize: batchSize,
            processor: processor
        )
    }
    
    /// Invalidates cache for specific criteria
    func invalidateCache(userId: UUID? = nil, familyId: UUID? = nil, eventId: UUID? = nil) {
        performanceService.invalidateCache(userId: userId, familyId: familyId, eventId: eventId)
    }
    
    /// Gets comprehensive performance metrics
    func getPerformanceMetrics() -> ComprehensivePerformanceMetrics {
        return performanceService.getPerformanceMetrics()
    }
    
    /// Optimizes performance based on usage patterns
    func optimizePerformance() async {
        await performanceService.optimizePerformance()
    }
    
    /// Processes background sync operations - delegates to CalendarBackgroundSyncProcessor
    func processBackgroundSync() async {
        print("🔄 CalendarService: Delegating background sync to CalendarBackgroundSyncProcessor")
        
        // Get the background processor from performance service
        await performanceService.processBackgroundSync()
    }
    
    /// Schedules background sync - delegates to CalendarBackgroundSyncProcessor
    func scheduleBackgroundSync() {
        print("⏰ CalendarService: Delegating background sync scheduling to CalendarBackgroundSyncProcessor")
        
        performanceService.scheduleBackgroundSync()
    }
    
    /// Processes comprehensive background operations
    func processComprehensiveBackgroundOperations() async {
        print("🔄 CalendarService: Starting comprehensive background operations")
        
        // Delegate to performance service which coordinates with background processor
        await performanceService.processBackgroundSync()
    }
}

// MARK: - Supporting Types

/// Types of sync operations
enum SyncOperationType: String, Codable, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case sync = "sync"
    
    var displayName: String {
        switch self {
        case .create:
            return "Create"
        case .update:
            return "Update"
        case .delete:
            return "Delete"
        case .sync:
            return "Sync"
        }
    }
    
    var priority: Int {
        switch self {
        case .delete:
            return 3 // Highest priority
        case .update:
            return 2
        case .create:
            return 1
        case .sync:
            return 1 // Lowest priority
        }
    }
}

/// Represents a sync operation to be processed
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let type: SyncOperationType
    let eventId: UUID?
    let timestamp: Date
    let userId: UUID
    var retryCount: Int
    let status: SyncStatus
    
    init(
        id: UUID = UUID(),
        type: SyncOperationType,
        eventId: UUID? = nil,
        timestamp: Date = Date(),
        userId: UUID,
        retryCount: Int = 0,
        status: SyncStatus = .pending
    ) {
        self.id = id
        self.type = type
        self.eventId = eventId
        self.timestamp = timestamp
        self.userId = userId
        self.retryCount = retryCount
        self.status = status
    }
}

/// Status of a sync operation
enum SyncStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

/// Represents the result of a validation operation
struct ValidationResult: Codable {
    var errors: [CalendarError] = []
    var warnings: [CalendarError] = []
    let message: String?
    
    var isValid: Bool {
        return errors.isEmpty
    }
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var allIssues: [CalendarError] {
        return errors + warnings
    }
    
    init(errors: [CalendarError] = [], warnings: [CalendarError] = [], message: String? = nil) {
        self.errors = errors
        self.warnings = warnings
        self.message = message
    }
    
    /// Creates a successful validation result
    static func success(message: String? = nil) -> ValidationResult {
        return ValidationResult(message: message)
    }
    
    /// Creates a failed validation result with errors
    static func failure(errors: [CalendarError], message: String? = nil) -> ValidationResult {
        return ValidationResult(errors: errors, message: message)
    }
}

/// Represents a validation issue with detailed information
struct ValidationIssue: Identifiable, Codable {
    let id = UUID()
    let type: ValidationIssueType
    let message: String
    let field: String?
    let severity: ValidationSeverity
    let suggestion: String?
    let timestamp: Date = Date()
    
    init(
        type: ValidationIssueType,
        message: String,
        field: String? = nil,
        severity: ValidationSeverity = .error,
        suggestion: String? = nil
    ) {
        self.type = type
        self.message = message
        self.field = field
        self.severity = severity
        self.suggestion = suggestion
    }
}

/// Types of validation issues
enum ValidationIssueType: String, CaseIterable, Codable {
    case required = "required"
    case format = "format"
    case range = "range"
    case conflict = "conflict"
    case permission = "permission"
    case businessRule = "business_rule"
    
    var displayName: String {
        switch self {
        case .required:
            return "Required Field"
        case .format:
            return "Invalid Format"
        case .range:
            return "Out of Range"
        case .conflict:
            return "Scheduling Conflict"
        case .permission:
            return "Permission Issue"
        case .businessRule:
            return "Business Rule Violation"
        }
    }
}

/// Severity levels for validation issues
enum ValidationSeverity: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical"
        }
    }
}

/// Priority levels for calendar error recovery operations
enum CalendarErrorRecoveryPriority: Int, CaseIterable, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Can be handled later without immediate impact"
        case .medium:
            return "Should be addressed soon to prevent issues"
        case .high:
            return "Requires prompt attention to maintain functionality"
        case .critical:
            return "Must be resolved immediately to prevent data loss or corruption"
        }
    }
}

/**
 * SyncStatusInfo - Comprehensive sync status information
 * 
 * This struct was completed during compilation error fixes to resolve incomplete
 * type definition issues. It provides a complete picture of calendar sync status
 * including network state, sync progress, and error information.
 * 
 * Key Properties:
 * - isOnline: Network connectivity status
 * - isSyncing: Whether sync is currently in progress
 * - syncProgress: Progress percentage (0.0 to 1.0)
 * - pendingOperations: Number of operations waiting to sync
 * - offlineStatistics: Detailed offline operation statistics
 * - syncError: Any error message from sync operations
 * 
 * Computed Properties:
 * - statusDescription: Human-readable status summary
 * - healthStatus: Overall sync health indicator
 */
struct SyncStatusInfo: Codable {
    let isOnline: Bool
    let isSyncing: Bool
    let syncProgress: Double
    let lastSyncDate: Date?
    let pendingOperations: Int
    let offlineStatistics: OfflineStatistics
    let syncError: String?
    
    var statusDescription: String {
        if !isOnline {
            return "Offline (\(pendingOperations) pending)"
        } else if isSyncing {
            return "Syncing... (\(Int(syncProgress * 100))%)"
        } else if pendingOperations > 0 {
            return "Pending (\(pendingOperations) operations)"
        } else if let error = syncError {
            return "Error: \(error)"
        } else {
            return "Up to date"
        }
    }
    
    var healthStatus: SyncHealthStatus {
        if !isOnline {
            return .offline
        } else if let _ = syncError {
            return .error
        } else if pendingOperations > 0 {
            return .syncing
        } else {
            return .healthy
        }
    }
    
    enum SyncHealthStatus: Codable {
        case healthy
        case syncing
        case offline
        case error
        
        var color: String {
            switch self {
            case .healthy:
                return "green"
            case .syncing:
                return "blue"
            case .offline:
                return "orange"
            case .error:
                return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .healthy:
                return "checkmark.circle.fill"
            case .syncing:
                return "arrow.triangle.2.circlepath"
            case .offline:
                return "wifi.slash"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }
}