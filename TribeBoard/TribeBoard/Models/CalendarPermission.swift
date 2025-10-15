import Foundation
import SwiftData
import CloudKit

/// Represents calendar-specific permissions for family members
enum CalendarPermissionLevel: String, CaseIterable, Codable, Sendable {
    case admin = "admin"
    case editor = "editor"
    case viewer = "viewer"
    case none = "none"
    
    /// Human-readable display name for the permission level
    var displayName: String {
        switch self {
        case .admin:
            return "Calendar Admin"
        case .editor:
            return "Can Edit Events"
        case .viewer:
            return "View Only"
        case .none:
            return "No Access"
        }
    }
    
    /// Description of the permission level's capabilities
    var description: String {
        switch self {
        case .admin:
            return "Full calendar management including permissions and bulk operations"
        case .editor:
            return "Can create, edit, and delete family events"
        case .viewer:
            return "Can view family events but cannot modify them"
        case .none:
            return "Cannot access family calendar features"
        }
    }
    
    /// Icon representing the permission level
    var icon: String {
        switch self {
        case .admin:
            return "crown.fill"
        case .editor:
            return "pencil.circle.fill"
        case .viewer:
            return "eye.fill"
        case .none:
            return "eye.slash.fill"
        }
    }
    
    /// Color associated with the permission level
    var color: String {
        switch self {
        case .admin:
            return "purple"
        case .editor:
            return "blue"
        case .viewer:
            return "green"
        case .none:
            return "gray"
        }
    }
}

/**
 * CalendarPermissionType - Specific calendar permissions that can be granted
 * 
 * ENUM CASE FIXES DOCUMENTATION:
 * During compilation error fixes, incorrect enum case references were corrected:
 * 
 * Fixed References:
 * - .deleteEvents → .deleteFamilyEvents (for family-wide delete permissions)
 * - .deleteEvents → .deleteOwnEvents (for personal delete permissions)
 * 
 * All enum cases are now properly defined and consistently referenced throughout the codebase.
 * Use .deleteFamilyEvents for admin-level delete permissions and .deleteOwnEvents for 
 * user-level delete permissions.
 */
enum CalendarPermissionType: String, CaseIterable, Codable, Sendable {
    case createEvents = "create_events"
    case editOwnEvents = "edit_own_events"
    case editFamilyEvents = "edit_family_events"
    case deleteOwnEvents = "delete_own_events"
    case deleteFamilyEvents = "delete_family_events"
    case managePermissions = "manage_permissions"
    case bulkOperations = "bulk_operations"
    case viewFamilyEvents = "view_family_events"
    
    var displayName: String {
        switch self {
        case .createEvents:
            return "Create Events"
        case .editOwnEvents:
            return "Edit Own Events"
        case .editFamilyEvents:
            return "Edit Family Events"
        case .deleteOwnEvents:
            return "Delete Own Events"
        case .deleteFamilyEvents:
            return "Delete Family Events"
        case .managePermissions:
            return "Manage Permissions"
        case .bulkOperations:
            return "Bulk Operations"
        case .viewFamilyEvents:
            return "View Family Events"
        }
    }
    
    var description: String {
        switch self {
        case .createEvents:
            return "Create new family events"
        case .editOwnEvents:
            return "Edit events they created"
        case .editFamilyEvents:
            return "Edit any family event"
        case .deleteOwnEvents:
            return "Delete events they created"
        case .deleteFamilyEvents:
            return "Delete any family event"
        case .managePermissions:
            return "Grant and revoke calendar permissions"
        case .bulkOperations:
            return "Perform bulk event operations"
        case .viewFamilyEvents:
            return "View family shared events"
        }
    }
}

/// SwiftData model for calendar permissions with CloudKit sync
@Model
final class CalendarPermission {
    // Primary identifier
    var id: UUID = UUID()
    
    // Core properties
    var userId: UUID = UUID()
    var familyId: UUID = UUID()
    var permissionLevel: CalendarPermissionLevel = CalendarPermissionLevel.none
    var grantedBy: UUID = UUID()
    var grantedAt: Date = Date()
    var lastModified: Date = Date()
    var isActive: Bool = true
    
    // Specific permissions (stored as comma-separated string for CloudKit compatibility)
    var specificPermissions: String = ""
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    var needsSync: Bool = true
    
    // Relationships
    @Relationship var membership: Membership?
    
    init(
        userId: UUID,
        familyId: UUID,
        permissionLevel: CalendarPermissionLevel,
        grantedBy: UUID,
        specificPermissions: [CalendarPermissionType] = []
    ) {
        self.id = UUID()
        self.userId = userId
        self.familyId = familyId
        self.permissionLevel = permissionLevel
        self.grantedBy = grantedBy
        self.grantedAt = Date()
        self.lastModified = Date()
        self.isActive = true
        self.needsSync = true
        self.specificPermissions = specificPermissions.map { $0.rawValue }.joined(separator: ",")
    }
    
    // MARK: - Permission Management
    
