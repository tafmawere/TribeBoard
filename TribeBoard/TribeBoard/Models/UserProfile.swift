import Foundation
import SwiftData
import CloudKit

/// SwiftData model for UserProfile with CloudKit sync capabilities
@Model
final class UserProfile {
    // Primary identifier - no unique constraint for CloudKit compatibility
    var id: UUID = UUID()
    
    // Core properties - with default values for CloudKit compatibility
    var displayName: String = ""
    var appleUserIdHash: String = ""
    var avatarUrl: URL?
    var createdAt: Date = Date()
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    var needsSync: Bool = true
    
    // Relationships - optional for CloudKit compatibility
    @Relationship(deleteRule: .cascade, inverse: \Membership.user)
    var memberships: [Membership]?
    
    init(displayName: String, appleUserIdHash: String, avatarUrl: URL? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.appleUserIdHash = appleUserIdHash
        self.avatarUrl = avatarUrl
        self.createdAt = Date()
        self.needsSync = true
        self.memberships = []
    }
    
    // MARK: - Validation
    
    /// Validates the display name
    var isDisplayNameValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        displayName.count >= 1 &&
        displayName.count <= 50
    }
    
    /// Validates the Apple user ID hash format
    var isAppleUserIdHashValid: Bool {
        !appleUserIdHash.isEmpty &&
        appleUserIdHash.count >= 10 // Minimum expected hash length
    }
    
    /// Validates all user profile properties
    var isFullyValid: Bool {
        isDisplayNameValid && isAppleUserIdHashValid
    }
    
    /// Returns active memberships only
    var activeMemberships: [Membership] {
        memberships?.filter { $0.status == .active } ?? []
    }
    
    /// Returns the current family membership if exists
    var currentFamilyMembership: Membership? {
        activeMemberships.first
    }
}

// MARK: - CloudKit Synchronization
extension UserProfile: CloudKitSyncable {
    static var recordType: String { CKRecordType.userProfile }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record[CKFieldName.userDisplayName] = displayName
        record[CKFieldName.userAppleUserIdHash] = appleUserIdHash
        record[CKFieldName.userAvatarUrl] = avatarUrl?.absoluteString
        record[CKFieldName.userCreatedAt] = createdAt
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let displayName = record[CKFieldName.userDisplayName] as? String,
              let appleUserIdHash = record[CKFieldName.userAppleUserIdHash] as? String,
              let createdAt = record[CKFieldName.userCreatedAt] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.displayName = displayName
        self.appleUserIdHash = appleUserIdHash
        self.createdAt = createdAt
        
        if let avatarUrlString = record[CKFieldName.userAvatarUrl] as? String {
            self.avatarUrl = URL(string: avatarUrlString)
        }
        
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}