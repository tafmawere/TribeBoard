import Foundation
import SwiftData

/// Service for coordinating family calendar events, notifications, and invitations
@MainActor
class FamilyEventCoordinationService: ObservableObject {
    
    private let modelContext: ModelContext
    private let permissionManager: CalendarPermissionManager
    
    @Published var isLoading = false
    @Published var error: Error?
    
    init(modelContext: ModelContext, permissionManager: CalendarPermissionManager) {
        self.modelContext = modelContext
        self.permissionManager = permissionManager
    }
    
    // MARK: - Event Notifications
    
    /// Creates notifications for family members when an event is created
    func notifyFamilyEventCreated(
        event: CalendarEvent,
        createdBy: UUID,
        familyId: UUID
    ) async throws {
        guard event.privacyLevel == .familyShared else { return }
        
        print("📢 FamilyEventCoordinationService: Creating notifications for new family event: \(event.title)")
        
        // Get family members who should be notified
        let familyMembers = try await getFamilyMembersForNotification(familyId: familyId, excludeUserId: createdBy)
        
        for memberId in familyMembers {
            // Check if member has permission to view family events
            guard try permissionManager.hasPermission(
                userId: memberId,
                familyId: familyId,
                permission: .viewFamilyEvents
            ) else { continue }
            
            let notification = CalendarEventNotification(
                type: .eventCreated,
                eventId: event.id,
                recipientUserId: memberId,
                senderUserId: createdBy,
                familyId: familyId,
                title: "New Family Event",
                message: "A new event '\(event.title)' has been added to the family calendar",
                eventTitle: event.title,
                eventDate: event.startDate
            )
            
            modelContext.insert(notification)
        }
        
        try modelContext.save()
        print("✅ FamilyEventCoordinationService: Created notifications for \(familyMembers.count) family members")
    }
    
    /// Creates notifications for family members when an event is updated
    func notifyFamilyEventUpdated(
        event: CalendarEvent,
        updatedBy: UUID,
        familyId: UUID,
        changes: [String]
    ) async throws {
        guard event.privacyLevel == .familyShared else { return }
        
        print("📢 FamilyEventCoordinationService: Creating update notifications for family event: \(event.title)")
        
        let familyMembers = try await getFamilyMembersForNotification(familyId: familyId, excludeUserId: updatedBy)
        let changesText = changes.isEmpty ? "details" : changes.joined(separator: ", ")
        
        for memberId in familyMembers {
            guard try permissionManager.hasPermission(
                userId: memberId,
                familyId: familyId,
                permission: .viewFamilyEvents
            ) else { continue }
            
            let notification = CalendarEventNotification(
                type: .eventUpdated,
                eventId: event.id,
                recipientUserId: memberId,
                senderUserId: updatedBy,
                familyId: familyId,
                title: "Event Updated",
                message: "The event '\(event.title)' has been updated (\(changesText))",
                eventTitle: event.title,
                eventDate: event.startDate
            )
            
            modelContext.insert(notification)
        }
        
        try modelContext.save()
    }
    
    /// Creates notifications for family members when an event is deleted
    func notifyFamilyEventDeleted(
        event: CalendarEvent,
        deletedBy: UUID,
        familyId: UUID
    ) async throws {
        guard event.privacyLevel == .familyShared else { return }
        
        print("📢 FamilyEventCoordinationService: Creating deletion notifications for family event: \(event.title)")
        
        let familyMembers = try await getFamilyMembersForNotification(familyId: familyId, excludeUserId: deletedBy)
        
        for memberId in familyMembers {
            let notification = CalendarEventNotification(
                type: .eventDeleted,
                eventId: event.id,
                recipientUserId: memberId,
                senderUserId: deletedBy,
                familyId: familyId,
                title: "Event Deleted",
                message: "The event '\(event.title)' has been removed from the family calendar",
                eventTitle: event.title,
                eventDate: event.startDate
            )
            
            modelContext.insert(notification)
        }
        
        try modelContext.save()
    }
    
    /// Gets notifications for a specific user
    func getNotifications(
        for userId: UUID,
        familyId: UUID? = nil,
        unreadOnly: Bool = false
    ) throws -> [CalendarEventNotification] {
        var predicate = #Predicate<CalendarEventNotification> { notification in
            notification.recipientUserId == userId
        }
        
