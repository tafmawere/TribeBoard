import Foundation
import SwiftData

// MARK: - Comprehensive Calendar Error Types

/// Comprehensive error types for all calendar operations with detailed error information and recovery suggestions
enum CalendarError: LocalizedError, Equatable, Codable {
    
    // MARK: - Event Validation Errors
    case invalidEventTitle(String)
    case invalidEventDates(String)
    case eventDurationTooLong(TimeInterval, maximum: TimeInterval)
    case eventDurationTooShort(TimeInterval, minimum: TimeInterval)
    case eventInPast(Date)
    case eventTooFarInFuture(Date, maximum: Date)
    case invalidLocation(String)
    case invalidNotes(String)
    case missingRequiredField(String)
    
    // MARK: - Permission Errors
    case insufficientPermissions(operation: String, required: String)
    case userNotAuthorized(userId: String, operation: String)
    case familyAccessDenied(familyId: String, userId: String)
    case eventNotOwnedByUser(eventId: String, userId: String)
    case adminPermissionRequired(operation: String)
    case permissionNotFound(userId: String, familyId: String)
    
    // MARK: - Sync Errors
    case eventKitAccessDenied
    case eventKitNotAvailable
    case appleCalendarNotFound(calendarName: String)
    case syncConflictDetected(localEvent: String, remoteEvent: String)
    case syncOperationFailed(operation: String, reason: String)
    case networkUnavailable
    case syncConfigurationInvalid(reason: String)
    case eventKitSyncDisabled
    case syncConfigurationNotFound
    case syncDisabled
    case batchSyncFailed([String])
    
    // MARK: - Data Errors
    case eventNotFound(eventId: String)
    case familyNotFound(familyId: String)
    case userNotFound(userId: String)
    case dataCorruption(description: String)
    case databaseOperationFailed(operation: String, error: String)
    case modelContextUnavailable
    case coreDataError(underlying: String)
    
    // MARK: - Business Logic Errors
    case schedulingConflict(conflictingEvents: [String])
    case eventCapacityExceeded(current: Int, maximum: Int)
    case duplicateEvent(existingEventId: String)
    case invalidPrivacyLevel(level: String, context: String)
    case familyEventLimitExceeded(current: Int, maximum: Int)
    case eventModificationNotAllowed(reason: String)
    
    // MARK: - Network and Connectivity Errors
    case connectionTimeout
    case serverUnavailable
    case rateLimitExceeded(retryAfter: TimeInterval)
    case cloudKitUnavailable
    case iCloudAccountNotAvailable
    case quotaExceeded(service: String)
    
    // MARK: - Configuration Errors
    case invalidConfiguration(parameter: String, value: String)
    case serviceNotInitialized(service: String)
    case dependencyMissing(dependency: String)
    case featureNotEnabled(feature: String)
    case versionMismatch(expected: String, actual: String)
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Event Validation Errors
        case .invalidEventTitle(let title):
            return "Invalid event title: '\(title)'. Title must be between 1 and 100 characters."
        case .invalidEventDates(let reason):
            return "Invalid event dates: \(reason)"
        case .eventDurationTooLong(let duration, let maximum):
            return "Event duration (\(formatDuration(duration))) exceeds maximum allowed (\(formatDuration(maximum)))."
        case .eventDurationTooShort(let duration, let minimum):
            return "Event duration (\(formatDuration(duration))) is below minimum required (\(formatDuration(minimum)))."
        case .eventInPast(let date):
            return "Cannot create events in the past. Selected date: \(formatDate(date))"
        case .eventTooFarInFuture(let date, let maximum):
            return "Event date (\(formatDate(date))) is too far in the future. Maximum allowed: \(formatDate(maximum))"
        case .invalidLocation(let location):
            return "Invalid location: '\(location)'. Location must be less than 200 characters."
        case .invalidNotes(let notes):
            return "Invalid notes: Notes must be less than 1000 characters."
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
            
        // Permission Errors
        case .insufficientPermissions(let operation, let required):
            return "Insufficient permissions for \(operation). Required: \(required)"
        case .userNotAuthorized(let userId, let operation):
            return "User \(userId) is not authorized to perform \(operation)"
        case .familyAccessDenied(let familyId, let userId):
            return "User \(userId) does not have access to family \(familyId) calendar"
        case .eventNotOwnedByUser(let eventId, let userId):
            return "Event \(eventId) is not owned by user \(userId)"
        case .adminPermissionRequired(let operation):
            return "Administrator permission required for \(operation)"
        case .permissionNotFound(let userId, let familyId):
            return "No permissions found for user \(userId) in family \(familyId)"
            
