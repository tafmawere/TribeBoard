import Foundation
import SwiftData

/// Service for integrating calendar functionality with family management
@MainActor
class FamilyCalendarIntegrationService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let calendarService: CalendarService
    private let permissionManager: CalendarPermissionManager
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        calendarService: CalendarService,
        permissionManager: CalendarPermissionManager
    ) {
        self.modelContext = modelContext
        self.calendarService = calendarService
        self.permissionManager = permissionManager
        print("🔗 FamilyCalendarIntegrationService: Initialized")
    }
    
    // MARK: - Family Calendar Setup
    
    /// Sets up calendar permissions for a new family member
    func setupCalendarPermissionsForNewMember(_ membership: Membership) async throws {
        print("🔗 FamilyCalendarIntegrationService: Setting up calendar permissions for new member: \(membership.userId ?? UUID())")
        
        guard let userId = membership.userId,
              let familyId = membership.familyId else {
            throw FamilyCalendarIntegrationError.invalidMembership
        }
        
        // Check if permissions already exist
        let existingPermission = try permissionManager.getCalendarPermission(
            userId: userId,
            familyId: familyId
        )
        
        if existingPermission != nil {
            print("📋 FamilyCalendarIntegrationService: Calendar permissions already exist for user")
            return
        }
        
        // Create default calendar permission based on role
        if let defaultPermission = membership.createDefaultCalendarPermission() {
            modelContext.insert(defaultPermission)
            try modelContext.save()
            print("✅ FamilyCalendarIntegrationService: Created default calendar permissions for role: \(membership.role)")
        }
    }
    
    /// Updates calendar permissions when a family member's role changes
    func updateCalendarPermissionsForRoleChange(
        membership: Membership,
        oldRole: Role,
        newRole: Role,
        changedBy: UUID
    ) async throws {
        print("🔗 FamilyCalendarIntegrationService: Updating calendar permissions for role change: \(oldRole) -> \(newRole)")
        
        guard let userId = membership.userId,
              let familyId = membership.familyId else {
            throw FamilyCalendarIntegrationError.invalidMembership
        }
        
        // Get existing permission
        guard let permission = try permissionManager.getCalendarPermission(
            userId: userId,
            familyId: familyId
        ) else {
            // Create new permission if none exists
            try await setupCalendarPermissionsForNewMember(membership)
            return
        }
        
        // Update permission level based on new role
        let newPermissionLevel = CalendarPermissionLevel.defaultForRole(newRole)
        permission.updatePermissionLevel(newPermissionLevel, grantedBy: changedBy)
        
        try modelContext.save()
        print("✅ FamilyCalendarIntegrationService: Updated calendar permission level to: \(newPermissionLevel)")
    }
    
    /// Removes calendar permissions when a member is removed from the family
    func removeCalendarPermissionsForMember(
        userId: UUID,
        familyId: UUID,
        removedBy: UUID
    ) async throws {
        print("🔗 FamilyCalendarIntegrationService: Removing calendar permissions for removed member: \(userId)")
        
        // Get and deactivate permission
        if let permission = try permissionManager.getCalendarPermission(
            userId: userId,
            familyId: familyId
        ) {
            permission.deactivate()
            try modelContext.save()
            print("✅ FamilyCalendarIntegrationService: Deactivated calendar permissions")
        }
        
        // Optionally, handle existing events created by this user
        // For now, we'll leave them as they are for data integrity
        print("📋 FamilyCalendarIntegrationService: Existing events by removed member will remain visible to family")
    }
    
    // MARK: - Family Calendar Dashboard Integration
    
    /// Gets calendar data for family dashboard display
    func getFamilyCalendarDashboardData(
        familyId: UUID,
        userId: UUID
    ) async throws -> FamilyCalendarDashboardData {
        print("🔗 FamilyCalendarIntegrationService: Getting calendar dashboard data for family: \(familyId)")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Check user permissions
            let permissions = try await calendarService.getFamilyCalendarPermissions(
                userId: userId,
                familyId: familyId
            )
            
            guard permissions.hasAccess else {
                throw FamilyCalendarIntegrationError.noCalendarAccess
            }
            
            // Get upcoming events (next 7 days)
            let now = Date()
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            let dateRange = DateInterval(start: now, end: nextWeek)
            
            let upcomingEvents = try await calendarService.fetchFamilyEventsForUser(
                userId,
                familyId: familyId,
                dateRange: dateRange
            )
            
            // Get today's events
            let todayStart = Calendar.current.startOfDay(for: now)
            let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? now
            let todayRange = DateInterval(start: todayStart, end: todayEnd)
            
            let todayEvents = try await calendarService.fetchFamilyEventsForUser(
                userId,
                familyId: familyId,
                dateRange: todayRange
            )
            
            // Get calendar statistics
            let statsRange = DateInterval(
                start: Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now,
                end: Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
            )
            let stats = try await calendarService.getFamilyCalendarStats(
                familyId: familyId,
                dateRange: statsRange
            )
            
            return FamilyCalendarDashboardData(
                upcomingEvents: upcomingEvents,
                todayEvents: todayEvents,
                permissions: permissions,
                stats: stats,
                hasCalendarAccess: permissions.hasAccess
            )
            
        } catch {
            self.error = error
            print("❌ FamilyCalendarIntegrationService: Failed to get dashboard data: \(error)")
            throw error
        }
    }
    
    /// Gets calendar activity feed data for family dashboard
    func getFamilyCalendarActivityFeed(
        familyId: UUID,
        userId: UUID,
        limit: Int = 10
    ) async throws -> [FamilyCalendarActivity] {
        print("🔗 FamilyCalendarIntegrationService: Getting calendar activity feed for family: \(familyId)")
        
        // Get recent events (last 7 days to next 7 days)
        let now = Date()
        let pastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let dateRange = DateInterval(start: pastWeek, end: nextWeek)
        
        let events = try await calendarService.fetchFamilyEventsForUser(
            userId,
            familyId: familyId,
            dateRange: dateRange
        )
        
        // Convert events to activity feed items
        let activities = events.prefix(limit).map { event in
            FamilyCalendarActivity(
                id: event.id,
                type: event.isUpcoming ? .upcomingEvent : .pastEvent,
                title: event.title,
                description: event.dateRangeString,
                timestamp: event.startDate,
                createdBy: event.createdBy,
                eventId: event.id
            )
        }
        
        return Array(activities)
    }
    
    // MARK: - Family Member Profile Integration
    
    /// Gets calendar-related information for a family member profile
    func getCalendarInfoForMemberProfile(
        userId: UUID,
        familyId: UUID,
        viewingUserId: UUID
    ) async throws -> MemberCalendarInfo {
        print("🔗 FamilyCalendarIntegrationService: Getting calendar info for member profile: \(userId)")
        
        // Check if viewing user has permission to see this info
        let viewerPermissions = try await calendarService.getFamilyCalendarPermissions(
            userId: viewingUserId,
            familyId: familyId
        )
        
        guard viewerPermissions.hasAccess else {
            throw FamilyCalendarIntegrationError.noCalendarAccess
        }
        
        // Get member's calendar permissions
        let memberPermissions = try await calendarService.getFamilyCalendarPermissions(
            userId: userId,
            familyId: familyId
        )
        
        // Get member's recent events (if viewer has admin access or is viewing their own profile)
        var recentEvents: [CalendarEvent] = []
        if viewerPermissions.isAdmin || viewingUserId == userId {
            let now = Date()
            let pastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            let dateRange = DateInterval(start: pastMonth, end: now)
            
            let allEvents = try await calendarService.fetchFamilyEventsForUser(
                viewingUserId,
                familyId: familyId,
                dateRange: dateRange
            )
            
            recentEvents = allEvents.filter { $0.createdBy == userId }.prefix(5).map { $0 }
        }
        
        return MemberCalendarInfo(
            userId: userId,
            permissions: memberPermissions,
            recentEventsCount: recentEvents.count,
            recentEvents: recentEvents,
            canViewDetails: viewerPermissions.isAdmin || viewingUserId == userId
        )
    }
    
    // MARK: - Permission Management Integration
    
    /// Updates calendar permissions for a family member (admin only)
    func updateMemberCalendarPermissions(
        targetUserId: UUID,
        familyId: UUID,
        newPermissionLevel: CalendarPermissionLevel,
        adminUserId: UUID
    ) async throws {
        print("🔗 FamilyCalendarIntegrationService: Updating calendar permissions for user: \(targetUserId)")
        
        // Verify admin permissions
        let adminPermissions = try await calendarService.getFamilyCalendarPermissions(
            userId: adminUserId,
            familyId: familyId
        )
        
        guard adminPermissions.isAdmin else {
            throw FamilyCalendarIntegrationError.insufficientPermissions
        }
        
        // Get or create permission record
        var permission = try permissionManager.getCalendarPermission(
            userId: targetUserId,
            familyId: familyId
        )
        
        if permission == nil {
            // Create new permission
            permission = CalendarPermission(
                userId: targetUserId,
                familyId: familyId,
                permissionLevel: newPermissionLevel,
                grantedBy: adminUserId
            )
            modelContext.insert(permission!)
        } else {
            // Update existing permission
            permission!.updatePermissionLevel(newPermissionLevel, grantedBy: adminUserId)
        }
        
        try modelContext.save()
        print("✅ FamilyCalendarIntegrationService: Updated calendar permissions to: \(newPermissionLevel)")
    }
}