        if let familyId = familyId {
            predicate = #Predicate<CalendarEventNotification> { notification in
                notification.recipientUserId == userId && notification.familyId == familyId
            }
        }
        
        if unreadOnly {
            let originalPredicate = predicate
            predicate = #Predicate<CalendarEventNotification> { notification in
                originalPredicate.evaluate(notification) && !notification.isRead
            }
        }
        
        let descriptor = FetchDescriptor<CalendarEventNotification>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Marks notifications as read
    func markNotificationsAsRead(_ notifications: [CalendarEventNotification]) throws {
        for notification in notifications {
            notification.markAsRead()
        }
        try modelContext.save()
    }
    
    // MARK: - Event Invitations and RSVP
    
    /// Sends invitations for a family event
    func sendEventInvitations(
        event: CalendarEvent,
        invitedUserIds: [UUID],
        invitedBy: UUID,
        message: String? = nil
    ) async throws {
        guard event.privacyLevel == .familyShared,
              let familyId = event.familyId else {
            throw FamilyEventCoordinationError.invalidEvent
        }
        
        print("💌 FamilyEventCoordinationService: Sending invitations for event: \(event.title)")
        
        // Verify sender has permission to invite
        guard try permissionManager.hasPermission(
            userId: invitedBy,
            familyId: familyId,
            permission: .createEvents
        ) else {
            throw FamilyEventCoordinationError.insufficientPermissions
        }
        
        for invitedUserId in invitedUserIds {
            // Check if user already has an invitation
            if try hasExistingInvitation(eventId: event.id, userId: invitedUserId) {
                continue
            }
            
            // Create invitation
            let invitation = CalendarEventInvitation(
                eventId: event.id,
                invitedUserId: invitedUserId,
                invitedBy: invitedBy,
                familyId: familyId,
                invitationMessage: message
            )
            
            modelContext.insert(invitation)
            
            // Create notification
            let notification = CalendarEventNotification(
                type: .eventInvitation,
                eventId: event.id,
                recipientUserId: invitedUserId,
                senderUserId: invitedBy,
                familyId: familyId,
                title: "Event Invitation",
                message: message ?? "You've been invited to '\(event.title)'",
                eventTitle: event.title,
                eventDate: event.startDate
            )
            
            modelContext.insert(notification)
        }
        
        try modelContext.save()
        print("✅ FamilyEventCoordinationService: Sent invitations to \(invitedUserIds.count) users")
    }
    
    /// Responds to an event invitation
    func respondToInvitation(
        invitationId: UUID,
        response: EventResponseStatus,
        message: String? = nil
    ) throws {
        guard let invitation = try getInvitation(id: invitationId) else {
            throw FamilyEventCoordinationError.invitationNotFound
        }
        
        print("📝 FamilyEventCoordinationService: Responding to invitation with: \(response.displayName)")
        
        invitation.updateResponse(status: response, message: message)
        
        // Create notification for event creator
        let notification = CalendarEventNotification(
            type: .eventInvitation,
            eventId: invitation.eventId,
            recipientUserId: invitation.invitedBy,
            senderUserId: invitation.invitedUserId,
            familyId: invitation.familyId,
            title: "RSVP Response",
            message: "Response to '\(invitation.eventId)': \(response.displayName)",
            eventTitle: "",
            eventDate: Date()
        )
        
        modelContext.insert(notification)
        try modelContext.save()
    }
    
    /// Gets invitations for a user
    func getInvitations(
        for userId: UUID,
        status: EventResponseStatus? = nil
    ) throws -> [CalendarEventInvitation] {
        var predicate = #Predicate<CalendarEventInvitation> { invitation in
            invitation.invitedUserId == userId
        }
        
        if let status = status {
            predicate = #Predicate<CalendarEventInvitation> { invitation in
                invitation.invitedUserId == userId && invitation.responseStatus == status
            }
        }
        
        let descriptor = FetchDescriptor<CalendarEventInvitation>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.invitedAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Gets invitations for a specific event
    func getEventInvitations(eventId: UUID) throws -> [CalendarEventInvitation] {
        let descriptor = FetchDescriptor<CalendarEventInvitation>(
            predicate: #Predicate<CalendarEventInvitation> { invitation in
                invitation.eventId == eventId
            },
            sortBy: [SortDescriptor(\.invitedAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Gets RSVP summary for an event
    func getEventRSVPSummary(eventId: UUID) throws -> EventRSVPSummary {
        let invitations = try getEventInvitations(eventId: eventId)
        
        let accepted = invitations.filter { $0.responseStatus == .accepted }.count
        let declined = invitations.filter { $0.responseStatus == .declined }.count
        let tentative = invitations.filter { $0.responseStatus == .tentative }.count
        let pending = invitations.filter { $0.responseStatus == .pending }.count
        
        return EventRSVPSummary(
            totalInvited: invitations.count,
            accepted: accepted,
            declined: declined,
            tentative: tentative,
            pending: pending,
            invitations: invitations
        )
    }
    
    // MARK: - Bulk Operations
    
    /// Performs bulk event operations for family administrators
    func performBulkEventOperation(
        operation: BulkEventOperation,
        eventIds: [UUID],
        performedBy: UUID,
        familyId: UUID
    ) async throws {
        // Verify user has bulk operation permissions
        guard try permissionManager.hasPermission(
            userId: performedBy,
            familyId: familyId,
            permission: .bulkOperations
        ) else {
            throw FamilyEventCoordinationError.insufficientPermissions
        }
        
        print("🔄 FamilyEventCoordinationService: Performing bulk operation: \(operation) on \(eventIds.count) events")
        
        switch operation {
        case .delete:
            try await bulkDeleteEvents(eventIds: eventIds, deletedBy: performedBy, familyId: familyId)
        case .updatePrivacy(let newPrivacyLevel):
            try await bulkUpdateEventPrivacy(eventIds: eventIds, privacyLevel: newPrivacyLevel, updatedBy: performedBy, familyId: familyId)
        case .sendReminders:
            try await bulkSendEventReminders(eventIds: eventIds, sentBy: performedBy, familyId: familyId)
        }
    }
    
    /// Creates a family calendar dashboard summary
    func getFamilyCalendarDashboard(
        familyId: UUID,
        userId: UUID,
        dateRange: DateInterval
    ) async throws -> FamilyCalendarDashboard {
        // Verify user has access to family calendar
        guard try permissionManager.hasPermission(
            userId: userId,
            familyId: familyId,
            permission: .viewFamilyEvents
        ) else {
            throw FamilyEventCoordinationError.insufficientPermissions
        }
        
        // Get family events in date range
        let events = try await getFamilyEvents(familyId: familyId, dateRange: dateRange)
        
        // Get notifications
        let notifications = try getNotifications(for: userId, familyId: familyId, unreadOnly: true)
        
        // Get pending invitations
        let pendingInvitations = try getInvitations(for: userId, status: .pending)
        
        // Calculate statistics
        let upcomingEvents = events.filter { $0.startDate > Date() }
        let todayEvents = events.filter { Calendar.current.isDateInToday($0.startDate) }
        
        return FamilyCalendarDashboard(
            familyId: familyId,
            totalEvents: events.count,
            upcomingEvents: upcomingEvents.count,
            todayEvents: todayEvents.count,
            unreadNotifications: notifications.count,
            pendingInvitations: pendingInvitations.count,
            recentEvents: Array(events.prefix(5)),
            recentNotifications: Array(notifications.prefix(5)),
            dateRange: dateRange
        )
    }
    
    // MARK: - Helper Methods
    
    private func getFamilyMembersForNotification(familyId: UUID, excludeUserId: UUID) async throws -> [UUID] {
        // TODO: Integrate with family service to get actual family members
        // For now, return empty array as placeholder
        return []
    }
    
    private func getFamilyEvents(familyId: UUID, dateRange: DateInterval) async throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { event in
                event.familyId == familyId &&
                event.privacyLevel == CalendarEvent.PrivacyLevel.familyShared &&
                !event.isDeleted &&
                event.startDate >= dateRange.start &&
                event.startDate <= dateRange.end
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    private func hasExistingInvitation(eventId: UUID, userId: UUID) throws -> Bool {
        let descriptor = FetchDescriptor<CalendarEventInvitation>(
            predicate: #Predicate<CalendarEventInvitation> { invitation in
                invitation.eventId == eventId && invitation.invitedUserId == userId
            }
        )
        
        return !(try modelContext.fetch(descriptor).isEmpty)
    }
    
    private func getInvitation(id: UUID) throws -> CalendarEventInvitation? {
        let descriptor = FetchDescriptor<CalendarEventInvitation>(
            predicate: #Predicate<CalendarEventInvitation> { invitation in
                invitation.id == id
            }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    private func bulkDeleteEvents(eventIds: [UUID], deletedBy: UUID, familyId: UUID) async throws {
        for eventId in eventIds {
            // Get event and mark as deleted
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate<CalendarEvent> { event in
                    event.id == eventId && event.familyId == familyId
                }
            )
            
            if let event = try modelContext.fetch(descriptor).first {
                event.markAsDeleted(by: deletedBy)
                try await notifyFamilyEventDeleted(event: event, deletedBy: deletedBy, familyId: familyId)
            }
        }
        
        try modelContext.save()
    }
    
    private func bulkUpdateEventPrivacy(eventIds: [UUID], privacyLevel: CalendarEvent.PrivacyLevel, updatedBy: UUID, familyId: UUID) async throws {
        for eventId in eventIds {
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate<CalendarEvent> { event in
                    event.id == eventId && event.familyId == familyId
                }
            )
            
            if let event = try modelContext.fetch(descriptor).first {
                let oldPrivacy = event.privacyLevel
                event.privacyLevel = privacyLevel
                event.lastModified = Date()
                event.needsSync = true
                
                if oldPrivacy != privacyLevel {
                    try await notifyFamilyEventUpdated(
                        event: event,
                        updatedBy: updatedBy,
                        familyId: familyId,
                        changes: ["privacy level"]
                    )
                }
            }
        }
        
        try modelContext.save()
    }
    
    private func bulkSendEventReminders(eventIds: [UUID], sentBy: UUID, familyId: UUID) async throws {
        let familyMembers = try await getFamilyMembersForNotification(familyId: familyId, excludeUserId: sentBy)
        
        for eventId in eventIds {
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate<CalendarEvent> { event in
                    event.id == eventId && event.familyId == familyId
                }
            )
            
            if let event = try modelContext.fetch(descriptor).first {
                for memberId in familyMembers {
                    let notification = CalendarEventNotification(
                        type: .eventReminder,
                        eventId: event.id,
                        recipientUserId: memberId,
                        senderUserId: sentBy,
                        familyId: familyId,
                        title: "Event Reminder",
                        message: "Reminder: '\(event.title)' is coming up",
                        eventTitle: event.title,
                        eventDate: event.startDate
                    )
                    
                    modelContext.insert(notification)
                }
            }
        }
        
        try modelContext.save()
    }
}

