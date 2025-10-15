import Foundation
import SwiftData

/// Service for validating and maintaining calendar data integrity
@MainActor
class CalendarDataIntegrityService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    @Published var integrityIssues: [DataIntegrityIssue] = []
    @Published var isValidating = false
    @Published var lastValidationDate: Date?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Integrity Validation
    
    /// Performs comprehensive data integrity validation
    func validateDataIntegrity() async throws -> DataIntegrityReport {
        isValidating = true
        integrityIssues = []
        
        defer {
            isValidating = false
            lastValidationDate = Date()
        }
        
        var report = DataIntegrityReport()
        
        // Validate event data integrity
        try await validateEventDataIntegrity(&report)
        
        // Validate relationship integrity
        try await validateRelationshipIntegrity(&report)
        
        // Validate sync state integrity
        try await validateSyncStateIntegrity(&report)
        
        // Validate permission integrity
        try await validatePermissionIntegrity(&report)
        
        // Validate temporal integrity
        try await validateTemporalIntegrity(&report)
        
        // Update published properties
        integrityIssues = report.issues
        
        return report
    }
    
    /// Validates individual event data integrity
    func validateEventIntegrity(_ event: CalendarEvent) async throws -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        // Validate required fields
        if event.id.uuidString.isEmpty {
            issues.append(DataIntegrityIssue(
                type: .invalidIdentifier,
                severity: .critical,
                entity: "CalendarEvent",
                entityId: "unknown",
                field: "id",
                message: "Event has invalid or empty ID",
                suggestedFix: "Generate new UUID for event"
            ))
        }
        
        if event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(DataIntegrityIssue(
                type: .missingRequiredField,
                severity: .high,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "title",
                message: "Event has empty title",
                suggestedFix: "Set default title or prompt user for title"
            ))
        }
        
        if event.createdBy.uuidString.isEmpty {
            issues.append(DataIntegrityIssue(
                type: .invalidIdentifier,
                severity: .critical,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "createdBy",
                message: "Event has invalid creator ID",
                suggestedFix: "Set valid creator ID or delete orphaned event"
            ))
        }
        
        // Validate date consistency
        if event.endDate <= event.startDate {
            issues.append(DataIntegrityIssue(
                type: .invalidDateRange,
                severity: .high,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "startDate/endDate",
                message: "Event end date is not after start date",
                suggestedFix: "Correct event dates or delete invalid event"
            ))
        }
        
        // Validate privacy level consistency
        if event.privacyLevel == .familyShared && event.familyId == nil {
            issues.append(DataIntegrityIssue(
                type: .inconsistentData,
                severity: .high,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "privacyLevel/familyId",
                message: "Family shared event has no family ID",
                suggestedFix: "Set family ID or change privacy level to personal"
            ))
        }
        
        if event.privacyLevel == .personal && event.familyId != nil {
            issues.append(DataIntegrityIssue(
                type: .inconsistentData,
                severity: .medium,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "privacyLevel/familyId",
                message: "Personal event has family ID",
                suggestedFix: "Remove family ID or change privacy level to family shared"
            ))
        }
        
        // Validate version consistency
        if event.version < 1 {
            issues.append(DataIntegrityIssue(
                type: .invalidVersion,
                severity: .medium,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "version",
                message: "Event has invalid version number",
                suggestedFix: "Reset version to 1"
            ))
        }
        
        // Validate timestamp consistency
        if event.lastModified < event.createdAt {
            issues.append(DataIntegrityIssue(
                type: .invalidTimestamp,
                severity: .medium,
                entity: "CalendarEvent",
                entityId: event.id.uuidString,
                field: "lastModified",
                message: "Last modified date is before creation date",
                suggestedFix: "Set last modified date to creation date or later"
            ))
        }
        
        return issues
    }
    
    /// Repairs data integrity issues
    func repairDataIntegrityIssues(_ issues: [DataIntegrityIssue]) async throws -> DataIntegrityRepairResult {
        var result = DataIntegrityRepairResult()
        
        for issue in issues {
            do {
                try await repairSingleIssue(issue)
                result.repairedIssues.append(issue)
            } catch {
                result.failedRepairs.append(DataIntegrityRepairFailure(
                    issue: issue,
                    error: error,
                    timestamp: Date()
                ))
            }
        }
        
        return result
    }
    
    /// Cleans up orphaned and invalid data
    func cleanupOrphanedData() async throws -> DataCleanupResult {
        var result = DataCleanupResult()
        
        // Find and clean up orphaned events
        try await cleanupOrphanedEvents(&result)
        
        // Find and clean up invalid sync states
        try await cleanupInvalidSyncStates(&result)
        
        // Find and clean up expired data
        try await cleanupExpiredData(&result)
        
        return result
    }
    
    // MARK: - Private Validation Methods
    
    private func validateEventDataIntegrity(_ report: inout DataIntegrityReport) async throws {
        let descriptor = FetchDescriptor<CalendarEvent>()
        
        do {
            let events = try modelContext.fetch(descriptor)
            report.totalEventsChecked = events.count
            
            for event in events {
                let eventIssues = try await validateEventIntegrity(event)
                report.issues.append(contentsOf: eventIssues)
            }
            
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate event data integrity",
                error: error.localizedDescription
            )
        }
    }
    
    private func validateRelationshipIntegrity(_ report: inout DataIntegrityReport) async throws {
        // Validate family relationships
        let familyEventDescriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.privacyLevel == .familyShared }
        )
        
        do {
            let familyEvents = try modelContext.fetch(familyEventDescriptor)
            
            for event in familyEvents {
                // Check if family ID exists (would need family service integration)
                if let familyId = event.familyId {
                    // For now, just validate the ID format
                    if familyId.uuidString.isEmpty {
                        report.issues.append(DataIntegrityIssue(
                            type: .brokenRelationship,
                            severity: .high,
                            entity: "CalendarEvent",
                            entityId: event.id.uuidString,
                            field: "familyId",
                            message: "Event references invalid family ID",
                            suggestedFix: "Remove family reference or fix family ID"
                        ))
                    }
                }
            }
            
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate relationship integrity",
                error: error.localizedDescription
            )
        }
    }
    
    private func validateSyncStateIntegrity(_ report: inout DataIntegrityReport) async throws {
        let syncPendingDescriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.needsSync == true || $0.needsEventKitSync == true }
        )
        
        do {
            let syncPendingEvents = try modelContext.fetch(syncPendingDescriptor)
            
            for event in syncPendingEvents {
                // Check for events that have been pending sync for too long
                let syncAge = Date().timeIntervalSince(event.lastModified)
                if syncAge > 86400 { // 24 hours
                    report.issues.append(DataIntegrityIssue(
                        type: .staleSyncState,
                        severity: .medium,
                        entity: "CalendarEvent",
                        entityId: event.id.uuidString,
                        field: "needsSync",
                        message: "Event has been pending sync for over 24 hours",
                        suggestedFix: "Reset sync state or force sync"
                    ))
                }
                
                // Check for inconsistent sync states
                if event.needsEventKitSync && event.eventKitIdentifier?.isEmpty == true {
                    report.issues.append(DataIntegrityIssue(
                        type: .inconsistentData,
                        severity: .medium,
                        entity: "CalendarEvent",
                        entityId: event.id.uuidString,
                        field: "eventKitIdentifier",
                        message: "Event needs EventKit sync but has no EventKit identifier",
                        suggestedFix: "Clear EventKit sync flag or generate identifier"
                    ))
                }
            }
            
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate sync state integrity",
                error: error.localizedDescription
            )
        }
    }
    
    private func validatePermissionIntegrity(_ report: inout DataIntegrityReport) async throws {
        // This would validate permission consistency with the permission system
        // For now, we'll do basic validation
        
        let familyEventDescriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.privacyLevel == .familyShared }
        )
        
        do {
            let familyEvents = try modelContext.fetch(familyEventDescriptor)
            
            for event in familyEvents {
                // Check if creator has valid permissions (would need permission service integration)
                if event.createdBy.uuidString.isEmpty {
                    report.issues.append(DataIntegrityIssue(
                        type: .permissionViolation,
                        severity: .high,
                        entity: "CalendarEvent",
                        entityId: event.id.uuidString,
                        field: "createdBy",
                        message: "Family event has invalid creator",
                        suggestedFix: "Set valid creator or change to personal event"
                    ))
                }
            }
            
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate permission integrity",
                error: error.localizedDescription
            )
        }
    }
    
    private func validateTemporalIntegrity(_ report: inout DataIntegrityReport) async throws {
        let descriptor = FetchDescriptor<CalendarEvent>()
        
        do {
            let events = try modelContext.fetch(descriptor)
            
            for event in events {
                // Check for events with impossible dates
                if event.startDate.timeIntervalSince1970 < 0 {
                    report.issues.append(DataIntegrityIssue(
                        type: .invalidTimestamp,
                        severity: .high,
                        entity: "CalendarEvent",
                        entityId: event.id.uuidString,
                        field: "startDate",
                        message: "Event has invalid start date (before Unix epoch)",
                        suggestedFix: "Set valid start date or delete event"
                    ))
                }
                
                // Check for events too far in the future
                let maxFutureDate = Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date()
                if event.startDate > maxFutureDate {
                    report.issues.append(DataIntegrityIssue(
                        type: .invalidTimestamp,
                        severity: .medium,
                        entity: "CalendarEvent",
                        entityId: event.id.uuidString,
                        field: "startDate",
                        message: "Event is scheduled too far in the future",
                        suggestedFix: "Adjust event date to reasonable future date"
                    ))
                }
            }
            
        } catch {
            throw CalendarError.databaseOperationFailed(
                operation: "validate temporal integrity",
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Private Repair Methods
    
    private func repairSingleIssue(_ issue: DataIntegrityIssue) async throws {
        switch issue.type {
        case .invalidIdentifier:
            try await repairInvalidIdentifier(issue)
        case .missingRequiredField:
            try await repairMissingRequiredField(issue)
        case .invalidDateRange:
            try await repairInvalidDateRange(issue)
        case .inconsistentData:
            try await repairInconsistentData(issue)
        case .invalidVersion:
            try await repairInvalidVersion(issue)
        case .invalidTimestamp:
            try await repairInvalidTimestamp(issue)
        case .brokenRelationship:
            try await repairBrokenRelationship(issue)
        case .staleSyncState:
            try await repairStaleSyncState(issue)
        case .permissionViolation:
            try await repairPermissionViolation(issue)
        }
    }
    
    private func repairInvalidIdentifier(_ issue: DataIntegrityIssue) async throws {
        // Generate new UUID for invalid identifiers
        if issue.field == "id" {
            // Cannot repair invalid event ID - would need to recreate event
            throw CalendarError.dataCorruption("Cannot repair invalid event ID")
        }
    }
    
    private func repairMissingRequiredField(_ issue: DataIntegrityIssue) async throws {
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        switch issue.field {
        case "title":
            event.title = "Untitled Event"
        default:
            break
        }
        
        try modelContext.save()
    }
    
    private func repairInvalidDateRange(_ issue: DataIntegrityIssue) async throws {
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        // Fix by setting end date to 1 hour after start date
        event.endDate = event.startDate.addingTimeInterval(3600)
        event.lastModified = Date()
        
        try modelContext.save()
    }
    
    private func repairInconsistentData(_ issue: DataIntegrityIssue) async throws {
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        if issue.field.contains("privacyLevel") {
            if event.privacyLevel == .familyShared && event.familyId == nil {
                // Change to personal event
                event.privacyLevel = .personal
            } else if event.privacyLevel == .personal && event.familyId != nil {
                // Remove family ID
                event.familyId = nil
            }
            
            event.lastModified = Date()
            try modelContext.save()
        }
    }
    
    private func repairInvalidVersion(_ issue: DataIntegrityIssue) async throws {
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        event.version = max(1, event.version)
        try modelContext.save()
    }
    
    private func repairInvalidTimestamp(_ issue: DataIntegrityIssue) async throws {
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        if issue.field == "lastModified" {
            event.lastModified = max(event.createdAt, event.lastModified)
        }
        
        try modelContext.save()
    }
    
    private func repairBrokenRelationship(_ issue: DataIntegrityIssue) async throws {
        // Remove broken relationships
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        if issue.field == "familyId" {
            event.familyId = nil
            event.privacyLevel = .personal
            event.lastModified = Date()
        }
        
        try modelContext.save()
    }
    
    private func repairStaleSyncState(_ issue: DataIntegrityIssue) async throws {
        guard let eventId = UUID(uuidString: issue.entityId) else {
            throw CalendarError.dataCorruption("Invalid event ID for repair")
        }
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        
        let events = try modelContext.fetch(descriptor)
        guard let event = events.first else {
            throw CalendarError.eventNotFound(issue.entityId)
        }
        
        // Reset sync state
        event.needsSync = false
        event.needsEventKitSync = false
        
        try modelContext.save()
    }
    
    private func repairPermissionViolation(_ issue: DataIntegrityIssue) async throws {
        // Permission violations typically require manual intervention
        throw CalendarError.permissionNotFound("", "")
    }
    
    // MARK: - Private Cleanup Methods
    
    private func cleanupOrphanedEvents(_ result: inout DataCleanupResult) async throws {
        // Find events with invalid creator IDs
        let descriptor = FetchDescriptor<CalendarEvent>()
        
        let events = try modelContext.fetch(descriptor)
        var orphanedEvents: [CalendarEvent] = []
        
        for event in events {
            if event.createdBy.uuidString.isEmpty {
                orphanedEvents.append(event)
            }
        }
        
        for event in orphanedEvents {
            modelContext.delete(event)
            result.deletedEvents += 1
        }
        
        if !orphanedEvents.isEmpty {
            try modelContext.save()
        }
    }
    
    private func cleanupInvalidSyncStates(_ result: inout DataCleanupResult) async throws {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.needsEventKitSync == true }
        )
        
        let events = try modelContext.fetch(descriptor)
        var fixedEvents = 0
        
        for event in events {
            if event.eventKitIdentifier?.isEmpty == true {
                event.needsEventKitSync = false
                fixedEvents += 1
            }
        }
        
        if fixedEvents > 0 {
            try modelContext.save()
            result.fixedSyncStates = fixedEvents
        }
    }
    
    private func cleanupExpiredData(_ result: inout DataCleanupResult) async throws {
        // Clean up very old deleted events
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.isDeleted == true && $0.lastModified < cutoffDate }
        )
        
        let expiredEvents = try modelContext.fetch(descriptor)
        
        for event in expiredEvents {
            modelContext.delete(event)
            result.deletedEvents += 1
        }
        
        if !expiredEvents.isEmpty {
            try modelContext.save()
        }
    }
}

