import XCTest
import CloudKit
@testable import TribeBoard

/// Tests for CloudKit record conversion and synchronization
@MainActor
final class CloudKitSyncTests: DatabaseTestBase {
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
    }
    
    // MARK: - Family CloudKit Conversion Tests
    
    func testFamilyToCKRecord_IncludesAllRequiredFields() throws {
        // Given
        let family = try createTestFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // When
        let ckRecord = try family.toCKRecord()
        
        // Then
        XCTAssertEqual(ckRecord.recordType, CKRecordType.family)
        XCTAssertEqual(ckRecord.recordID.recordName, family.id.uuidString)
        
        // Verify all required fields are present with correct types
        XCTAssertEqual(ckRecord[CKFieldName.familyName] as? String, "Test Family")
        XCTAssertEqual(ckRecord[CKFieldName.familyCode] as? String, "TEST123")
        XCTAssertEqual(ckRecord[CKFieldName.familyCreatedByUserId] as? String, family.createdByUserId.uuidString)
        XCTAssertEqual(ckRecord[CKFieldName.familyCreatedAt] as? Date, family.createdAt)
        
        print("✅ Family toCKRecord includes all required fields with correct types")
    }
    
    func testFamilyUpdateFromCKRecord_CorrectlyMapsAllFields() throws {
        // Given
        let originalFamily = try createTestFamily()
        let recordID = CKRecord.ID(recordName: originalFamily.id.uuidString)
        let ckRecord = CKRecord(recordType: CKRecordType.family, recordID: recordID)
        
        let newName = "Updated Family"
        let newCode = "UPD456"
        let newUserId = UUID()
        let newCreatedAt = Date().addingTimeInterval(-3600) // 1 hour ago
        
        ckRecord[CKFieldName.familyName] = newName
        ckRecord[CKFieldName.familyCode] = newCode
        ckRecord[CKFieldName.familyCreatedByUserId] = newUserId.uuidString
        ckRecord[CKFieldName.familyCreatedAt] = newCreatedAt
        
        // When
        try originalFamily.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertEqual(originalFamily.name, newName)
        XCTAssertEqual(originalFamily.code, newCode)
        XCTAssertEqual(originalFamily.createdByUserId, newUserId)
        XCTAssertEqual(originalFamily.createdAt, newCreatedAt)
        XCTAssertEqual(originalFamily.ckRecordID, recordID.recordName)
        XCTAssertNotNil(originalFamily.lastSyncDate)
        XCTAssertFalse(originalFamily.needsSync)
        
        print("✅ Family updateFromCKRecord correctly maps all CloudKit fields to model properties")
    }
    
    func testFamilyUpdateFromCKRecord_ThrowsErrorForInvalidRecord() throws {
        // Given
        let family = try createTestFamily()
        let recordID = CKRecord.ID(recordName: family.id.uuidString)
        let invalidRecord = CKRecord(recordType: CKRecordType.family, recordID: recordID)
        
        // Missing required fields
        invalidRecord[CKFieldName.familyName] = "Test Family"
        // Missing code, createdByUserId, and createdAt
        
        // When & Then
        XCTAssertThrowsError(try family.updateFromCKRecord(invalidRecord)) { error in
            XCTAssertTrue(error is CloudKitSyncError)
            if case CloudKitSyncError.invalidRecord = error {
                print("✅ Family updateFromCKRecord throws appropriate error for invalid record")
            } else {
                XCTFail("Expected CloudKitSyncError.invalidRecord, got \(error)")
            }
        }
    }
    
    // MARK: - UserProfile CloudKit Conversion Tests
    
    func testUserProfileToCKRecord_IncludesAllRequiredFields() throws {
        // Given
        let avatarURL = URL(string: "https://example.com/avatar.jpg")
        let user = try createTestUser(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123456789"
        )
        user.avatarUrl = avatarURL
        
        // When
        let ckRecord = try user.toCKRecord()
        
        // Then
        XCTAssertEqual(ckRecord.recordType, CKRecordType.userProfile)
        XCTAssertEqual(ckRecord.recordID.recordName, user.id.uuidString)
        
        // Verify all required fields are present with correct types
        XCTAssertEqual(ckRecord[CKFieldName.userDisplayName] as? String, "Test User")
        XCTAssertEqual(ckRecord[CKFieldName.userAppleUserIdHash] as? String, "test_hash_123456789")
        XCTAssertEqual(ckRecord[CKFieldName.userAvatarUrl] as? String, avatarURL?.absoluteString)
        XCTAssertEqual(ckRecord[CKFieldName.userCreatedAt] as? Date, user.createdAt)
        
        print("✅ UserProfile toCKRecord includes all required fields with correct types")
    }
    
    func testUserProfileUpdateFromCKRecord_CorrectlyMapsAllFields() throws {
        // Given
        let originalUser = try createTestUser()
        let recordID = CKRecord.ID(recordName: originalUser.id.uuidString)
        let ckRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: recordID)
        
        let newDisplayName = "Updated User"
        let newAppleUserIdHash = "updated_hash_987654321"
        let newAvatarUrl = "https://example.com/new-avatar.jpg"
        let newCreatedAt = Date().addingTimeInterval(-7200) // 2 hours ago
        
        ckRecord[CKFieldName.userDisplayName] = newDisplayName
        ckRecord[CKFieldName.userAppleUserIdHash] = newAppleUserIdHash
        ckRecord[CKFieldName.userAvatarUrl] = newAvatarUrl
        ckRecord[CKFieldName.userCreatedAt] = newCreatedAt
        
        // When
        try originalUser.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertEqual(originalUser.displayName, newDisplayName)
        XCTAssertEqual(originalUser.appleUserIdHash, newAppleUserIdHash)
        XCTAssertEqual(originalUser.avatarUrl?.absoluteString, newAvatarUrl)
        XCTAssertEqual(originalUser.createdAt, newCreatedAt)
        XCTAssertEqual(originalUser.ckRecordID, recordID.recordName)
        XCTAssertNotNil(originalUser.lastSyncDate)
        XCTAssertFalse(originalUser.needsSync)
        
        print("✅ UserProfile updateFromCKRecord correctly maps all CloudKit fields to model properties")
    }
    
    func testUserProfileUpdateFromCKRecord_HandlesOptionalFields() throws {
        // Given
        let user = try createTestUser()
        let recordID = CKRecord.ID(recordName: user.id.uuidString)
        let ckRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: recordID)
        
        // Set required fields only (no avatar URL)
        ckRecord[CKFieldName.userDisplayName] = "Test User"
        ckRecord[CKFieldName.userAppleUserIdHash] = "test_hash_123456789"
        ckRecord[CKFieldName.userCreatedAt] = Date()
        
        // When
        try user.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertNil(user.avatarUrl)
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.appleUserIdHash, "test_hash_123456789")
        
        print("✅ UserProfile updateFromCKRecord correctly handles optional fields")
    }
    
    func testUserProfileUpdateFromCKRecord_ThrowsErrorForInvalidRecord() throws {
        // Given
        let user = try createTestUser()
        let recordID = CKRecord.ID(recordName: user.id.uuidString)
        let invalidRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: recordID)
        
        // Missing required fields
        invalidRecord[CKFieldName.userDisplayName] = "Test User"
        // Missing appleUserIdHash and createdAt
        
        // When & Then
        XCTAssertThrowsError(try user.updateFromCKRecord(invalidRecord)) { error in
            XCTAssertTrue(error is CloudKitSyncError)
            if case CloudKitSyncError.invalidRecord = error {
                print("✅ UserProfile updateFromCKRecord throws appropriate error for invalid record")
            } else {
                XCTFail("Expected CloudKitSyncError.invalidRecord, got \(error)")
            }
        }
    }
    
    // MARK: - Membership CloudKit Conversion Tests
    
    func testMembershipToCKRecord_IncludesAllRequiredFields() throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let membership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        membership.lastRoleChangeAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        // When
        let ckRecord = try membership.toCKRecord()
        
        // Then
        XCTAssertEqual(ckRecord.recordType, CKRecordType.membership)
        XCTAssertEqual(ckRecord.recordID.recordName, membership.id.uuidString)
        
        // Verify all required fields are present with correct types
        XCTAssertEqual(ckRecord[CKFieldName.membershipRole] as? String, Role.parentAdmin.rawValue)
        XCTAssertEqual(ckRecord[CKFieldName.membershipStatus] as? String, MembershipStatus.active.rawValue)
        XCTAssertEqual(ckRecord[CKFieldName.membershipJoinedAt] as? Date, membership.joinedAt)
        XCTAssertEqual(ckRecord[CKFieldName.membershipLastRoleChangeAt] as? Date, membership.lastRoleChangeAt)
        
        // Verify relationships are properly referenced
        let familyReference = ckRecord[CKFieldName.membershipFamilyReference] as? CKRecord.Reference
        XCTAssertNotNil(familyReference)
        XCTAssertEqual(familyReference?.recordID.recordName, family.id.uuidString)
        XCTAssertEqual(familyReference?.action, .deleteSelf)
        
        let userReference = ckRecord[CKFieldName.membershipUserReference] as? CKRecord.Reference
        XCTAssertNotNil(userReference)
        XCTAssertEqual(userReference?.recordID.recordName, user.id.uuidString)
        XCTAssertEqual(userReference?.action, .deleteSelf)
        
        print("✅ Membership toCKRecord includes all required fields with correct types and relationships")
    }
    
    func testMembershipUpdateFromCKRecord_CorrectlyMapsAllFields() throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let originalMembership = try createTestMembership(family: family, user: user, role: .kid)
        
        let recordID = CKRecord.ID(recordName: originalMembership.id.uuidString)
        let ckRecord = CKRecord(recordType: CKRecordType.membership, recordID: recordID)
        
        let newRole = Role.teen
        let newStatus = MembershipStatus.removed
        let newJoinedAt = Date().addingTimeInterval(-86400) // 1 day ago
        let newLastRoleChangeAt = Date().addingTimeInterval(-3600) // 1 hour ago
        
        ckRecord[CKFieldName.membershipRole] = newRole.rawValue
        ckRecord[CKFieldName.membershipStatus] = newStatus.rawValue
        ckRecord[CKFieldName.membershipJoinedAt] = newJoinedAt
        ckRecord[CKFieldName.membershipLastRoleChangeAt] = newLastRoleChangeAt
        
        // When
        try originalMembership.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertEqual(originalMembership.role, newRole)
        XCTAssertEqual(originalMembership.status, newStatus)
        XCTAssertEqual(originalMembership.joinedAt, newJoinedAt)
        XCTAssertEqual(originalMembership.lastRoleChangeAt, newLastRoleChangeAt)
        XCTAssertEqual(originalMembership.ckRecordID, recordID.recordName)
        XCTAssertNotNil(originalMembership.lastSyncDate)
        XCTAssertFalse(originalMembership.needsSync)
        
        print("✅ Membership updateFromCKRecord correctly maps all CloudKit fields to model properties")
    }
    
    func testMembershipUpdateFromCKRecord_HandlesOptionalFields() throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let membership = try createTestMembership(family: family, user: user, role: .kid)
        
        let recordID = CKRecord.ID(recordName: membership.id.uuidString)
        let ckRecord = CKRecord(recordType: CKRecordType.membership, recordID: recordID)
        
        // Set required fields only (no lastRoleChangeAt)
        ckRecord[CKFieldName.membershipRole] = Role.teen.rawValue
        ckRecord[CKFieldName.membershipStatus] = MembershipStatus.active.rawValue
        ckRecord[CKFieldName.membershipJoinedAt] = Date()
        
        // When
        try membership.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertNil(membership.lastRoleChangeAt)
        XCTAssertEqual(membership.role, .teen)
        XCTAssertEqual(membership.status, .active)
        
        print("✅ Membership updateFromCKRecord correctly handles optional fields")
    }
    
    func testMembershipUpdateFromCKRecord_ThrowsErrorForInvalidRecord() throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let membership = try createTestMembership(family: family, user: user, role: .kid)
        
        let recordID = CKRecord.ID(recordName: membership.id.uuidString)
        let invalidRecord = CKRecord(recordType: CKRecordType.membership, recordID: recordID)
        
        // Missing required fields
        invalidRecord[CKFieldName.membershipRole] = Role.teen.rawValue
        // Missing status and joinedAt
        
        // When & Then
        XCTAssertThrowsError(try membership.updateFromCKRecord(invalidRecord)) { error in
            XCTAssertTrue(error is CloudKitSyncError)
            if case CloudKitSyncError.invalidRecord = error {
                print("✅ Membership updateFromCKRecord throws appropriate error for invalid record")
            } else {
                XCTFail("Expected CloudKitSyncError.invalidRecord, got \(error)")
            }
        }
    }
    
    // MARK: - Bidirectional Conversion Tests
    
    func testFamilyBidirectionalConversion_PreservesAllData() throws {
        // Given
        let originalFamily = try createTestFamily(
            name: "Original Family",
            code: "ORIG123",
            createdByUserId: UUID()
        )
        
        // When - Convert to CloudKit and back
        let ckRecord = try originalFamily.toCKRecord()
        let newFamily = Family(name: "", code: "", createdByUserId: UUID())
        try newFamily.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertEqual(newFamily.name, originalFamily.name)
        XCTAssertEqual(newFamily.code, originalFamily.code)
        XCTAssertEqual(newFamily.createdByUserId, originalFamily.createdByUserId)
        XCTAssertEqual(newFamily.createdAt, originalFamily.createdAt)
        
        print("✅ Family bidirectional conversion preserves all data")
    }
    
    func testUserProfileBidirectionalConversion_PreservesAllData() throws {
        // Given
        let avatarURL = URL(string: "https://example.com/avatar.jpg")
        let originalUser = try createTestUser(
            displayName: "Original User",
            appleUserIdHash: "original_hash_123456789"
        )
        originalUser.avatarUrl = avatarURL
        
        // When - Convert to CloudKit and back
        let ckRecord = try originalUser.toCKRecord()
        let newUser = UserProfile(displayName: "", appleUserIdHash: "")
        try newUser.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertEqual(newUser.displayName, originalUser.displayName)
        XCTAssertEqual(newUser.appleUserIdHash, originalUser.appleUserIdHash)
        XCTAssertEqual(newUser.avatarUrl?.absoluteString, originalUser.avatarUrl?.absoluteString)
        XCTAssertEqual(newUser.createdAt, originalUser.createdAt)
        
        print("✅ UserProfile bidirectional conversion preserves all data")
    }
    
    func testMembershipBidirectionalConversion_PreservesAllData() throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let originalMembership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        originalMembership.lastRoleChangeAt = Date().addingTimeInterval(-1800)
        
        // When - Convert to CloudKit and back
        let ckRecord = try originalMembership.toCKRecord()
        let newMembership = Membership(family: family, user: user, role: .kid)
        try newMembership.updateFromCKRecord(ckRecord)
        
        // Then
        XCTAssertEqual(newMembership.role, originalMembership.role)
        XCTAssertEqual(newMembership.status, originalMembership.status)
        XCTAssertEqual(newMembership.joinedAt, originalMembership.joinedAt)
        XCTAssertEqual(newMembership.lastRoleChangeAt, originalMembership.lastRoleChangeAt)
        
        print("✅ Membership bidirectional conversion preserves all data")
    }
    
    // MARK: - CloudKit Syncable Protocol Tests
    
    func testCloudKitSyncableProtocol_MarkForSync() throws {
        // Given
        var family = try createTestFamily()
        family.needsSync = false
        
        // When
        family.markForSync()
        
        // Then
        XCTAssertTrue(family.needsSync)
        
        print("✅ CloudKitSyncable markForSync sets needsSync flag")
    }
    
    func testCloudKitSyncableProtocol_MarkAsSynced() throws {
        // Given
        var family = try createTestFamily()
        family.needsSync = true
        family.ckRecordID = nil
        family.lastSyncDate = nil
        
        let recordID = "test-record-id"
        
        // When
        family.markAsSynced(recordID: recordID)
        
        // Then
        XCTAssertEqual(family.ckRecordID, recordID)
        XCTAssertNotNil(family.lastSyncDate)
        XCTAssertFalse(family.needsSync)
        
        print("✅ CloudKitSyncable markAsSynced updates sync properties correctly")
    }
    
    func testCloudKitSyncableProtocol_RequiresSync() throws {
        // Given
        var family = try createTestFamily()
        
        // Test case 1: needsSync is true
        family.needsSync = true
        family.ckRecordID = "some-id"
        XCTAssertTrue(family.requiresSync)
        
        // Test case 2: ckRecordID is nil
        family.needsSync = false
        family.ckRecordID = nil
        XCTAssertTrue(family.requiresSync)
        
        // Test case 3: Both conditions are false
        family.needsSync = false
        family.ckRecordID = "some-id"
        XCTAssertFalse(family.requiresSync)
        
        print("✅ CloudKitSyncable requiresSync correctly evaluates sync requirements")
    }
}