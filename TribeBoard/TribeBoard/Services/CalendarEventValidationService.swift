import Foundation
import SwiftData

/// Centralized validation service for all calendar operations
/// This service consolidates validation logic to eliminate duplication across services
@MainActor
class CalendarEventValidationService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let permissionManager: CalendarPermissionManager
    
    // Validation configuration
    private let maxEventTitleLength = 200
    private let maxLocationLength = 200
    private let maxNotesLength = 1000
    private let minEventDuration: TimeInterval = 900 // 15 minutes
    private let maxTimedEventDuration: TimeInterval = 86400 // 24 hours
    private let maxAllDayEventDuration: TimeInterval = 2592000 // 30 days
    private let maxFutureYears = 2
    private let maxEventsPerDay = 50
    private let maxFamilyEventsPerMonth = 200
    
    @Published var validationErrors: [CalendarError] = []
    @Published var validationWarnings: [CalendarError] = []
    @Published var isValidating = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, permissionManager: CalendarPermissionManager) {
        self.modelContext = modelContext
        self.permissionManager = permissionManager
    }
    
    // MARK: - Comprehensive Event Validation
    
    /// Validates an event comprehensively with all business rules
    func validateEvent(
        _ event: CalendarEvent,
        operation: ValidationOperation,
        context: CalendarErrorContext
    ) async throws -> ValidationResult {
        isValidating = true
        validationErrors = []
        validationWarnings = []
        
        defer {
            isValidating = false
        }
        
        var result = ValidationResult()
        
        // Basic field validation
        try await validateBasicFields(event, result: &result, context: context)
        
        // Date and time validation
        try await validateDateAndTime(event, result: &result, context: context)
        
        // Duration validation
        try await validateDuration(event, result: &result, context: context)
        
        // Privacy and permission validation
        try await validatePrivacyAndPermissions(event, operation: operation, result: &result, context: context)
        
        // Business rules validation
        try await validateBusinessRules(event, operation: operation, result: &result, context: context)
        
        // Scheduling conflict validation
        try await validateSchedulingConflicts(event, operation: operation, result: &result, context: context)
        
        // Data integrity validation
        try await validateDataIntegrity(event, operation: operation, result: &result, context: context)
        
        // Update published properties
        validationErrors = result.errors
        validationWarnings = result.warnings
        
        return result
    }
    
    /// Validates event title with comprehensive rules
    func validateEventTitle(_ title: String) -> [CalendarError] {
        var errors: [CalendarError] = []
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Required field validation
        if trimmedTitle.isEmpty {
            errors.append(.invalidEventTitle("Event title is required"))
        }
        
        // Length validation
        if trimmedTitle.count > maxEventTitleLength {
            errors.append(.invalidEventTitle("Title exceeds \(maxEventTitleLength) characters"))
        }
        
        // Content validation
        if trimmedTitle.contains(where: { $0.isNewline }) {
            errors.append(.invalidEventTitle("Title cannot contain line breaks"))
        }
        
        // Profanity and inappropriate content check
        if containsInappropriateContent(trimmedTitle) {
            errors.append(.invalidEventTitle("Title contains inappropriate content"))
        }
        
        return errors
    }
    
    /// Validates event dates with business rules
    func validateEventDates(startDate: Date, endDate: Date, isAllDay: Bool) -> [CalendarError] {
        var errors: [CalendarError] = []
        
        // Basic date validation
        if endDate <= startDate {
            errors.append(.invalidEventDates("End date must be after start date"))
        }
        
        // Past date validation (with grace period)
        let gracePeriod: TimeInterval = 300 // 5 minutes
        if startDate < Date().addingTimeInterval(-gracePeriod) {
            errors.append(.eventInPast(startDate))
        }
        
        // Future date validation
        let maxFutureDate = Calendar.current.date(byAdding: .year, value: maxFutureYears, to: Date()) ?? Date()
        if startDate > maxFutureDate {
            errors.append(.eventTooFarInFuture(startDate, maximum: maxFutureDate))
        }
        
        // All-day event date validation
        if isAllDay {
            let calendar = Calendar.current
            let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
            
            // Ensure all-day events start and end at midnight
            if !calendar.date(startDate, matchesComponents: DateComponents(hour: 0, minute: 0, second: 0)) ||
               !calendar.date(endDate, matchesComponents: DateComponents(hour: 0, minute: 0, second: 0)) {
                errors.append(.invalidEventDates("All-day events must start and end at midnight"))
            }
        }
        
        return errors
    }
    
    /// Validates event duration with business rules
    func validateEventDuration(startDate: Date, endDate: Date, isAllDay: Bool) -> [CalendarError] {
        var errors: [CalendarError] = []
        
        let duration = endDate.timeIntervalSince(startDate)
        
        if isAllDay {
            // All-day event duration validation
            if duration > maxAllDayEventDuration {
                errors.append(.eventDurationTooLong(duration, maximum: maxAllDayEventDuration))
            }
        } else {
            // Timed event duration validation
            if duration < minEventDuration {
                errors.append(.eventDurationTooShort(duration, minimum: minEventDuration))
            }
            
            if duration > maxTimedEventDuration {
                errors.append(.eventDurationTooLong(duration, maximum: maxTimedEventDuration))
            }
        }
        
        return errors
    }
    
    /// Validates location field
    func validateLocation(_ location: String?) -> [CalendarError] {
        var errors: [CalendarError] = []
        
        if let location = location, !location.isEmpty {
            if location.count > maxLocationLength {
                errors.append(.invalidLocation("Location exceeds \(maxLocationLength) characters"))
            }
            
            // Check for inappropriate content
            if containsInappropriateContent(location) {
                errors.append(.invalidLocation("Location contains inappropriate content"))
            }
        }
        
        return errors
    }
    
    /// Validates notes field
    func validateNotes(_ notes: String?) -> [CalendarError] {
        var errors: [CalendarError] = []
        
        if let notes = notes, !notes.isEmpty {
            if notes.count > maxNotesLength {
                errors.append(.invalidNotes("Notes exceed \(maxNotesLength) characters"))
            }
            
            // Check for inappropriate content
            if containsInappropriateContent(notes) {
                errors.append(.invalidNotes("Notes contain inappropriate content"))
            }
        }
        
        return errors
    }
    
    // MARK: - Business Rules Validation
    
    /// Validates business rules for event creation/modification
    private func validateBusinessRules(
        _ event: CalendarEvent,
        operation: ValidationOperation,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        
        // Daily event limit validation
        try await validateDailyEventLimit(event, result: &result, context: context)
        
        // Family event monthly limit validation
        if event.privacyLevel == .familyShared {
            try await validateFamilyEventMonthlyLimit(event, result: &result, context: context)
        }
        
        // Event capacity validation (for family events)
        if event.privacyLevel == .familyShared {
            try await validateFamilyEventCapacity(event, result: &result, context: context)
        }
        
        // Duplicate event validation
        if operation == .create {
            try await validateNoDuplicateEvent(event, result: &result, context: context)
        }
        
        // Event modification rules
        if operation == .update {
            try await validateEventModificationRules(event, result: &result, context: context)
        }
        
        // Privacy level change validation
        try await validatePrivacyLevelChange(event, operation: operation, result: &result, context: context)
    }
    
    /// Validates daily event limit for a user
    private func validateDailyEventLimit(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: event.startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? event.startDate
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { existingEvent in
                existingEvent.createdBy == event.createdBy &&
                existingEvent.id != event.id &&
                !existingEvent.isDeleted &&
                existingEvent.startDate >= startOfDay &&
                existingEvent.startDate < endOfDay
            }
        )
        
        do {
            let eventsOnDay = try modelContext.fetch(descriptor)
            
            if eventsOnDay.count >= maxEventsPerDay {
                result.errors.append(.eventCapacityExceeded(
                    current: eventsOnDay.count,
                    maximum: maxEventsPerDay
                ))
            } else if eventsOnDay.count >= maxEventsPerDay - 5 {
                // Warning when approaching limit
                result.warnings.append(.eventCapacityExceeded(
                    current: eventsOnDay.count,
                    maximum: maxEventsPerDay
                ))
            }
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate daily event limit",
                error: error.localizedDescription
            )
        }
    }
    
    /// Validates monthly family event limit
    private func validateFamilyEventMonthlyLimit(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        guard let familyId = event.familyId else { return }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: event.startDate)?.start ?? event.startDate
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? event.startDate
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { existingEvent in
                existingEvent.familyId == familyId &&
                existingEvent.id != event.id &&
                !existingEvent.isDeleted &&
                existingEvent.startDate >= startOfMonth &&
                existingEvent.startDate < endOfMonth
            }
        )
        
        do {
            let familyEventsInMonth = try modelContext.fetch(descriptor)
            
            if familyEventsInMonth.count >= maxFamilyEventsPerMonth {
                result.errors.append(.familyEventLimitExceeded(
                    current: familyEventsInMonth.count,
                    maximum: maxFamilyEventsPerMonth
                ))
            } else if familyEventsInMonth.count >= maxFamilyEventsPerMonth - 10 {
                // Warning when approaching limit
                result.warnings.append(.familyEventLimitExceeded(
                    current: familyEventsInMonth.count,
                    maximum: maxFamilyEventsPerMonth
                ))
            }
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate family event monthly limit",
                error: error.localizedDescription
            )
        }
    }
    
    /// Validates family event capacity
    private func validateFamilyEventCapacity(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        // This would validate against family size and event capacity rules
        // For now, we'll implement a basic check
        
        guard let familyId = event.familyId else { return }
        
        // Check if family has too many concurrent events
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { existingEvent in
                existingEvent.familyId == familyId &&
                existingEvent.id != event.id &&
                !existingEvent.isDeleted &&
                existingEvent.startDate < event.endDate &&
                existingEvent.endDate > event.startDate
            }
        )
        
        do {
            let concurrentEvents = try modelContext.fetch(descriptor)
            let maxConcurrentEvents = 10 // Business rule: max 10 concurrent family events
            
            if concurrentEvents.count >= maxConcurrentEvents {
                result.errors.append(.eventCapacityExceeded(
                    current: concurrentEvents.count,
                    maximum: maxConcurrentEvents
                ))
            }
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate family event capacity",
                error: error.localizedDescription
            )
        }
    }
    
    /// Validates no duplicate events exist
    private func validateNoDuplicateEvent(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
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
                result.errors.append(.duplicateEvent(existingEventId: duplicate.id.uuidString))
            }
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate duplicate events",
                error: error.localizedDescription
            )
        }
    }
    
    /// Validates event modification rules
    private func validateEventModificationRules(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        // Check if event is in the past and modification is allowed
        if event.startDate < Date() {
            // Allow modification of past events only within 24 hours
            let modificationCutoff = event.startDate.addingTimeInterval(86400) // 24 hours
            if Date() > modificationCutoff {
                result.errors.append(.eventModificationNotAllowed(
                    "Cannot modify events more than 24 hours after they started"
                ))
            }
        }
        
        // Check if event is currently in progress
        let now = Date()
        if event.startDate <= now && event.endDate > now {
            // Only allow certain modifications for in-progress events
            result.warnings.append(.eventModificationNotAllowed(
                "Event is currently in progress - some changes may not sync immediately"
            ))
        }
    }
    
    /// Validates privacy level changes
    private func validatePrivacyLevelChange(
        _ event: CalendarEvent,
        operation: ValidationOperation,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        if operation == .update {
            // Fetch original event to compare privacy levels
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.id == event.id }
            )
            
            do {
                let existingEvents = try modelContext.fetch(descriptor)
                if let existingEvent = existingEvents.first {
                    if existingEvent.privacyLevel != event.privacyLevel {
                        // Privacy level is changing - validate the change
                        if existingEvent.privacyLevel == .familyShared && event.privacyLevel == .personal {
                            // Changing from family to personal - check permissions
                            if existingEvent.createdBy != event.createdBy {
                                result.errors.append(.insufficientPermissions(
                                    operation: "change event privacy level",
                                    required: "event ownership"
                                ))
                            }
                        } else if existingEvent.privacyLevel == .personal && event.privacyLevel == .familyShared {
                            // Changing from personal to family - validate family access
                            if event.familyId == nil {
                                result.errors.append(.invalidPrivacyLevel(
                                    event.privacyLevel.rawValue,
                                    context: "Family shared events require a family ID"
                                ))
                            }
                        }
                    }
                }
            } catch {
                throw CalendarError.databaseOperationFailed(
                    operation: "validate privacy level change",
                    error: error.localizedDescription
                )
            }
        }
    }
    
    // MARK: - Private Validation Methods
    
    private func validateBasicFields(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        // Title validation
        result.errors.append(contentsOf: validateEventTitle(event.title))
        
        // Location validation
        result.errors.append(contentsOf: validateLocation(event.location))
        
        // Notes validation
        result.errors.append(contentsOf: validateNotes(event.notes))
    }
    
    private func validateDateAndTime(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        result.errors.append(contentsOf: validateEventDates(
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay
        ))
    }
    
    private func validateDuration(
        _ event: CalendarEvent,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        result.errors.append(contentsOf: validateEventDuration(
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay
        ))
    }
    
    private func validatePrivacyAndPermissions(
        _ event: CalendarEvent,
        operation: ValidationOperation,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        switch event.privacyLevel {
        case .personal:
            // Personal events shouldn't have family ID
            if event.familyId != nil {
                result.errors.append(.invalidPrivacyLevel(
                    event.privacyLevel.rawValue,
                    context: "Personal events cannot have a family ID"
                ))
            }
            
        case .familyShared:
            // Family events must have family ID
            guard let familyId = event.familyId else {
                result.errors.append(.invalidPrivacyLevel(
                    event.privacyLevel.rawValue,
                    context: "Family shared events must have a valid family ID"
                ))
                return
            }
            
            // Validate user has permission to create/modify family events
            let userId = event.modifiedBy ?? event.createdBy
            let hasPermission = try await permissionManager.hasPermission(
                userId: userId,
                familyId: familyId,
                permission: operation == .create ? .createEvents : .modifyEvents
            )
            
            if !hasPermission {
                result.errors.append(.insufficientPermissions(
                    operation: operation == .create ? "create family event" : "modify family event",
                    required: "calendar \(operation.rawValue) permission"
                ))
            }
        }
    }
    
    private func validateSchedulingConflicts(
        _ event: CalendarEvent,
        operation: ValidationOperation,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        let userId = event.modifiedBy ?? event.createdBy
        
        // Check for overlapping events for the same user
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { existingEvent in
                existingEvent.createdBy == userId &&
                existingEvent.id != event.id &&
                !existingEvent.isDeleted &&
                existingEvent.startDate < event.endDate &&
                existingEvent.endDate > event.startDate
            }
        )
        
        do {
            let conflictingEvents = try modelContext.fetch(descriptor)
            
            if !conflictingEvents.isEmpty {
                let conflictTitles = conflictingEvents.map { $0.title }
                
                // Determine if this is a hard conflict or just a warning
                let hasHardConflict = conflictingEvents.contains { conflictingEvent in
                    // Hard conflict: exact time overlap for non-all-day events
                    !event.isAllDay && !conflictingEvent.isAllDay &&
                    event.startDate < conflictingEvent.endDate &&
                    event.endDate > conflictingEvent.startDate
                }
                
                if hasHardConflict {
                    result.errors.append(.schedulingConflict(conflictingEvents: conflictTitles))
                } else {
                    result.warnings.append(.schedulingConflict(conflictingEvents: conflictTitles))
                }
            }
        } catch {
            // Don't fail validation for conflict check errors, just log
            CalendarErrorLogger.shared.logGenericError(
                error,
                operation: "validate scheduling conflicts",
                userId: userId.uuidString,
                eventId: event.id.uuidString
            )
        }
    }
    
    private func validateDataIntegrity(
        _ event: CalendarEvent,
        operation: ValidationOperation,
        result: inout ValidationResult,
        context: CalendarErrorContext
    ) async throws {
        // Validate UUID format
        if event.id.uuidString.isEmpty {
            result.errors.append(.dataCorruption("Invalid event ID"))
        }
        
        if event.createdBy.uuidString.isEmpty {
            result.errors.append(.dataCorruption("Invalid creator ID"))
        }
        
        if let familyId = event.familyId, familyId.uuidString.isEmpty {
            result.errors.append(.dataCorruption("Invalid family ID"))
        }
        
        // Validate required timestamps
        if operation == .update && event.lastModified < event.createdAt {
            result.errors.append(.dataCorruption("Last modified date cannot be before creation date"))
        }
    }
    
    // MARK: - Centralized Validation Methods (eliminates duplication)
    
    /// Centralized sync configuration validation - used by all sync services
    func validateSyncConfiguration(for userId: UUID) throws -> SyncConfiguration {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let allConfigs = try modelContext.fetch(descriptor)
        
        guard let config = allConfigs.first(where: { $0.userId == userId }) else {
            throw CalendarError.syncConfigurationNotFound
        }
        
        guard config.isAppleCalendarSyncEnabled else {
            throw CalendarError.syncDisabled
        }
        
        guard config.isSyncConfigured else {
            throw CalendarError.eventKitNotAvailable
        }
        
        return config
    }
    
    /// Centralized business rules validation - used by all services
    func validateBusinessRules(_ event: CalendarEvent, operation: ValidationOperation) throws {
        // Get business rules
        let businessRulesService = CalendarBusinessRulesService(modelContext: modelContext)
        let rules = businessRulesService.businessRules
        
        // Title validation
        if rules.enableTitleValidation {
            if event.title.count > rules.maxEventTitleLength {
                throw CalendarError.invalidEventTitle("Title exceeds maximum length of \(rules.maxEventTitleLength)")
            }
        }
        
        // Duration validation
        let duration = event.endDate.timeIntervalSince(event.startDate)
        if duration > rules.maxEventDurationHours * 3600 {
            throw CalendarError.eventDurationTooLong(duration, maximum: rules.maxEventDurationHours * 3600)
        }
        
        if duration < rules.minEventDurationMinutes * 60 {
            throw CalendarError.eventDurationTooShort(duration, minimum: rules.minEventDurationMinutes * 60)
        }
        
        // Future date validation
        if rules.enableFutureDateValidation {
            let maxFutureDate = Calendar.current.date(byAdding: .day, value: rules.maxFutureDays, to: Date()) ?? Date()
            if event.startDate > maxFutureDate {
                throw CalendarError.eventTooFarInFuture(event.startDate, maximum: maxFutureDate)
            }
        }
    }
    
    /// Centralized cache invalidation validation - used by all services
    func validateCacheInvalidation(userId: UUID?, familyId: UUID?, eventId: UUID?) -> Bool {
        // Validate that at least one identifier is provided
        guard userId != nil || familyId != nil || eventId != nil else {
            return false
        }
        
        // Validate UUID formats if provided
        if let userId = userId, userId.uuidString.isEmpty {
            return false
        }
        
        if let familyId = familyId, familyId.uuidString.isEmpty {
            return false
        }
        
        if let eventId = eventId, eventId.uuidString.isEmpty {
            return false
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func containsInappropriateContent(_ text: String) -> Bool {
        // Basic inappropriate content detection
        // In a real app, this would use a more sophisticated content filter
        let inappropriateWords = ["spam", "test123", "inappropriate"]
        let lowercaseText = text.lowercased()
        
        return inappropriateWords.contains { lowercaseText.contains($0) }
    }
}

// MARK: - Supporting Types

enum ValidationOperation: String {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

// Note: ValidationResult is now defined in CalendarService.swift