// MARK: - Supporting Types

struct DataIntegrityReport {
    var totalEventsChecked: Int = 0
    var issues: [DataIntegrityIssue] = []
    var validationDate: Date = Date()
    
    var criticalIssues: [DataIntegrityIssue] {
        return issues.filter { $0.severity == .critical }
    }
    
    var highPriorityIssues: [DataIntegrityIssue] {
        return issues.filter { $0.severity == .high }
    }
    
    var isHealthy: Bool {
        return criticalIssues.isEmpty && highPriorityIssues.isEmpty
    }
}

struct DataIntegrityIssue: Identifiable {
    let id = UUID()
    let type: DataIntegrityIssueType
    let severity: DataIntegritySeverity
    let entity: String
    let entityId: String
    let field: String
    let message: String
    let suggestedFix: String
    let detectedAt: Date = Date()
}

enum DataIntegrityIssueType: String, CaseIterable {
    case invalidIdentifier = "invalid_identifier"
    case missingRequiredField = "missing_required_field"
    case invalidDateRange = "invalid_date_range"
    case inconsistentData = "inconsistent_data"
    case invalidVersion = "invalid_version"
    case invalidTimestamp = "invalid_timestamp"
    case brokenRelationship = "broken_relationship"
    case staleSyncState = "stale_sync_state"
    case permissionViolation = "permission_violation"
    
    var displayName: String {
        switch self {
        case .invalidIdentifier:
            return "Invalid Identifier"
        case .missingRequiredField:
            return "Missing Required Field"
        case .invalidDateRange:
            return "Invalid Date Range"
        case .inconsistentData:
            return "Inconsistent Data"
        case .invalidVersion:
            return "Invalid Version"
        case .invalidTimestamp:
            return "Invalid Timestamp"
        case .brokenRelationship:
            return "Broken Relationship"
        case .staleSyncState:
            return "Stale Sync State"
        case .permissionViolation:
            return "Permission Violation"
        }
    }
}

enum DataIntegritySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

struct DataIntegrityRepairResult {
    var repairedIssues: [DataIntegrityIssue] = []
    var failedRepairs: [DataIntegrityRepairFailure] = []
    
    var successRate: Double {
        let total = repairedIssues.count + failedRepairs.count
        return total > 0 ? Double(repairedIssues.count) / Double(total) : 0.0
    }
}

struct DataIntegrityRepairFailure {
    let issue: DataIntegrityIssue
    let error: Error
    let timestamp: Date
}

struct DataCleanupResult {
    var deletedEvents: Int = 0
    var fixedSyncStates: Int = 0
    var cleanupDate: Date = Date()
}