        // Sync Errors
        case .eventKitAccessDenied:
            return "Calendar access denied. Please enable calendar access in Settings."
        case .eventKitNotAvailable:
            return "Apple Calendar is not available on this device."
        case .appleCalendarNotFound(let calendarName):
            return "Apple Calendar '\(calendarName)' not found. Please check your calendar settings."
        case .syncConflictDetected(let localEvent, let remoteEvent):
            return "Sync conflict detected between local event '\(localEvent)' and remote event '\(remoteEvent)'"
        case .syncOperationFailed(let operation, let reason):
            return "Sync operation '\(operation)' failed: \(reason)"
        case .networkUnavailable:
            return "Network connection unavailable. Some features may not work properly."
        case .syncConfigurationInvalid(let reason):
            return "Sync configuration is invalid: \(reason)"
        case .eventKitSyncDisabled:
            return "Apple Calendar sync is disabled. Enable it in Settings to sync events."
        case .syncConfigurationNotFound:
            return "Sync configuration not found for user."
        case .syncDisabled:
            return "Apple Calendar sync is disabled."
        case .batchSyncFailed(let errors):
            return "Batch sync failed: \(errors.joined(separator: "; "))"
            
        // Data Errors
        case .eventNotFound(let eventId):
            return "Event with ID \(eventId) not found."
        case .familyNotFound(let familyId):
            return "Family with ID \(familyId) not found."
        case .userNotFound(let userId):
            return "User with ID \(userId) not found."
        case .dataCorruption(let description):
            return "Data corruption detected: \(description)"
        case .databaseOperationFailed(let operation, let error):
            return "Database operation '\(operation)' failed: \(error)"
        case .modelContextUnavailable:
            return "Database context is unavailable. Please restart the app."
        case .coreDataError(let underlying):
            return "Database error: \(underlying)"
            
        // Business Logic Errors
        case .schedulingConflict(let conflictingEvents):
            return "Scheduling conflict with existing events: \(conflictingEvents.joined(separator: ", "))"
        case .eventCapacityExceeded(let current, let maximum):
            return "Event capacity exceeded. Current: \(current), Maximum: \(maximum)"
        case .duplicateEvent(let existingEventId):
            return "Duplicate event detected. Existing event ID: \(existingEventId)"
        case .invalidPrivacyLevel(let level, let context):
            return "Invalid privacy level '\(level)' for \(context)"
        case .familyEventLimitExceeded(let current, let maximum):
            return "Family event limit exceeded. Current: \(current), Maximum: \(maximum)"
        case .eventModificationNotAllowed(let reason):
            return "Event modification not allowed: \(reason)"
            
        // Network and Connectivity Errors
        case .connectionTimeout:
            return "Connection timeout. Please check your internet connection and try again."
        case .serverUnavailable:
            return "Server is temporarily unavailable. Please try again later."
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Please try again in \(Int(retryAfter)) seconds."
        case .cloudKitUnavailable:
            return "iCloud is unavailable. Please check your iCloud settings."
        case .iCloudAccountNotAvailable:
            return "iCloud account not available. Please sign in to iCloud in Settings."
        case .quotaExceeded(let service):
            return "Storage quota exceeded for \(service). Please free up space or upgrade your plan."
            
