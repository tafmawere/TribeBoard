import Foundation
import CloudKit

/// CloudKit record type constants
struct CKRecordType {
    static let family = "Family"
    static let membership = "Membership"
    static let userProfile = "UserProfile"
}

/// CloudKit field name constants
struct CKFieldName {
    // Family fields
    static let familyName = "name"
    static let familyCode = "code"
    static let familyCreatedByUserId = "createdByUserId"
    static let familyCreatedAt = "createdAt"
    
    // Membership fields
    static let membershipRole = "role"
    static let membershipJoinedAt = "joinedAt"
    static let membershipStatus = "status"
    static let membershipLastRoleChangeAt = "lastRoleChangeAt"
    static let membershipFamilyReference = "family"
    static let membershipUserReference = "user"
    
    // UserProfile fields
    static let userDisplayName = "displayName"
    static let userAppleUserIdHash = "appleUserIdHash"
    static let userAvatarUrl = "avatarUrl"
    static let userCreatedAt = "createdAt"
}

/// CloudKit zone constants
struct CKZone {
    static let customZoneName = "TribeBoardZone"
    static let customZoneID = CKRecordZone.ID(zoneName: customZoneName)
}