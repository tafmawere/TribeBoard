import Foundation
import EventKit

/// EventKit integration extensions for CalendarEvent
extension CalendarEvent {
    
    // MARK: - EventKit Constants
    
    /// Constants for EventKit integration
    enum EventKitConstants {
        static let tribeBoardCalendarName = "TribeBoard"
        static let tribeBoardFamilyCalendarName = "TribeBoard Family"
        static let tribeBoardPersonalCalendarName = "TribeBoard Personal"
        static let metadataPrefix = "[TribeBoard:"
        static let metadataSuffix = "]"
        static let privacyLevelKey = "PrivacyLevel"
        static let eventIdKey = "EventId"
        static let familyIdKey = "FamilyId"
    }
    
    // MARK: - EventKit Conversion
    
    /// Creates an EKEvent from this CalendarEvent
    func toEKEvent(in eventStore: EKEventStore, calendar: EKCalendar) -> EKEvent {
        let ekEvent = EKEvent(eventStore: eventStore)
        
        // Basic properties
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate
        ekEvent.isAllDay = isAllDay
        ekEvent.location = location
        ekEvent.calendar = calendar
        
        // Combine notes with metadata
        var combinedNotes = notes ?? ""
        let metadata = createEventKitMetadata()
        
        if !combinedNotes.isEmpty {
            combinedNotes += "\n\n"
        }
        combinedNotes += metadata
        
        ekEvent.notes = combinedNotes
        
        return ekEvent
    }
    
    /// Updates this CalendarEvent from an EKEvent
    func updateFromEKEvent(_ ekEvent: EKEvent, modifiedBy: UUID) {
        // Update basic properties
        self.title = ekEvent.title ?? ""
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.location = ekEvent.location
        
        // Extract notes without metadata
        if let eventNotes = ekEvent.notes {
            self.notes = CalendarEvent.extractNotesFromEventKit(eventNotes)
        } else {
            self.notes = nil
        }
        
        // Update modification tracking
        self.modifiedBy = modifiedBy
        self.lastModified = Date()
        self.version += 1
        self.needsSync = true
    }
    
    /// Creates a new CalendarEvent from an EKEvent
    static func fromEKEvent(
        _ ekEvent: EKEvent,
        createdBy: UUID,
        familyId: UUID? = nil,
        defaultPrivacyLevel: PrivacyLevel = .personal
    ) -> CalendarEvent {
        // Extract metadata if present
        let metadata = extractEventKitMetadata(from: ekEvent.notes)
        let privacyLevel = metadata[EventKitConstants.privacyLevelKey].flatMap { PrivacyLevel(rawValue: $0) } ?? defaultPrivacyLevel
        let extractedFamilyId = metadata[EventKitConstants.familyIdKey].flatMap { UUID(uuidString: $0) } ?? familyId
        
        let event = CalendarEvent(
            title: ekEvent.title ?? "",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            location: ekEvent.location,
            notes: extractNotesFromEventKit(ekEvent.notes),
            privacyLevel: privacyLevel,
            createdBy: createdBy,
            familyId: extractedFamilyId
        )
        
        // Set EventKit identifiers
        event.eventKitIdentifier = ekEvent.eventIdentifier
        event.eventKitCalendarIdentifier = ekEvent.calendar?.calendarIdentifier
        
        return event
    }
    
    // MARK: - EventKit Metadata Management
    
    /// Creates metadata string for EventKit notes
    private func createEventKitMetadata() -> String {
        var metadata: [String] = []
        
        // Add privacy level
        metadata.append("\(EventKitConstants.privacyLevelKey): \(privacyLevel.rawValue)")
        
        // Add event ID
        metadata.append("\(EventKitConstants.eventIdKey): \(id.uuidString)")
        
        // Add family ID if present
        if let familyId = familyId {
            metadata.append("\(EventKitConstants.familyIdKey): \(familyId.uuidString)")
        }
        
        return "\(EventKitConstants.metadataPrefix) \(metadata.joined(separator: ", ")) \(EventKitConstants.metadataSuffix)"
    }
    