        // Configuration Errors
        case .invalidConfiguration(let parameter, let value):
            return "Invalid configuration: \(parameter) = '\(value)'"
        case .serviceNotInitialized(let service):
            return "Service '\(service)' is not initialized. Please restart the app."
        case .dependencyMissing(let dependency):
            return "Required dependency '\(dependency)' is missing."
        case .featureNotEnabled(let feature):
            return "Feature '\(feature)' is not enabled. Please enable it in Settings."
        case .versionMismatch(let expected, let actual):
            return "Version mismatch. Expected: \(expected), Actual: \(actual)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidEventTitle:
            return "Event title validation failed"
        case .invalidEventDates:
            return "Event date validation failed"
        case .eventDurationTooLong, .eventDurationTooShort:
            return "Event duration validation failed"
        case .eventInPast, .eventTooFarInFuture:
            return "Event date range validation failed"
        case .insufficientPermissions, .userNotAuthorized, .familyAccessDenied:
            return "Permission check failed"
        case .eventKitAccessDenied, .eventKitNotAvailable:
            return "Apple Calendar access failed"
        case .syncConflictDetected, .syncOperationFailed:
            return "Calendar synchronization failed"
        case .networkUnavailable, .connectionTimeout:
            return "Network connectivity issue"
        case .eventNotFound, .familyNotFound, .userNotFound:
            return "Required data not found"
        case .dataCorruption, .databaseOperationFailed:
            return "Data integrity issue"
        case .schedulingConflict:
            return "Event scheduling conflict"
        default:
            return "Calendar operation failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidEventTitle:
            return "Please enter a title between 1 and 100 characters."
        case .invalidEventDates:
            return "Please select valid start and end dates for the event."
        case .eventDurationTooLong:
            return "Please reduce the event duration or split it into multiple events."
        case .eventDurationTooShort:
            return "Please increase the event duration to at least the minimum required."
        case .eventInPast:
            return "Please select a future date for the event."
        case .eventTooFarInFuture:
            return "Please select a date within the allowed range."
        case .invalidLocation:
            return "Please enter a location with fewer than 200 characters."
        case .invalidNotes:
            return "Please limit notes to fewer than 1000 characters."
        case .insufficientPermissions:
            return "Please contact your family administrator to request the necessary permissions."
        case .familyAccessDenied:
            return "Please ensure you are a member of the family and have calendar access."
        case .eventKitAccessDenied:
            return "Please go to Settings > Privacy & Security > Calendars and enable access for TribeBoard."
        case .eventKitNotAvailable:
            return "Apple Calendar sync is not available on this device."
        case .appleCalendarNotFound:
            return "Please check your Apple Calendar app and ensure TribeBoard calendar exists."
        case .networkUnavailable:
            return "Please check your internet connection and try again."
        case .syncConflictDetected:
            return "Please choose which version of the event to keep."
        case .eventNotFound:
            return "The event may have been deleted. Please refresh and try again."
        case .schedulingConflict:
            return "Please choose a different time or resolve the conflicting events."
        case .connectionTimeout:
            return "Please check your internet connection and try again."
        case .serverUnavailable:
            return "Please try again in a few minutes."
        case .cloudKitUnavailable:
            return "Please check your iCloud settings and internet connection."
        case .iCloudAccountNotAvailable:
            return "Please sign in to iCloud in Settings > [Your Name] > iCloud."
        case .modelContextUnavailable:
            return "Please restart the app to restore database connectivity."
        case .serviceNotInitialized:
            return "Please restart the app to reinitialize services."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    // MARK: - Error Categories
    
    var category: CalendarErrorCategory {
        switch self {
        case .invalidEventTitle, .invalidEventDates, .eventDurationTooLong, .eventDurationTooShort,
             .eventInPast, .eventTooFarInFuture, .invalidLocation, .invalidNotes, .missingRequiredField:
            return .validation
            
        case .insufficientPermissions, .userNotAuthorized, .familyAccessDenied, .eventNotOwnedByUser,
             .adminPermissionRequired, .permissionNotFound:
            return .permission
            
        case .eventKitAccessDenied, .eventKitNotAvailable, .appleCalendarNotFound, .syncConflictDetected,
             .syncOperationFailed, .syncConfigurationInvalid, .eventKitSyncDisabled, .syncConfigurationNotFound,
             .syncDisabled, .batchSyncFailed:
            return .sync
            
        case .eventNotFound, .familyNotFound, .userNotFound, .dataCorruption, .databaseOperationFailed,
             .modelContextUnavailable, .coreDataError:
            return .data
            
        case .schedulingConflict, .eventCapacityExceeded, .duplicateEvent, .invalidPrivacyLevel,
             .familyEventLimitExceeded, .eventModificationNotAllowed:
            return .businessLogic
            
        case .networkUnavailable, .connectionTimeout, .serverUnavailable, .rateLimitExceeded,
             .cloudKitUnavailable, .iCloudAccountNotAvailable, .quotaExceeded:
            return .network
            
        case .invalidConfiguration, .serviceNotInitialized, .dependencyMissing, .featureNotEnabled,
             .versionMismatch:
            return .configuration
        }
    }
    
    // MARK: - Severity Level
    
