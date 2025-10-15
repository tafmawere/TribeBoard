import Foundation
import SwiftData
import CloudKit

/// Types of calendar event notifications
enum CalendarNotificationType: String, CaseIterable, Codable, Sendable {
    case eventCreated = "event_created"
    case eventUpdated = "event_updated"
    case eventDeleted = "event_deleted"
    case eventInvitation = "event_invitation"
    case eventReminder = "event_reminder"
    case eventConflict = "event_conflict"
    
    var displayName: String {
        switch self {
        case .eventCreated:
            return "Event Created"
        case .eventUpdated:
            return "Event Updated"
        case .eventDeleted:
            return "Event Deleted"
        case .eventInvitation:
            return "Event Invitation"
        case .eventReminder:
            return "Event Reminder"
        case .eventConflict:
            return "Event Conflict"
        }
    }
    
    var icon: String {
        switch self {
        case .eventCreated:
            return "calendar.badge.plus"
        case .eventUpdated:
            return "calendar.badge.exclamationmark"
        case .eventDeleted:
            return "calendar.badge.minus"
        case .eventInvitation:
            return "envelope.fill"
        case .eventReminder:
            return "bell.fill"
        case .eventConflict:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .eventCreated:
            return "green"
        case .eventUpdated:
            return "blue"
        case .eventDeleted:
            return "red"
        case .eventInvitation:
            return "purple"
        case .eventReminder:
            return "orange"
        case .eventConflict:
            return "red"
        }
    }
}

/// Status of event invitations and RSVPs
enum EventResponseStatus: String, CaseIterable, Codable, Sendable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case tentative = "tentative"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        case .tentative:
            return "Maybe"
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .accepted:
            return "checkmark.circle.fill"
        case .declined:
            return "xmark.circle.fill"
        case .tentative:
            return "questionmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .accepted:
            return "green"
        case .declined:
            return "red"
        case .tentative:
            return "yellow"
        }
    }
}

/// SwiftData model for calendar event notifications
@Model
final class CalendarEventNotification {
    // Primary identifier
    var id: UUID = UUID()
    
    // Core properties
    var type: CalendarNotificationType = CalendarNotificationType.eventCreated
    var eventId: UUID = UUID()
    var recipientUserId: UUID = UUID()
    var senderUserId: UUID = UUID()
    var familyId: UUID = UUID()
    
    // Notification content
    var title: String = ""
    var message: String = ""
    var eventTitle: String = ""
    var eventDate: Date = Date()
    
    // Status and metadata
    var isRead: Bool = false
    var isDelivered: Bool = false
    var createdAt: Date = Date()
    var readAt: Date?
    var deliveredAt: Date?
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    var needsSync: Bool = true
    
    init(
        type: CalendarNotificationType,
        eventId: UUID,
        recipientUserId: UUID,
        senderUserId: UUID,
        familyId: UUID,
        title: String,
        message: String,
        eventTitle: String,
        eventDate: Date
    ) {
        self.id = UUID()
        self.type = type
        self.eventId = eventId
        self.recipientUserId = recipientUserId
        self.senderUserId = senderUserId
        self.familyId = familyId
        self.title = title
        self.message = message
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.isRead = false
        self.isDelivered = false
        self.createdAt = Date()
        self.needsSync = true
    }
    
    // MARK: - Status Management
    
    /// Marks the notification as read
    func markAsRead() {
        guard !isRead else { return }
        
        isRead = true
        readAt = Date()
        needsSync = true
    }
    
    /// Marks the notification as delivered
    func markAsDelivered() {
        guard !isDelivered else { return }
        
        isDelivered = true
        deliveredAt = Date()
        needsSync = true
    }
    
    /// Checks if the notification is recent (within 24 hours)
    var isRecent: Bool {
        let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return createdAt > dayAgo
    }
    
    /// Gets the time since creation as a formatted string
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// Marks the record as synced
    func markAsSynced(recordID: String) {
        ckRecordID = recordID
        lastSyncDate = Date()
        needsSync = false
    }
}

/// SwiftData model for event invitations and RSVP tracking
@Model
final class CalendarEventInvitation {
    // Primary identifier
    var id: UUID = UUID()
    
    // Core properties
    var eventId: UUID = UUID()
    var invitedUserId: UUID = UUID()
    var invitedBy: UUID = UUID()
    var familyId: UUID = UUID()
    
    // Invitation details
    var invitationMessage: String?
    var responseStatus: EventResponseStatus = EventResponseStatus.pending
    var responseMessage: String?
    
    // Timestamps
    var invitedAt: Date = Date()
    var respondedAt: Date?
    var lastModified: Date = Date()
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    var needsSync: Bool = true
    