// MARK: - Supporting Types

/// Bulk event operations
enum BulkEventOperation {
    case delete
    case updatePrivacy(CalendarEvent.PrivacyLevel)
    case sendReminders
}

/// RSVP summary for an event
struct EventRSVPSummary {
    let totalInvited: Int
    let accepted: Int
    let declined: Int
    let tentative: Int
    let pending: Int
    let invitations: [CalendarEventInvitation]
    
    var responseRate: Double {
        guard totalInvited > 0 else { return 0 }
        return Double(totalInvited - pending) / Double(totalInvited)
    }
    
    var acceptanceRate: Double {
        guard totalInvited > 0 else { return 0 }
        return Double(accepted) / Double(totalInvited)
    }
}

/// Family calendar dashboard data
struct FamilyCalendarDashboard {
    let familyId: UUID
    let totalEvents: Int
    let upcomingEvents: Int
    let todayEvents: Int
    let unreadNotifications: Int
    let pendingInvitations: Int
    let recentEvents: [CalendarEvent]
    let recentNotifications: [CalendarEventNotification]
    let dateRange: DateInterval
}

/// Family event coordination errors
enum FamilyEventCoordinationError: LocalizedError {
    case invalidEvent
    case insufficientPermissions
    case invitationNotFound
    case userNotInFamily
    
    var errorDescription: String? {
        switch self {
        case .invalidEvent:
            return "Invalid event for family coordination"
        case .insufficientPermissions:
            return "Insufficient permissions for this operation"
        case .invitationNotFound:
            return "Event invitation not found"
        case .userNotInFamily:
            return "User is not a member of this family"
        }
    }
}