    var severity: CalendarErrorSeverity {
        switch self {
        case .invalidEventTitle, .invalidEventDates, .invalidLocation, .invalidNotes, .missingRequiredField:
            return .low
            
        case .eventDurationTooLong, .eventDurationTooShort, .eventInPast, .eventTooFarInFuture,
             .schedulingConflict, .duplicateEvent:
            return .medium
            
        case .insufficientPermissions, .userNotAuthorized, .familyAccessDenied, .eventNotOwnedByUser,
             .syncConflictDetected, .eventNotFound:
            return .medium
            
        case .eventKitAccessDenied, .networkUnavailable, .syncOperationFailed, .databaseOperationFailed:
            return .high
            
        case .dataCorruption, .modelContextUnavailable, .coreDataError, .serviceNotInitialized:
            return .critical
            
        default:
            return .medium
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case type
        case message
        case associatedValue1
        case associatedValue2
        case associatedValue3
        case associatedValue4
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "invalidEventTitle":
            let message = try container.decode(String.self, forKey: .associatedValue1)
            self = .invalidEventTitle(message)
        case "invalidEventDates":
            let message = try container.decode(String.self, forKey: .associatedValue1)
            self = .invalidEventDates(message)
        case "eventDurationTooLong":
            let duration = try container.decode(TimeInterval.self, forKey: .associatedValue1)
            let maximum = try container.decode(TimeInterval.self, forKey: .associatedValue2)
            self = .eventDurationTooLong(duration, maximum: maximum)
        case "eventDurationTooShort":
            let duration = try container.decode(TimeInterval.self, forKey: .associatedValue1)
            let minimum = try container.decode(TimeInterval.self, forKey: .associatedValue2)
            self = .eventDurationTooShort(duration, minimum: minimum)
        case "eventInPast":
            let date = try container.decode(Date.self, forKey: .associatedValue1)
            self = .eventInPast(date)
        case "eventTooFarInFuture":
            let date = try container.decode(Date.self, forKey: .associatedValue1)
            let maximum = try container.decode(Date.self, forKey: .associatedValue2)
            self = .eventTooFarInFuture(date, maximum: maximum)
        case "invalidLocation":
            let message = try container.decode(String.self, forKey: .associatedValue1)
            self = .invalidLocation(message)
        case "invalidNotes":
            let message = try container.decode(String.self, forKey: .associatedValue1)
            self = .invalidNotes(message)
        case "missingRequiredField":
            let field = try container.decode(String.self, forKey: .associatedValue1)
            self = .missingRequiredField(field)
        case "insufficientPermissions":
            let operation = try container.decode(String.self, forKey: .associatedValue1)
            let required = try container.decode(String.self, forKey: .associatedValue2)
            self = .insufficientPermissions(operation: operation, required: required)
        case "userNotAuthorized":
            let userId = try container.decode(String.self, forKey: .associatedValue1)
            let operation = try container.decode(String.self, forKey: .associatedValue2)
            self = .userNotAuthorized(userId: userId, operation: operation)
        case "familyAccessDenied":
            let familyId = try container.decode(String.self, forKey: .associatedValue1)
            let userId = try container.decode(String.self, forKey: .associatedValue2)
            self = .familyAccessDenied(familyId: familyId, userId: userId)
        case "eventNotOwnedByUser":
            let eventId = try container.decode(String.self, forKey: .associatedValue1)
            let userId = try container.decode(String.self, forKey: .associatedValue2)
            self = .eventNotOwnedByUser(eventId: eventId, userId: userId)
        case "adminPermissionRequired":
            let operation = try container.decode(String.self, forKey: .associatedValue1)
            self = .adminPermissionRequired(operation: operation)
        case "permissionNotFound":
            let userId = try container.decode(String.self, forKey: .associatedValue1)
            let familyId = try container.decode(String.self, forKey: .associatedValue2)
            self = .permissionNotFound(userId: userId, familyId: familyId)
        case "eventKitAccessDenied":
            self = .eventKitAccessDenied
        case "eventKitNotAvailable":
            self = .eventKitNotAvailable
        case "appleCalendarNotFound":
            let calendarName = try container.decode(String.self, forKey: .associatedValue1)
            self = .appleCalendarNotFound(calendarName: calendarName)
        case "syncConflictDetected":
            let localEvent = try container.decode(String.self, forKey: .associatedValue1)
            let remoteEvent = try container.decode(String.self, forKey: .associatedValue2)
            self = .syncConflictDetected(localEvent: localEvent, remoteEvent: remoteEvent)
        case "syncOperationFailed":
            let operation = try container.decode(String.self, forKey: .associatedValue1)
            let reason = try container.decode(String.self, forKey: .associatedValue2)
            self = .syncOperationFailed(operation: operation, reason: reason)
        case "networkUnavailable":
            self = .networkUnavailable
        case "syncConfigurationInvalid":
            let reason = try container.decode(String.self, forKey: .associatedValue1)
            self = .syncConfigurationInvalid(reason: reason)
        case "eventKitSyncDisabled":
            self = .eventKitSyncDisabled
        case "syncConfigurationNotFound":
            self = .syncConfigurationNotFound
        case "syncDisabled":
            self = .syncDisabled
        case "batchSyncFailed":
            let errors = try container.decode([String].self, forKey: .associatedValue1)
            self = .batchSyncFailed(errors)
        case "eventNotFound":
            let eventId = try container.decode(String.self, forKey: .associatedValue1)
            self = .eventNotFound(eventId: eventId)
        case "familyNotFound":
            let familyId = try container.decode(String.self, forKey: .associatedValue1)
            self = .familyNotFound(familyId: familyId)
        case "userNotFound":
            let userId = try container.decode(String.self, forKey: .associatedValue1)
            self = .userNotFound(userId: userId)
        case "dataCorruption":
            let description = try container.decode(String.self, forKey: .associatedValue1)
            self = .dataCorruption(description: description)
        case "databaseOperationFailed":
            let operation = try container.decode(String.self, forKey: .associatedValue1)
            let error = try container.decode(String.self, forKey: .associatedValue2)
            self = .databaseOperationFailed(operation: operation, error: error)
        case "modelContextUnavailable":
            self = .modelContextUnavailable
        case "coreDataError":
            let underlying = try container.decode(String.self, forKey: .associatedValue1)
            self = .coreDataError(underlying: underlying)
        case "schedulingConflict":
            let conflictingEvents = try container.decode([String].self, forKey: .associatedValue1)
            self = .schedulingConflict(conflictingEvents: conflictingEvents)
        case "eventCapacityExceeded":
            let current = try container.decode(Int.self, forKey: .associatedValue1)
            let maximum = try container.decode(Int.self, forKey: .associatedValue2)
            self = .eventCapacityExceeded(current: current, maximum: maximum)
        case "duplicateEvent":
            let existingEventId = try container.decode(String.self, forKey: .associatedValue1)
            self = .duplicateEvent(existingEventId: existingEventId)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown CalendarError type: \(type)"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .invalidEventTitle(let message):
            try container.encode("invalidEventTitle", forKey: .type)
            try container.encode(message, forKey: .associatedValue1)
        case .invalidEventDates(let message):
            try container.encode("invalidEventDates", forKey: .type)
            try container.encode(message, forKey: .associatedValue1)
        case .eventDurationTooLong(let duration, let maximum):
            try container.encode("eventDurationTooLong", forKey: .type)
            try container.encode(duration, forKey: .associatedValue1)
            try container.encode(maximum, forKey: .associatedValue2)
        case .eventDurationTooShort(let duration, let minimum):
            try container.encode("eventDurationTooShort", forKey: .type)
            try container.encode(duration, forKey: .associatedValue1)
            try container.encode(minimum, forKey: .associatedValue2)
        case .eventInPast(let date):
            try container.encode("eventInPast", forKey: .type)
            try container.encode(date, forKey: .associatedValue1)
        case .eventTooFarInFuture(let date, let maximum):
            try container.encode("eventTooFarInFuture", forKey: .type)
            try container.encode(date, forKey: .associatedValue1)
            try container.encode(maximum, forKey: .associatedValue2)
        case .invalidLocation(let message):
            try container.encode("invalidLocation", forKey: .type)
            try container.encode(message, forKey: .associatedValue1)
        case .invalidNotes(let message):
            try container.encode("invalidNotes", forKey: .type)
            try container.encode(message, forKey: .associatedValue1)
        case .missingRequiredField(let field):
            try container.encode("missingRequiredField", forKey: .type)
            try container.encode(field, forKey: .associatedValue1)
        case .insufficientPermissions(let operation, let required):
            try container.encode("insufficientPermissions", forKey: .type)
            try container.encode(operation, forKey: .associatedValue1)
            try container.encode(required, forKey: .associatedValue2)
        case .userNotAuthorized(let userId, let operation):
            try container.encode("userNotAuthorized", forKey: .type)
            try container.encode(userId, forKey: .associatedValue1)
            try container.encode(operation, forKey: .associatedValue2)
        case .familyAccessDenied(let familyId, let userId):
            try container.encode("familyAccessDenied", forKey: .type)
            try container.encode(familyId, forKey: .associatedValue1)
            try container.encode(userId, forKey: .associatedValue2)
        case .eventNotOwnedByUser(let eventId, let userId):
            try container.encode("eventNotOwnedByUser", forKey: .type)
            try container.encode(eventId, forKey: .associatedValue1)
            try container.encode(userId, forKey: .associatedValue2)
        case .adminPermissionRequired(let operation):
            try container.encode("adminPermissionRequired", forKey: .type)
            try container.encode(operation, forKey: .associatedValue1)
        case .permissionNotFound(let userId, let familyId):
            try container.encode("permissionNotFound", forKey: .type)
            try container.encode(userId, forKey: .associatedValue1)
            try container.encode(familyId, forKey: .associatedValue2)
        case .eventKitAccessDenied:
            try container.encode("eventKitAccessDenied", forKey: .type)
        case .eventKitNotAvailable:
            try container.encode("eventKitNotAvailable", forKey: .type)
        case .appleCalendarNotFound(let calendarName):
            try container.encode("appleCalendarNotFound", forKey: .type)
            try container.encode(calendarName, forKey: .associatedValue1)
        case .syncConflictDetected(let localEvent, let remoteEvent):
            try container.encode("syncConflictDetected", forKey: .type)
            try container.encode(localEvent, forKey: .associatedValue1)
            try container.encode(remoteEvent, forKey: .associatedValue2)
        case .syncOperationFailed(let operation, let reason):
            try container.encode("syncOperationFailed", forKey: .type)
            try container.encode(operation, forKey: .associatedValue1)
            try container.encode(reason, forKey: .associatedValue2)
        case .networkUnavailable:
            try container.encode("networkUnavailable", forKey: .type)
        case .syncConfigurationInvalid(let reason):
            try container.encode("syncConfigurationInvalid", forKey: .type)
            try container.encode(reason, forKey: .associatedValue1)
        case .eventKitSyncDisabled:
            try container.encode("eventKitSyncDisabled", forKey: .type)
        case .syncConfigurationNotFound:
            try container.encode("syncConfigurationNotFound", forKey: .type)
        case .syncDisabled:
            try container.encode("syncDisabled", forKey: .type)
        case .batchSyncFailed(let errors):
            try container.encode("batchSyncFailed", forKey: .type)
            try container.encode(errors, forKey: .associatedValue1)
        case .eventNotFound(let eventId):
            try container.encode("eventNotFound", forKey: .type)
            try container.encode(eventId, forKey: .associatedValue1)
        case .familyNotFound(let familyId):
            try container.encode("familyNotFound", forKey: .type)
            try container.encode(familyId, forKey: .associatedValue1)
        case .userNotFound(let userId):
            try container.encode("userNotFound", forKey: .type)
            try container.encode(userId, forKey: .associatedValue1)
        case .dataCorruption(let description):
            try container.encode("dataCorruption", forKey: .type)
            try container.encode(description, forKey: .associatedValue1)
        case .databaseOperationFailed(let operation, let error):
            try container.encode("databaseOperationFailed", forKey: .type)
            try container.encode(operation, forKey: .associatedValue1)
            try container.encode(error, forKey: .associatedValue2)
        case .modelContextUnavailable:
            try container.encode("modelContextUnavailable", forKey: .type)
        case .coreDataError(let underlying):
            try container.encode("coreDataError", forKey: .type)
            try container.encode(underlying, forKey: .associatedValue1)
        case .schedulingConflict(let conflictingEvents):
            try container.encode("schedulingConflict", forKey: .type)
            try container.encode(conflictingEvents, forKey: .associatedValue1)
        case .eventCapacityExceeded(let current, let maximum):
            try container.encode("eventCapacityExceeded", forKey: .type)
            try container.encode(current, forKey: .associatedValue1)
            try container.encode(maximum, forKey: .associatedValue2)
        case .duplicateEvent(let existingEventId):
            try container.encode("duplicateEvent", forKey: .type)
            try container.encode(existingEventId, forKey: .associatedValue1)
        case .invalidPrivacyLevel(let level, let context):
            try container.encode("invalidPrivacyLevel", forKey: .type)
            try container.encode(level, forKey: .associatedValue1)
            try container.encode(context, forKey: .associatedValue2)
        case .familyEventLimitExceeded(let current, let maximum):
            try container.encode("familyEventLimitExceeded", forKey: .type)
            try container.encode(current, forKey: .associatedValue1)
            try container.encode(maximum, forKey: .associatedValue2)
        case .eventModificationNotAllowed(let reason):
            try container.encode("eventModificationNotAllowed", forKey: .type)
            try container.encode(reason, forKey: .associatedValue1)
        // Network and Connectivity Errors
        case .connectionTimeout:
            try container.encode("connectionTimeout", forKey: .type)
        case .serverUnavailable:
            try container.encode("serverUnavailable", forKey: .type)
        case .rateLimitExceeded(let retryAfter):
            try container.encode("rateLimitExceeded", forKey: .type)
            try container.encode(retryAfter, forKey: .associatedValue1)
        case .cloudKitUnavailable:
            try container.encode("cloudKitUnavailable", forKey: .type)
        case .iCloudAccountNotAvailable:
            try container.encode("iCloudAccountNotAvailable", forKey: .type)
        case .quotaExceeded(let service):
            try container.encode("quotaExceeded", forKey: .type)
            try container.encode(service, forKey: .associatedValue1)
        // Configuration Errors
        case .invalidConfiguration(let parameter, let value):
            try container.encode("invalidConfiguration", forKey: .type)
            try container.encode(parameter, forKey: .associatedValue1)
            try container.encode(value, forKey: .associatedValue2)
        case .serviceNotInitialized(let service):
            try container.encode("serviceNotInitialized", forKey: .type)
            try container.encode(service, forKey: .associatedValue1)
        case .dependencyMissing(let dependency):
            try container.encode("dependencyMissing", forKey: .type)
            try container.encode(dependency, forKey: .associatedValue1)
        case .featureNotEnabled(let feature):
            try container.encode("featureNotEnabled", forKey: .type)
            try container.encode(feature, forKey: .associatedValue1)
        case .versionMismatch(let expected, let actual):
            try container.encode("versionMismatch", forKey: .type)
            try container.encode(expected, forKey: .associatedValue1)
            try container.encode(actual, forKey: .associatedValue2)
        }
    }
}