    init(
        eventId: UUID,
        invitedUserId: UUID,
        invitedBy: UUID,
        familyId: UUID,
        invitationMessage: String? = nil
    ) {
        self.id = UUID()
        self.eventId = eventId
        self.invitedUserId = invitedUserId
        self.invitedBy = invitedBy
        self.familyId = familyId
        self.invitationMessage = invitationMessage
        self.responseStatus = .pending
        self.invitedAt = Date()
        self.lastModified = Date()
        self.needsSync = true
    }
    
    // MARK: - Response Management
    
    /// Updates the RSVP response
    func updateResponse(
        status: EventResponseStatus,
        message: String? = nil
    ) {
        responseStatus = status
        responseMessage = message
        respondedAt = Date()
        lastModified = Date()
        needsSync = true
    }
    
    /// Checks if the invitation is still pending
    var isPending: Bool {
        responseStatus == .pending
    }
    
    /// Checks if the invitation was accepted
    var isAccepted: Bool {
        responseStatus == .accepted
    }
    
    /// Checks if the invitation was declined
    var isDeclined: Bool {
        responseStatus == .declined
    }
    
    /// Marks the record as synced
    func markAsSynced(recordID: String) {
        ckRecordID = recordID
        lastSyncDate = Date()
        needsSync = false
    }
}

// MARK: - CloudKit Synchronization
extension CalendarEventNotification: CloudKitSyncable {
    static var recordType: String { "CalendarEventNotification" }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record["type"] = type.rawValue
        record["eventId"] = eventId.uuidString
        record["recipientUserId"] = recipientUserId.uuidString
        record["senderUserId"] = senderUserId.uuidString
        record["familyId"] = familyId.uuidString
        record["title"] = title
        record["message"] = message
        record["eventTitle"] = eventTitle
        record["eventDate"] = eventDate
        record["isRead"] = isRead ? 1 : 0
        record["isDelivered"] = isDelivered ? 1 : 0
        record["createdAt"] = createdAt
        record["readAt"] = readAt
        record["deliveredAt"] = deliveredAt
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let typeString = record["type"] as? String,
              let type = CalendarNotificationType(rawValue: typeString),
              let eventIdString = record["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let recipientUserIdString = record["recipientUserId"] as? String,
              let recipientUserId = UUID(uuidString: recipientUserIdString),
              let senderUserIdString = record["senderUserId"] as? String,
              let senderUserId = UUID(uuidString: senderUserIdString),
              let familyIdString = record["familyId"] as? String,
              let familyId = UUID(uuidString: familyIdString),
              let title = record["title"] as? String,
              let message = record["message"] as? String,
              let eventTitle = record["eventTitle"] as? String,
              let eventDate = record["eventDate"] as? Date,
              let isReadInt = record["isRead"] as? Int,
              let isDeliveredInt = record["isDelivered"] as? Int,
              let createdAt = record["createdAt"] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.type = type
        self.eventId = eventId
        self.recipientUserId = recipientUserId
        self.senderUserId = senderUserId
        self.familyId = familyId
        self.title = title
        self.message = message
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.isRead = isReadInt == 1
        self.isDelivered = isDeliveredInt == 1
        self.createdAt = createdAt
        self.readAt = record["readAt"] as? Date
        self.deliveredAt = record["deliveredAt"] as? Date
        
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}

extension CalendarEventInvitation: CloudKitSyncable {
    static var recordType: String { "CalendarEventInvitation" }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record["eventId"] = eventId.uuidString
        record["invitedUserId"] = invitedUserId.uuidString
        record["invitedBy"] = invitedBy.uuidString
        record["familyId"] = familyId.uuidString
        record["invitationMessage"] = invitationMessage
        record["responseStatus"] = responseStatus.rawValue
        record["responseMessage"] = responseMessage
        record["invitedAt"] = invitedAt
        record["respondedAt"] = respondedAt
        record["lastModified"] = lastModified
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let eventIdString = record["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let invitedUserIdString = record["invitedUserId"] as? String,
              let invitedUserId = UUID(uuidString: invitedUserIdString),
              let invitedByString = record["invitedBy"] as? String,
              let invitedBy = UUID(uuidString: invitedByString),
              let familyIdString = record["familyId"] as? String,
              let familyId = UUID(uuidString: familyIdString),
              let responseStatusString = record["responseStatus"] as? String,
              let responseStatus = EventResponseStatus(rawValue: responseStatusString),
              let invitedAt = record["invitedAt"] as? Date,
              let lastModified = record["lastModified"] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.eventId = eventId
        self.invitedUserId = invitedUserId
        self.invitedBy = invitedBy
        self.familyId = familyId
        self.invitationMessage = record["invitationMessage"] as? String
        self.responseStatus = responseStatus
        self.responseMessage = record["responseMessage"] as? String
        self.invitedAt = invitedAt
        self.respondedAt = record["respondedAt"] as? Date
        self.lastModified = lastModified
        
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}