import Foundation
import SwiftData
import CloudKit

/// SwiftData model for Membership with CloudKit sync capabilities
@Model
class Membership {
    @Attribute(.unique) var id: UUID
    var role: Role
    var joinedAt: Date
    var status: MembershipStatus
    var lastRoleChangeAt: Date?
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    var needsSync: Bool = false
    
    // Relationships
    @Relationship var family: Family?
    @Relationship var user: UserProfile?
    
    init(family: Family, user: UserProfile, role: Role) {
        self.id = UUID()
        self.role = role
        self.joinedAt = Date()
        self.status = .active
        self.needsSync = true
        
        // Set relationships
        self.family = family
        self.user = user
    }
    
    // MARK: - Computed Properties
    
    /// Returns the family ID for convenience
    var familyId: UUID? {
        family?.id
    }
    
    /// Returns the user ID for convenience
    var userId: UUID? {
        user?.id
    }
    
    /// Returns the user's display name
    var userDisplayName: String {
        user?.displayName ?? "Unknown User"
    }
    
    /// Returns the family name
    var familyName: String {
        family?.name ?? "Unknown Family"
    }
    
    // MARK: - Validation
    
    /// Validates the membership state
    var isValid: Bool {
        family != nil && user != nil
    }
    
    /// Checks if this is an active membership
    var isActive: Bool {
        status == .active
    }
    
    /// Checks if this is a parent admin role
    var isParentAdmin: Bool {
        role == .parentAdmin
    }
    
    /// Validates that the membership meets all constraints
    var isFullyValid: Bool {
        isValid && family != nil && user != nil
    }
    
    /// Checks if this membership can be changed to a specific role
    func canChangeRole(to newRole: Role, in family: Family) -> Bool {
        // Can't change to the same role
        guard role != newRole else { return false }
        
        // If trying to become parent admin, check if one already exists
        if newRole == .parentAdmin {
            return !family.hasParentAdmin
        }
        
        // Other role changes are allowed
        return true
    }
    
    // MARK: - Role Management
    
    /// Updates the role and tracks the change date
    func updateRole(to newRole: Role) {
        guard role != newRole else { return }
        
        role = newRole
        lastRoleChangeAt = Date()
        needsSync = true
    }
    
    /// Removes the member (soft delete)
    func remove() {
        status = .removed
        needsSync = true
    }
    
    /// Activates the membership
    func activate() {
        status = .active
        needsSync = true
    }
}

// MARK: - CloudKit Synchronization
extension Membership: CloudKitSyncable {
    static var recordType: String { CKRecordType.membership }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record[CKFieldName.membershipRole] = role.rawValue
        record[CKFieldName.membershipJoinedAt] = joinedAt
        record[CKFieldName.membershipStatus] = status.rawValue
        record[CKFieldName.membershipLastRoleChangeAt] = lastRoleChangeAt
        
        // Add references to family and user
        if let family = family {
            let familyRecordID = CKRecord.ID(recordName: family.id.uuidString)
            record[CKFieldName.membershipFamilyReference] = CKRecord.Reference(recordID: familyRecordID, action: .deleteSelf)
        }
        
        if let user = user {
            let userRecordID = CKRecord.ID(recordName: user.id.uuidString)
            record[CKFieldName.membershipUserReference] = CKRecord.Reference(recordID: userRecordID, action: .deleteSelf)
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let roleString = record[CKFieldName.membershipRole] as? String,
              let role = Role(rawValue: roleString),
              let statusString = record[CKFieldName.membershipStatus] as? String,
              let status = MembershipStatus(rawValue: statusString),
              let joinedAt = record[CKFieldName.membershipJoinedAt] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.role = role
        self.status = status
        self.joinedAt = joinedAt
        
        if let lastRoleChangeAt = record[CKFieldName.membershipLastRoleChangeAt] as? Date {
            self.lastRoleChangeAt = lastRoleChangeAt
        }
        
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}