// MARK: - Error Categories

enum CalendarErrorCategory: String, CaseIterable, Codable {
    case validation = "Validation"
    case permission = "Permission"
    case sync = "Synchronization"
    case data = "Data"
    case businessLogic = "Business Logic"
    case network = "Network"
    case configuration = "Configuration"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .validation:
            return "checkmark.circle"
        case .permission:
            return "lock.circle"
        case .sync:
            return "arrow.triangle.2.circlepath.circle"
        case .data:
            return "externaldrive.badge.exclamationmark"
        case .businessLogic:
            return "gear.circle"
        case .network:
            return "wifi.exclamationmark"
        case .configuration:
            return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Error Severity

enum CalendarErrorSeverity: String, CaseIterable, Comparable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var displayName: String {
        return rawValue
    }
    
    var color: String {
        switch self {
        case .low:
            return "blue"
        case .medium:
            return "orange"
        case .high:
            return "red"
        case .critical:
            return "purple"
        }
    }
    
    static func < (lhs: CalendarErrorSeverity, rhs: CalendarErrorSeverity) -> Bool {
        let order: [CalendarErrorSeverity] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Error Context

struct CalendarErrorContext: Codable {
    let timestamp: Date
    let userId: String?
    let familyId: String?
    let eventId: String?
    let operation: String
    let additionalInfo: [String: String] // Changed from [String: Any] to [String: String] for Codable conformance
    
    init(
        userId: String? = nil,
        familyId: String? = nil,
        eventId: String? = nil,
        operation: String,
        additionalInfo: [String: Any] = [:]
    ) {
        self.timestamp = Date()
        self.userId = userId
        self.familyId = familyId
        self.eventId = eventId
        self.operation = operation
        // Convert [String: Any] to [String: String] for Codable conformance
        self.additionalInfo = additionalInfo.compactMapValues { value in
            if let stringValue = value as? String {
                return stringValue
            } else {
                return String(describing: value)
            }
        }
    }
}