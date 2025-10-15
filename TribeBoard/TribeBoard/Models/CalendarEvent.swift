import Foundation
import SwiftData
import CloudKit
import EventKit

/**
 * CalendarEvent - Production SwiftData model for calendar events
 * 
 * TYPE CONFLICT PREVENTION:
 * This is the PRODUCTION SwiftData model for calendar events. 
 * 
 * DO NOT create other types with the same name "CalendarEvent" in this codebase.
 * For mock/demo data, use "MockCalendarEvent" (see MockDataGenerator.swift).
 * For test data, use "TestCalendarEvent" or similar prefixed names.
 * 
 * This naming separation prevents type ambiguity compilation errors.
 * Always import this specific type when you need the production calendar event model.
 */
@Model
final class CalendarEvent {
    // Primary identifier
    var id: UUID = UUID()
    
    // Core event properties
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var isAllDay: Bool = false
    var location: String?
    var notes: String?
    
    // Privacy and sharing properties
    var privacyLevel: PrivacyLevel = PrivacyLevel.personal
    var createdBy: UUID = UUID()
    var familyId: UUID?
    var participants: [UUID] = []
    
    // EventKit integration properties
    var eventKitIdentifier: String?
    var eventKitCalendarIdentifier: String?
    
    // Sync and metadata properties
    var lastModified: Date = Date()
    var isDeleted: Bool = false
    var needsSync: Bool = true
    var needsEventKitSync: Bool = false
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    
    // Audit properties
    var createdAt: Date = Date()
    var modifiedBy: UUID?
    var version: Int = 1
    
    init(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: PrivacyLevel = .personal,
        createdBy: UUID,
        familyId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.privacyLevel = privacyLevel
        self.createdBy = createdBy
        self.familyId = familyId
        self.lastModified = Date()
        self.createdAt = Date()
        self.needsSync = true
        self.needsEventKitSync = false
        self.isDeleted = false
        self.version = 1
    }
    
    // MARK: - Privacy Level Enum
    
    enum PrivacyLevel: String, CaseIterable, Codable {
        case familyShared = "family_shared"
        case personal = "personal"
        
        var displayName: String {
            switch self {
            case .familyShared:
                return "Family Shared"
            case .personal:
                return "Personal"
            }
        }
        
        var description: String {
            switch self {
            case .familyShared:
                return "Visible to all family members"
            case .personal:
                return "Visible only to you"
            }
        }
        
        var icon: String {
            switch self {
            case .familyShared:
                return "person.2.fill"
            case .personal:
                return "person.fill"
            }
        }
    }
    
    // MARK: - Validation
    
