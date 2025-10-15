import Foundation
import SwiftData

/// Service for managing calendar permissions within families
@MainActor
class CalendarPermissionManager: ObservableObject {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Permission Queries
    
    /// Gets calendar permission for a user in a family
    func getPermission(for userId: UUID, in familyId: UUID) throws -> CalendarPermission? {
        let descriptor = FetchDescriptor<CalendarPermission>(
            predicate: #Predicate<CalendarPermission> { permission in
                permission.userId == userId && 
                permission.familyId == familyId && 
                permission.isActive
            }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Gets all active permissions for a family
    func getPermissions(for familyId: UUID) throws -> [CalendarPermission] {
        let descriptor = FetchDescriptor<CalendarPermission>(
            predicate: #Predicate<CalendarPermission> { permission in
                permission.familyId == familyId && permission.isActive
            },
            sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Gets all users with admin permissions in a family
    func getAdmins(for familyId: UUID) throws -> [CalendarPermission] {
        let descriptor = FetchDescriptor<CalendarPermission>(
            predicate: #Predicate<CalendarPermission> { permission in
                permission.familyId == familyId && 
                permission.isActive && 
                permission.permissionLevel == CalendarPermissionLevel.admin
            }
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Permission Checking
    
    /// Checks if a user has a specific calendar permission
    func hasPermission(
        userId: UUID,
        familyId: UUID,
        permission: CalendarPermissionType
    ) throws -> Bool {
        guard let calendarPermission = try getPermission(for: userId, in: familyId) else {
            return false
        }
        
        return calendarPermission.hasPermission(permission)
    }
    
    /// Checks if a user can perform an action on a calendar event
    func canPerformAction(
        userId: UUID,
        on event: CalendarEvent,
        action: CalendarEventAction
    ) throws -> Bool {
        // Personal events - user can always manage their own
        if event.privacyLevel == .personal && event.createdBy == userId {
            return true
        }
        
        // Family events - check permissions
        guard event.privacyLevel == .familyShared,
              let familyId = event.familyId else {
            return false
        }
        
        guard let permission = try getPermission(for: userId, in: familyId) else {
            return false
        }
        
        switch action {
        case .view:
            return permission.hasPermission(.viewFamilyEvents)
        case .create:
            return permission.hasPermission(.createEvents)
        case .edit:
            if event.createdBy == userId {
                return permission.hasPermission(.editOwnEvents)
            } else {
                return permission.hasPermission(.editFamilyEvents)
            }
        case .delete:
            if event.createdBy == userId {
                return permission.hasPermission(.deleteOwnEvents)
            } else {
                return permission.hasPermission(.deleteFamilyEvents)
            }
        }
    }
    
    /// Checks if a user can manage permissions for a family
    func canManagePermissions(userId: UUID, familyId: UUID) throws -> Bool {
        return try hasPermission(userId: userId, familyId: familyId, permission: .managePermissions)
    }
    
    // MARK: - Permission Management
    
    /// Grants or updates calendar permission for a user
    func grantPermission(
        to userId: UUID,
        in familyId: UUID,
        level: CalendarPermissionLevel,
        grantedBy: UUID,
        specificPermissions: [CalendarPermissionType] = []
    ) throws {
        // Verify the granter has permission to manage permissions
        guard try canManagePermissions(userId: grantedBy, familyId: familyId) else {
            throw CalendarPermissionError.insufficientPermissions
        }
        
        // Check if permission already exists
        if let existingPermission = try getPermission(for: userId, in: familyId) {
            // Update existing permission
            existingPermission.updatePermissionLevel(level, grantedBy: grantedBy)
            existingPermission.setSpecificPermissions(specificPermissions)
        } else {
            // Create new permission
            let newPermission = CalendarPermission(
                userId: userId,
                familyId: familyId,
                permissionLevel: level,
                grantedBy: grantedBy,
                specificPermissions: specificPermissions
            )
            modelContext.insert(newPermission)
        }
        
        try modelContext.save()
    }
    
    /// Revokes calendar permission for a user
    func revokePermission(
        from userId: UUID,
        in familyId: UUID,
        revokedBy: UUID
    ) throws {
        // Verify the revoker has permission to manage permissions
        guard try canManagePermissions(userId: revokedBy, familyId: familyId) else {
            throw CalendarPermissionError.insufficientPermissions
        }
        
        // Don't allow revoking admin permission from the last admin
        let admins = try getAdmins(for: familyId)
        if admins.count == 1 && admins.first?.userId == userId {
            throw CalendarPermissionError.cannotRevokeLastAdmin
        }
        
        guard let permission = try getPermission(for: userId, in: familyId) else {
            throw CalendarPermissionError.permissionNotFound
        }
        
        permission.deactivate()
        try modelContext.save()
    }
    
    /// Updates specific permissions for a user
    func updateSpecificPermissions(
        for userId: UUID,
        in familyId: UUID,
        permissions: [CalendarPermissionType],
        updatedBy: UUID
    ) throws {
        // Verify the updater has permission to manage permissions
        guard try canManagePermissions(userId: updatedBy, familyId: familyId) else {
            throw CalendarPermissionError.insufficientPermissions
        }
        
        guard let permission = try getPermission(for: userId, in: familyId) else {
            throw CalendarPermissionError.permissionNotFound
        }
        
        permission.setSpecificPermissions(permissions)
        try modelContext.save()
    }
    
    // MARK: - Family Setup
    
    /// Sets up default calendar permissions for a new family
    func setupDefaultPermissions(for family: Family) throws {
        // Grant admin permission to family creator
        let adminPermission = CalendarPermission(
            userId: family.createdByUserId,
            familyId: family.id,
            permissionLevel: .admin,
            grantedBy: family.createdByUserId
        )
        
        modelContext.insert(adminPermission)
        try modelContext.save()
    }
    
    /// Sets up calendar permissions when a new member joins a family
    func setupMemberPermissions(for membership: Membership) throws {
        guard let family = membership.family,
              let user = membership.user else {
            throw CalendarPermissionError.invalidMembership
        }
        
        // Get default permission level for the role
        let defaultLevel = CalendarPermissionLevel.defaultForRole(membership.role)
        
        // Create permission with family creator as granter
        let permission = CalendarPermission(
            userId: user.id,
            familyId: family.id,
            permissionLevel: defaultLevel,
            grantedBy: family.createdByUserId
        )
        
        modelContext.insert(permission)
        try modelContext.save()
    }
    
    /// Updates calendar permissions when a member's role changes
    func updatePermissionsForRoleChange(membership: Membership) throws {
        guard let family = membership.family,
              let user = membership.user else {
            throw CalendarPermissionError.invalidMembership
        }
        
        guard let permission = try getPermission(for: user.id, in: family.id) else {
            // If no permission exists, create one
            try setupMemberPermissions(for: membership)
            return
        }
        
        // Update to default permission level for new role
        let newLevel = CalendarPermissionLevel.defaultForRole(membership.role)
        permission.updatePermissionLevel(newLevel, grantedBy: family.createdByUserId)
        
        try modelContext.save()
    }
    
    // MARK: - Bulk Operations
    
    /// Performs bulk permission updates (admin only)
    func bulkUpdatePermissions(
        updates: [BulkPermissionUpdate],
        familyId: UUID,
        updatedBy: UUID
    ) throws {
        // Verify the updater has bulk operation permissions
        guard try hasPermission(userId: updatedBy, familyId: familyId, permission: .bulkOperations) else {
            throw CalendarPermissionError.insufficientPermissions
        }
        
        for update in updates {
            switch update.action {
            case .grant:
                try grantPermission(
                    to: update.userId,
                    in: familyId,
                    level: update.permissionLevel,
                    grantedBy: updatedBy,
                    specificPermissions: update.specificPermissions
                )
            case .revoke:
                try revokePermission(from: update.userId, in: familyId, revokedBy: updatedBy)
            case .update:
                try updateSpecificPermissions(
                    for: update.userId,
                    in: familyId,
                    permissions: update.specificPermissions,
                    updatedBy: updatedBy
                )
            }
        }
    }
    
    // MARK: - Permission Status
    
    /// Gets permission status summary for a family
    func getPermissionStatus(for familyId: UUID) throws -> FamilyPermissionStatus {
        let permissions = try getPermissions(for: familyId)
        let admins = permissions.filter { $0.permissionLevel == .admin }
        let editors = permissions.filter { $0.permissionLevel == .editor }
        let viewers = permissions.filter { $0.permissionLevel == .viewer }
        let noAccess = permissions.filter { $0.permissionLevel == .none }
        
        return FamilyPermissionStatus(
            totalMembers: permissions.count,
            adminCount: admins.count,
            editorCount: editors.count,
            viewerCount: viewers.count,
            noAccessCount: noAccess.count,
            permissions: permissions
        )
    }
}

// MARK: - Supporting Types

/// Actions that can be performed on calendar events
enum CalendarEventAction {
    case view
    case create
    case edit
    case delete
}

/// Bulk permission update operation
struct BulkPermissionUpdate {
    let userId: UUID
    let action: BulkPermissionAction
    let permissionLevel: CalendarPermissionLevel
    let specificPermissions: [CalendarPermissionType]
    
    enum BulkPermissionAction {
        case grant
        case revoke
        case update
    }
}

/// Family permission status summary
struct FamilyPermissionStatus {
    let totalMembers: Int
    let adminCount: Int
    let editorCount: Int
    let viewerCount: Int
    let noAccessCount: Int
    let permissions: [CalendarPermission]
    
    var hasAdmins: Bool { adminCount > 0 }
    var hasMultipleAdmins: Bool { adminCount > 1 }
}

/// Calendar permission related errors
enum CalendarPermissionError: LocalizedError {
    case insufficientPermissions
    case permissionNotFound
    case cannotRevokeLastAdmin
    case invalidMembership
    case userNotInFamily
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .permissionNotFound:
            return "Calendar permission not found for this user"
        case .cannotRevokeLastAdmin:
            return "Cannot revoke admin permission from the last admin"
        case .invalidMembership:
            return "Invalid family membership"
        case .userNotInFamily:
            return "User is not a member of this family"
        }
    }
}