    /// Extracts metadata from EventKit notes
    private static func extractEventKitMetadata(from notes: String?) -> [String: String] {
        guard let notes = notes else { return [:] }
        
        // Find metadata section
        guard let startRange = notes.range(of: EventKitConstants.metadataPrefix),
              let endRange = notes.range(of: EventKitConstants.metadataSuffix, range: startRange.upperBound..<notes.endIndex) else {
            return [:]
        }
        
        let metadataString = String(notes[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        
        // Parse key-value pairs
        var metadata: [String: String] = [:]
        let pairs = metadataString.components(separatedBy: ", ")
        
        for pair in pairs {
            let components = pair.components(separatedBy: ": ")
            if components.count == 2 {
                let key = components[0].trimmingCharacters(in: .whitespaces)
                let value = components[1].trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }
        
        return metadata
    }
    
    /// Extracts notes without TribeBoard metadata
    private static func extractNotesFromEventKit(_ notes: String?) -> String? {
        guard let notes = notes else { return nil }
        
        // Find and remove metadata section
        if let startRange = notes.range(of: EventKitConstants.metadataPrefix) {
            let beforeMetadata = String(notes[..<startRange.lowerBound])
            
            if let endRange = notes.range(of: EventKitConstants.metadataSuffix, range: startRange.upperBound..<notes.endIndex) {
                let afterMetadata = String(notes[endRange.upperBound...])
                let cleanNotes = (beforeMetadata + afterMetadata).trimmingCharacters(in: .whitespacesAndNewlines)
                return cleanNotes.isEmpty ? nil : cleanNotes
            } else {
                // Metadata start found but no end - remove everything from start
                let cleanNotes = beforeMetadata.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleanNotes.isEmpty ? nil : cleanNotes
            }
        }
        
        // No metadata found - return original notes
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanNotes.isEmpty ? nil : cleanNotes
    }
    
    // MARK: - EventKit Matching
    
    /// Checks if this CalendarEvent matches an EKEvent
    func matchesEKEvent(_ ekEvent: EKEvent) -> Bool {
        // First check by EventKit identifier if available
        if let eventKitId = eventKitIdentifier,
           eventKitId == ekEvent.eventIdentifier {
            return true
        }
        
        // Check by metadata if present
        let metadata = Self.extractEventKitMetadata(from: ekEvent.notes)
        if let eventIdString = metadata[EventKitConstants.eventIdKey],
           let eventId = UUID(uuidString: eventIdString),
           eventId == id {
            return true
        }
        
        // Fallback to property matching
        return matchesEKEventProperties(ekEvent)
    }
    
    /// Checks if this CalendarEvent matches an EKEvent by properties
    private func matchesEKEventProperties(_ ekEvent: EKEvent) -> Bool {
        let titleMatches = title == (ekEvent.title ?? "")
        let startDateMatches = abs(startDate.timeIntervalSince(ekEvent.startDate)) < 60 // Within 1 minute
        let endDateMatches = abs(endDate.timeIntervalSince(ekEvent.endDate)) < 60 // Within 1 minute
        let allDayMatches = isAllDay == ekEvent.isAllDay
        
        return titleMatches && startDateMatches && endDateMatches && allDayMatches
    }
    
    /// Checks if an EKEvent was created by TribeBoard
    static func isEKEventFromTribeBoard(_ ekEvent: EKEvent) -> Bool {
        guard let notes = ekEvent.notes else { return false }
        return notes.contains(EventKitConstants.metadataPrefix)
    }
    
    /// Extracts TribeBoard event ID from an EKEvent
    static func extractTribeBoardEventId(from ekEvent: EKEvent) -> UUID? {
        let metadata = extractEventKitMetadata(from: ekEvent.notes)
        guard let eventIdString = metadata[EventKitConstants.eventIdKey] else { return nil }
        return UUID(uuidString: eventIdString)
    }
    
    /// Extracts family ID from an EKEvent
    static func extractFamilyId(from ekEvent: EKEvent) -> UUID? {
        let metadata = extractEventKitMetadata(from: ekEvent.notes)
        guard let familyIdString = metadata[EventKitConstants.familyIdKey] else { return nil }
        return UUID(uuidString: familyIdString)
    }
    
    /// Extracts privacy level from an EKEvent
    static func extractPrivacyLevel(from ekEvent: EKEvent) -> PrivacyLevel? {
        let metadata = extractEventKitMetadata(from: ekEvent.notes)
        guard let privacyLevelString = metadata[EventKitConstants.privacyLevelKey] else { return nil }
        return PrivacyLevel(rawValue: privacyLevelString)
    }
    
    // MARK: - EventKit Validation
    
    /// Validates that the event can be synced to EventKit
    var canSyncToEventKit: Bool {
        return isFullyValid && !isDeleted
    }
    
    /// Returns validation errors for EventKit sync
    var eventKitSyncValidationErrors: [String] {
        var errors: [String] = []
        
        if !isTitleValid {
            errors.append("Event title is required and must be between 1-200 characters")
        }
        
        if !isDateRangeValid {
            errors.append("Event end date must be after start date")
        }
        
        if !isDurationValid {
            errors.append("Event duration cannot exceed 24 hours for timed events")
        }
        
        if isDeleted {
            errors.append("Deleted events cannot be synced")
        }
        
        return errors
    }
    
    // MARK: - EventKit Calendar Management
    
    /// Determines the appropriate calendar for this event
    func getTargetCalendar(
        familyCalendar: EKCalendar?,
        personalCalendar: EKCalendar?,
        defaultCalendar: EKCalendar
    ) -> EKCalendar {
        switch privacyLevel {
        case .familyShared:
            return familyCalendar ?? defaultCalendar
        case .personal:
            return personalCalendar ?? defaultCalendar
        }
    }
    
    /// Returns the calendar name for this event's privacy level
    var targetCalendarName: String {
        switch privacyLevel {
        case .familyShared:
            return EventKitConstants.tribeBoardFamilyCalendarName
        case .personal:
            return EventKitConstants.tribeBoardPersonalCalendarName
        }
    }
}

// MARK: - EventKit Sync Status
extension CalendarEvent {
    
    /// Sync status for EventKit integration
    enum EventKitSyncStatus {
        case notSynced
        case synced
        case needsSync
        case syncError
        case deleted
        
        var displayName: String {
            switch self {
            case .notSynced:
                return "Not Synced"
            case .synced:
                return "Synced"
            case .needsSync:
                return "Needs Sync"
            case .syncError:
                return "Sync Error"
            case .deleted:
                return "Deleted"
            }
        }
        
        var icon: String {
            switch self {
            case .notSynced:
                return "circle"
            case .synced:
                return "checkmark.circle.fill"
            case .needsSync:
                return "arrow.clockwise.circle"
            case .syncError:
                return "exclamationmark.circle.fill"
            case .deleted:
                return "trash.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .notSynced:
                return "gray"
            case .synced:
                return "green"
            case .needsSync:
                return "blue"
            case .syncError:
                return "red"
            case .deleted:
                return "red"
            }
        }
    }
    
    /// Returns the current EventKit sync status
    var eventKitSyncStatus: EventKitSyncStatus {
        if isDeleted {
            return .deleted
        } else if needsEventKitSync {
            return .needsSync
        } else if eventKitIdentifier != nil {
            return .synced
        } else {
            return .notSynced
        }
    }
}