    /// Validates the event title
    var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count >= 1 &&
        title.count <= 200
    }
    
    /// Validates the event date range
    var isDateRangeValid: Bool {
        if isAllDay {
            // For all-day events, start and end should be on the same day or end after start
            return Calendar.current.compare(startDate, to: endDate, toGranularity: .day) != .orderedDescending
        } else {
            // For timed events, end must be after start
            return endDate > startDate
        }
    }
    
    /// Validates event duration (max 24 hours for non-all-day events)
    var isDurationValid: Bool {
        if isAllDay {
            return true // All-day events can span multiple days
        } else {
            let duration = endDate.timeIntervalSince(startDate)
            return duration > 0 && duration <= 24 * 60 * 60 // Max 24 hours
        }
    }
    
    /// Validates family sharing requirements
    var isFamilySharingValid: Bool {
        if privacyLevel == .familyShared {
            return familyId != nil
        }
        return true // Personal events don't need family ID
    }
    
    /// Validates all event properties
    var isFullyValid: Bool {
        isTitleValid && isDateRangeValid && isDurationValid && isFamilySharingValid
    }
    
    // MARK: - Computed Properties
    
    /// Returns the event duration in seconds
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    /// Returns the event duration formatted as a string
    var durationString: String {
        if isAllDay {
            let dayCount = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            return dayCount <= 1 ? "All day" : "\(dayCount + 1) days"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            
            if hours > 0 {
                return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
            } else {
                return "\(minutes)m"
            }
        }
    }
    
    /// Checks if the event is happening today
    var isToday: Bool {
        Calendar.current.isDate(startDate, inSameDayAs: Date())
    }
    
    /// Checks if the event is in the past
    var isPast: Bool {
        endDate < Date()
    }
    
    /// Checks if the event is currently happening
    var isHappening: Bool {
        let now = Date()
        return startDate <= now && now <= endDate
    }
    
    /// Checks if the event is upcoming (starts in the future)
    var isUpcoming: Bool {
        startDate > Date()
    }
    
    /// Returns a formatted date range string
    var dateRangeString: String {
        let formatter = DateFormatter()
        
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            
            if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                return formatter.string(from: startDate)
            } else {
                return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        } else {
            if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                // Same day - show date once with time range
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let dateString = formatter.string(from: startDate)
                
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                let startTime = formatter.string(from: startDate)
                let endTime = formatter.string(from: endDate)
                
                return "\(dateString), \(startTime) - \(endTime)"
            } else {
                // Different days - show full date and time for both
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        }
    }
    
    // MARK: - Event Management
    
    /// Updates the event and marks it for sync
    func updateEvent(
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool? = nil,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: PrivacyLevel? = nil,
        modifiedBy: UUID
    ) {
        if let title = title { self.title = title }
        if let startDate = startDate { self.startDate = startDate }
        if let endDate = endDate { self.endDate = endDate }
        if let isAllDay = isAllDay { self.isAllDay = isAllDay }
        if let location = location { self.location = location }
        if let notes = notes { self.notes = notes }
        if let privacyLevel = privacyLevel { self.privacyLevel = privacyLevel }
        
        self.modifiedBy = modifiedBy
        self.lastModified = Date()
        self.version += 1
        self.needsSync = true
        self.needsEventKitSync = true
    }
    
    /// Marks the event as deleted (soft delete)
    func markAsDeleted(by userId: UUID) {
        self.isDeleted = true
        self.modifiedBy = userId
        self.lastModified = Date()
        self.version += 1
        self.needsSync = true
        self.needsEventKitSync = true
    }
    
    /// Marks the event as synced with CloudKit
    func markAsSynced(recordID: String) {
        self.ckRecordID = recordID
        self.lastSyncDate = Date()
        self.needsSync = false
    }
    
    /// Marks the event as synced with EventKit
    func markAsEventKitSynced(eventIdentifier: String, calendarIdentifier: String) {
        self.eventKitIdentifier = eventIdentifier
        self.eventKitCalendarIdentifier = calendarIdentifier
        self.needsEventKitSync = false
    }
    
    /// Creates a copy of the event for editing
    func createCopy() -> CalendarEvent {
        let copy = CalendarEvent(
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
        return copy
    }
}

// MARK: - EventKit Integration Extensions


// MARK: - CloudKit Synchronization
extension CalendarEvent: CloudKitSyncable {
    static var recordType: String { "CalendarEvent" }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        // Core properties
        record["title"] = title
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["isAllDay"] = isAllDay ? 1 : 0
        record["location"] = location
        record["notes"] = notes
        
        // Privacy and sharing
        record["privacyLevel"] = privacyLevel.rawValue
        record["createdBy"] = createdBy.uuidString
        record["familyId"] = familyId?.uuidString
        
        // EventKit integration
        record["eventKitIdentifier"] = eventKitIdentifier
        record["eventKitCalendarIdentifier"] = eventKitCalendarIdentifier
        
        // Metadata
        record["lastModified"] = lastModified
        record["isDeleted"] = isDeleted ? 1 : 0
        record["createdAt"] = createdAt
        record["modifiedBy"] = modifiedBy?.uuidString
        record["version"] = version
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let title = record["title"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let isAllDayInt = record["isAllDay"] as? Int,
              let privacyLevelString = record["privacyLevel"] as? String,
              let privacyLevel = PrivacyLevel(rawValue: privacyLevelString),
              let createdByString = record["createdBy"] as? String,
              let createdBy = UUID(uuidString: createdByString),
              let lastModified = record["lastModified"] as? Date,
              let isDeletedInt = record["isDeleted"] as? Int,
              let createdAt = record["createdAt"] as? Date,
              let version = record["version"] as? Int else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDayInt == 1
        self.location = record["location"] as? String
        self.notes = record["notes"] as? String
        self.privacyLevel = privacyLevel
        self.createdBy = createdBy
        self.lastModified = lastModified
        self.isDeleted = isDeletedInt == 1
        self.createdAt = createdAt
        self.version = version
        
        // Optional properties
        if let familyIdString = record["familyId"] as? String {
            self.familyId = UUID(uuidString: familyIdString)
        }
        
        if let modifiedByString = record["modifiedBy"] as? String {
            self.modifiedBy = UUID(uuidString: modifiedByString)
        }
        
        self.eventKitIdentifier = record["eventKitIdentifier"] as? String
        self.eventKitCalendarIdentifier = record["eventKitCalendarIdentifier"] as? String
        
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}

// MARK: - Hashable and Equatable
extension CalendarEvent: Hashable {
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Comparable for sorting
extension CalendarEvent: Comparable {
    static func < (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.startDate < rhs.startDate
    }
}