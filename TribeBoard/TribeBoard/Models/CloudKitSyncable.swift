import Foundation
import CloudKit

/// Protocol for models that can be synchronized with CloudKit
protocol CloudKitSyncable {
    /// The CloudKit record ID
    var ckRecordID: String? { get set }
    
    /// The last sync date with CloudKit
    var lastSyncDate: Date? { get set }
    
    /// Flag indicating if the record needs to be synced
    var needsSync: Bool { get set }
    
    /// The unique identifier for the record
    var id: UUID { get }
    
    /// Converts the model to a CloudKit record
    func toCKRecord() throws -> CKRecord
    
    /// Updates the model from a CloudKit record
    func updateFromCKRecord(_ record: CKRecord) throws
    
    /// The CloudKit record type name
    static var recordType: String { get }
}

/// Default implementations for CloudKit synchronization
extension CloudKitSyncable {
    
    /// Marks the record as needing sync
    mutating func markForSync() {
        needsSync = true
    }
    
    /// Marks the record as synced
    mutating func markAsSynced(recordID: String) {
        ckRecordID = recordID
        lastSyncDate = Date()
        needsSync = false
    }
    
    /// Checks if the record needs to be synced
    var requiresSync: Bool {
        needsSync || ckRecordID == nil
    }
}

/// CloudKit record type names
enum CKRecordType {
    static let family = "CKFamily"
    static let userProfile = "CKUserProfile"
    static let membership = "CKMembership"
}

/// CloudKit field names for consistency
enum CKFieldName {
    // Family fields
    static let familyName = "name"
    static let familyCode = "code"
    static let familyCreatedByUserId = "createdByUserId"
    static let familyCreatedAt = "createdAt"
    
    // UserProfile fields
    static let userDisplayName = "displayName"
    static let userAppleUserIdHash = "appleUserIdHash"
    static let userAvatarUrl = "avatarUrl"
    static let userCreatedAt = "createdAt"
    
    // Membership fields
    static let membershipRole = "role"
    static let membershipJoinedAt = "joinedAt"
    static let membershipStatus = "status"
    static let membershipLastRoleChangeAt = "lastRoleChangeAt"
    static let membershipFamilyReference = "family"
    static let membershipUserReference = "user"
}