// MARK: - Supporting Data Structures

/// Data structure for family calendar dashboard display
struct FamilyCalendarDashboardData {
    let upcomingEvents: [CalendarEvent]
    let todayEvents: [CalendarEvent]
    let permissions: FamilyCalendarPermissions
    let stats: FamilyCalendarStats
    let hasCalendarAccess: Bool
    
    var hasUpcomingEvents: Bool {
        !upcomingEvents.isEmpty
    }
    
    var hasTodayEvents: Bool {
        !todayEvents.isEmpty
    }
    
    var nextEvent: CalendarEvent? {
        upcomingEvents.first
    }
}

/// Data structure for family calendar activity feed
struct FamilyCalendarActivity: Identifiable {
    let id: UUID
    let type: ActivityType
    let title: String
    let description: String
    let timestamp: Date
    let createdBy: UUID
    let eventId: UUID
    
    enum ActivityType {
        case upcomingEvent
        case pastEvent
        case eventCreated
        case eventModified
        case eventDeleted
        
        var icon: String {
            switch self {
            case .upcomingEvent:
                return "calendar.badge.clock"
            case .pastEvent:
                return "calendar.badge.checkmark"
            case .eventCreated:
                return "calendar.badge.plus"
            case .eventModified:
                return "calendar.badge.exclamationmark"
            case .eventDeleted:
                return "calendar.badge.minus"
            }
        }
        
        var color: String {
            switch self {
            case .upcomingEvent:
                return "blue"
            case .pastEvent:
                return "green"
            case .eventCreated:
                return "purple"
            case .eventModified:
                return "orange"
            case .eventDeleted:
                return "red"
            }
        }
    }
}

/// Data structure for member calendar information
struct MemberCalendarInfo {
    let userId: UUID
    let permissions: FamilyCalendarPermissions
    let recentEventsCount: Int
    let recentEvents: [CalendarEvent]
    let canViewDetails: Bool
    
    var hasCalendarAccess: Bool {
        permissions.hasAccess
    }
    
    var permissionSummary: String {
        permissions.description
    }
}

// MARK: - Error Types

enum FamilyCalendarIntegrationError: LocalizedError {
    case invalidMembership
    case noCalendarAccess
    case insufficientPermissions
    case memberNotFound
    case familyNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidMembership:
            return "Invalid family membership information"
        case .noCalendarAccess:
            return "No access to family calendar features"
        case .insufficientPermissions:
            return "Insufficient permissions to perform this action"
        case .memberNotFound:
            return "Family member not found"
        case .familyNotFound:
            return "Family not found"
        }
    }
}