    /// Gets the specific permissions as an array
    var specificPermissionsArray: [CalendarPermissionType] {
        guard !specificPermissions.isEmpty else { return [] }
        return specificPermissions.components(separatedBy: ",").compactMap { CalendarPermissionType(rawValue: $0) }
    }
    
    /// Sets specific permissions from an array
    func setSpecificPermissions(_ permissions: [CalendarPermissionType]) {
        specificPermissions = permissions.map { $0.rawValue }.joined(separator: ",")
        lastModified = Date()
        needsSync = true
    }
    
    /// Gets all effective permissions based on permission level and specific permissions
    var effectivePermissions: [CalendarPermissionType] {
        var permissions: [CalendarPermissionType] = []
        
        // Add permissions based on level
        switch permissionLevel {
        case .admin:
            permissions = CalendarPermissionType.allCases
        case .editor:
            permissions = [
                .createEvents,
                .editOwnEvents,
                .editFamilyEvents,
                .deleteOwnEvents,
                .viewFamilyEvents
            ]
        case .viewer:
            permissions = [.viewFamilyEvents]
        case .none:
            permissions = []
        }
        
        // Add any additional specific permissions
        let specificPerms = specificPermissionsArray
        for perm in specificPerms {
            if !permissions.contains(perm) {
                permissions.append(perm)
            }
        }
        
        return permissions
    }
    
    /// Checks if the user has a specific permission
    func hasPermission(_ permission: CalendarPermissionType) -> Bool {
        guard isActive else { return false }
        return effectivePermissions.contains(permission)
    }
    
    /// Updates the permission level
    func updatePermissionLevel(_ newLevel: CalendarPermissionLevel, grantedBy: UUID) {
        self.permissionLevel = newLevel
        self.grantedBy = grantedBy
        self.lastModified = Date()
        self.needsSync = true
    }
    
    /// Grants a specific permission
    func grantPermission(_ permission: CalendarPermissionType) {
        var current = specificPermissionsArray
        if !current.contains(permission) {
            current.append(permission)
            setSpecificPermissions(current)
        }
    }
    
    /// Revokes a specific permission
    func revokePermission(_ permission: CalendarPermissionType) {
        var current = specificPermissionsArray
        current.removeAll { $0 == permission }
        setSpecificPermissions(current)
    }
    
    /// Deactivates the permission
    func deactivate() {
        isActive = false
        lastModified = Date()
        needsSync = true
    }
    
    /// Activates the permission
    func activate() {
        isActive = true
        lastModified = Date()
        needsSync = true
    }
    
    // MARK: - Validation
    
    /// Validates the permission state
    var isValid: Bool {
        !userId.uuidString.isEmpty && !familyId.uuidString.isEmpty && !grantedBy.uuidString.isEmpty
    }
    
    /// Marks the record as synced
    func markAsSynced(recordID: String) {
        ckRecordID = recordID
        lastSyncDate = Date()
        needsSync = false
    }
}

// MARK: - CloudKit Synchronization
extension CalendarPermission: CloudKitSyncable {
    static var recordType: String { "CalendarPermission" }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record["userId"] = userId.uuidString
        record["familyId"] = familyId.uuidString
        record["permissionLevel"] = permissionLevel.rawValue
        record["grantedBy"] = grantedBy.uuidString
        record["grantedAt"] = grantedAt
        record["lastModified"] = lastModified
        record["isActive"] = isActive ? 1 : 0
        record["specificPermissions"] = specificPermissions
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let userIdString = record["userId"] as? String,
              let userId = UUID(uuidString: userIdString),
              let familyIdString = record["familyId"] as? String,
              let familyId = UUID(uuidString: familyIdString),
              let permissionLevelString = record["permissionLevel"] as? String,
              let permissionLevel = CalendarPermissionLevel(rawValue: permissionLevelString),
              let grantedByString = record["grantedBy"] as? String,
              let grantedBy = UUID(uuidString: grantedByString),
              let grantedAt = record["grantedAt"] as? Date,
              let lastModified = record["lastModified"] as? Date,
              let isActiveInt = record["isActive"] as? Int else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.userId = userId
        self.familyId = familyId
        self.permissionLevel = permissionLevel
        self.grantedBy = grantedBy
        self.grantedAt = grantedAt
        self.lastModified = lastModified
        self.isActive = isActiveInt == 1
        self.specificPermissions = record["specificPermissions"] as? String ?? ""
        
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}

// MARK: - Default Permission Configurations
extension CalendarPermissionLevel {
    
    /// Gets default permissions for a family role
    static func defaultForRole(_ role: Role) -> CalendarPermissionLevel {
        switch role {
        case .parentAdmin:
            return .admin
        case .adult:
            return .editor
        case .kid:
            return .viewer
        case .visitor:
            return .viewer
        }
    }
    
    /// Gets the minimum role required for this permission level
    var minimumRole: Role {
        switch self {
        case .admin:
            return .parentAdmin
        case .editor:
            return .adult
        case .viewer:
            return .kid
        case .none:
            return .visitor
        }
    }
}