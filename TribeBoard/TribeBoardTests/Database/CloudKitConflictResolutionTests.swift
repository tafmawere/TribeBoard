import XCTest
import CloudKit
@testable import TribeBoard

/// Tests for CloudKit conflict resolution scenarios
@MainActor
final class CloudKitConflictResolutionTests: DatabaseTestBase {
    
    // MARK: - Properties
    
    private var mockCloudKitService: MockCloudKitService!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        mockCloudKitService = MockCloudKitService()
    }
    
    override func tearDown() async throws {
        mockCloudKitService = nil
        try await super.tearDown()
    }
    
    // MARK: - Family Conflict Resolution Tests
    
    func testFamilyConflictResolution_LocalRecordNewer() async throws {
        // Given
        let family = try createTestFamily(name: "Local Family", code: "LOCAL1")
        let localModificationDate = Date()
        family.lastSyncDate = localModificationDate
        
        // Create server record with older modification date
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Server Family"
        serverRecord[CKFieldName.familyCode] = "SERVER1"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        serverRecord.modificationDate = localModificationDate.addingTimeInterval(-3600) // 1 hour older
        
        // When
        let resolvedFamily = try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)
        
        // Then - Local record should win (newer)
        XCTAssertEqual(resolvedFamily.name, "Local Family")
        XCTAssertEqual(resolvedFamily.code, "LOCAL1")
        XCTAssertEqual(resolvedFamily.id, family.id)
        
        print("✅ Family conflict resolution: Local record wins when newer")
    }
    
    func testFamilyConflictResolution_ServerRecordNewer() async throws {
        // Given
        let family = try createTestFamily(name: "Local Family", code: "LOCAL1")
        let localModificationDate = Date().addingTimeInterval(-3600) // 1 hour ago
        family.lastSyncDate = localModificationDate
        
        // Create server record with newer modification date
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Server Family"
        serverRecord[CKFieldName.familyCode] = "SERVER1"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        serverRecord.modificationDate = Date() // Current time (newer)
        
        // When
        let resolvedFamily = try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)
        
        // Then - Server record should win (newer)
        XCTAssertEqual(resolvedFamily.name, "Server Family")
        XCTAssertEqual(resolvedFamily.code, "SERVER1")
        XCTAssertEqual(resolvedFamily.id, family.id)
        
        print("✅ Family conflict resolution: Server record wins when newer")
    }
    
    func testFamilyConflictResolution_SimultaneousUpdate() async throws {
        // Given
        let family = try createTestFamily(name: "Local Family", code: "LOCAL1")
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Server Family"
        serverRecord[CKFieldName.familyCode] = "SERVER1"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        
        // Configure mock to simulate simultaneous update conflict
        mockCloudKitService.simulateConflict(scenario: .simultaneousUpdate)
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)) { error in
            XCTAssertTrue(error is CloudKitError)
            if case CloudKitError.conflictResolution = error {
                print("✅ Family conflict resolution: Throws error for simultaneous updates")
            } else {
                XCTFail("Expected CloudKitError.conflictResolution, got \(error)")
            }
        }
    }
    
    // MARK: - UserProfile Conflict Resolution Tests
    
    func testUserProfileConflictResolution_LocalRecordNewer() async throws {
        // Given
        let user = try createTestUser(displayName: "Local User", appleUserIdHash: "local_hash_123")
        let localModificationDate = Date()
        user.lastSyncDate = localModificationDate
        user.avatarUrl = URL(string: "https://local.com/avatar.jpg")
        
        // Create server record with older modification date
        let serverRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: user.id.uuidString))
        serverRecord[CKFieldName.userDisplayName] = "Server User"
        serverRecord[CKFieldName.userAppleUserIdHash] = "server_hash_456"
        serverRecord[CKFieldName.userAvatarUrl] = "https://server.com/avatar.jpg"
        serverRecord[CKFieldName.userCreatedAt] = user.createdAt
        serverRecord.modificationDate = localModificationDate.addingTimeInterval(-1800) // 30 minutes older
        
        // When
        let resolvedUser = try await mockCloudKitService.resolveConflict(localRecord: user, serverRecord: serverRecord)
        
        // Then - Local record should win (newer)
        XCTAssertEqual(resolvedUser.displayName, "Local User")
        XCTAssertEqual(resolvedUser.appleUserIdHash, "local_hash_123")
        XCTAssertEqual(resolvedUser.avatarUrl?.absoluteString, "https://local.com/avatar.jpg")
        XCTAssertEqual(resolvedUser.id, user.id)
        
        print("✅ UserProfile conflict resolution: Local record wins when newer")
    }
    
    func testUserProfileConflictResolution_ServerRecordNewer() async throws {
        // Given
        let user = try createTestUser(displayName: "Local User", appleUserIdHash: "local_hash_123")
        let localModificationDate = Date().addingTimeInterval(-1800) // 30 minutes ago
        user.lastSyncDate = localModificationDate
        user.avatarUrl = URL(string: "https://local.com/avatar.jpg")
        
        // Create server record with newer modification date
        let serverRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: user.id.uuidString))
        serverRecord[CKFieldName.userDisplayName] = "Server User"
        serverRecord[CKFieldName.userAppleUserIdHash] = "server_hash_456"
        serverRecord[CKFieldName.userAvatarUrl] = "https://server.com/avatar.jpg"
        serverRecord[CKFieldName.userCreatedAt] = user.createdAt
        serverRecord.modificationDate = Date() // Current time (newer)
        
        // When
        let resolvedUser = try await mockCloudKitService.resolveConflict(localRecord: user, serverRecord: serverRecord)
        
        // Then - Server record should win (newer)
        XCTAssertEqual(resolvedUser.displayName, "Server User")
        XCTAssertEqual(resolvedUser.appleUserIdHash, "server_hash_456")
        XCTAssertEqual(resolvedUser.avatarUrl?.absoluteString, "https://server.com/avatar.jpg")
        XCTAssertEqual(resolvedUser.id, user.id)
        
        print("✅ UserProfile conflict resolution: Server record wins when newer")
    }
    
    // MARK: - Membership Conflict Resolution Tests
    
    func testMembershipConflictResolution_LocalRecordNewer() async throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let membership = try createTestMembership(family: family, user: user, role: .teen)
        let localModificationDate = Date()
        membership.lastSyncDate = localModificationDate
        membership.lastRoleChangeAt = Date().addingTimeInterval(-900) // 15 minutes ago
        
        // Create server record with older modification date
        let serverRecord = CKRecord(recordType: CKRecordType.membership, recordID: CKRecord.ID(recordName: membership.id.uuidString))
        serverRecord[CKFieldName.membershipRole] = Role.kid.rawValue
        serverRecord[CKFieldName.membershipStatus] = MembershipStatus.active.rawValue
        serverRecord[CKFieldName.membershipJoinedAt] = membership.joinedAt
        serverRecord[CKFieldName.membershipLastRoleChangeAt] = Date().addingTimeInterval(-1800) // 30 minutes ago
        serverRecord.modificationDate = localModificationDate.addingTimeInterval(-600) // 10 minutes older
        
        // When
        let resolvedMembership = try await mockCloudKitService.resolveConflict(localRecord: membership, serverRecord: serverRecord)
        
        // Then - Local record should win (newer)
        XCTAssertEqual(resolvedMembership.role, .teen)
        XCTAssertEqual(resolvedMembership.status, .active)
        XCTAssertEqual(resolvedMembership.id, membership.id)
        
        print("✅ Membership conflict resolution: Local record wins when newer")
    }
    
    func testMembershipConflictResolution_ServerRecordNewer() async throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let membership = try createTestMembership(family: family, user: user, role: .teen)
        let localModificationDate = Date().addingTimeInterval(-600) // 10 minutes ago
        membership.lastSyncDate = localModificationDate
        membership.lastRoleChangeAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        // Create server record with newer modification date
        let serverRecord = CKRecord(recordType: CKRecordType.membership, recordID: CKRecord.ID(recordName: membership.id.uuidString))
        serverRecord[CKFieldName.membershipRole] = Role.parentAdmin.rawValue
        serverRecord[CKFieldName.membershipStatus] = MembershipStatus.active.rawValue
        serverRecord[CKFieldName.membershipJoinedAt] = membership.joinedAt
        serverRecord[CKFieldName.membershipLastRoleChangeAt] = Date().addingTimeInterval(-300) // 5 minutes ago
        serverRecord.modificationDate = Date() // Current time (newer)
        
        // When
        let resolvedMembership = try await mockCloudKitService.resolveConflict(localRecord: membership, serverRecord: serverRecord)
        
        // Then - Server record should win (newer)
        XCTAssertEqual(resolvedMembership.role, .parentAdmin)
        XCTAssertEqual(resolvedMembership.status, .active)
        XCTAssertEqual(resolvedMembership.id, membership.id)
        
        print("✅ Membership conflict resolution: Server record wins when newer")
    }
    
    // MARK: - Data Integrity Tests
    
    func testConflictResolution_MaintainsDataIntegrity() async throws {
        // Given
        let family = try createTestFamily(name: "Original Family", code: "ORIG123")
        let originalId = family.id
        let originalCreatedAt = family.createdAt
        let originalCreatedByUserId = family.createdByUserId
        
        // Create server record with different data but same core identifiers
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Updated Family"
        serverRecord[CKFieldName.familyCode] = "UPD456"
        serverRecord[CKFieldName.familyCreatedByUserId] = originalCreatedByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = originalCreatedAt
        serverRecord.modificationDate = Date() // Newer than local
        
        // When
        let resolvedFamily = try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)
        
        // Then - Core integrity should be maintained
        XCTAssertEqual(resolvedFamily.id, originalId, "ID should remain unchanged")
        XCTAssertEqual(resolvedFamily.createdAt, originalCreatedAt, "Creation date should remain unchanged")
        XCTAssertEqual(resolvedFamily.createdByUserId, originalCreatedByUserId, "Creator ID should remain unchanged")
        
        // Updated fields should reflect server values
        XCTAssertEqual(resolvedFamily.name, "Updated Family")
        XCTAssertEqual(resolvedFamily.code, "UPD456")
        
        // Sync metadata should be updated
        XCTAssertNotNil(resolvedFamily.lastSyncDate)
        XCTAssertFalse(resolvedFamily.needsSync)
        
        print("✅ Conflict resolution maintains data integrity while updating changed fields")
    }
    
    func testConflictResolution_HandlesNilModificationDates() async throws {
        // Given
        let family = try createTestFamily(name: "Local Family", code: "LOCAL1")
        family.lastSyncDate = nil // No previous sync
        
        // Create server record with nil modification date
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Server Family"
        serverRecord[CKFieldName.familyCode] = "SERVER1"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        serverRecord.modificationDate = nil
        
        // When
        let resolvedFamily = try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)
        
        // Then - Should handle gracefully (local record should win when both dates are nil/distantPast)
        XCTAssertEqual(resolvedFamily.name, "Local Family")
        XCTAssertEqual(resolvedFamily.code, "LOCAL1")
        
        print("✅ Conflict resolution handles nil modification dates gracefully")
    }
    
    func testConflictResolution_PreservesRelationships() async throws {
        // Given
        let family = try createTestFamily()
        let user = try createTestUser()
        let membership = try createTestMembership(family: family, user: user, role: .teen)
        
        let originalFamily = membership.family
        let originalUser = membership.user
        
        // Create server record with role change but same relationships
        let serverRecord = CKRecord(recordType: CKRecordType.membership, recordID: CKRecord.ID(recordName: membership.id.uuidString))
        serverRecord[CKFieldName.membershipRole] = Role.parentAdmin.rawValue
        serverRecord[CKFieldName.membershipStatus] = MembershipStatus.active.rawValue
        serverRecord[CKFieldName.membershipJoinedAt] = membership.joinedAt
        serverRecord.modificationDate = Date() // Newer than local
        
        // When
        let resolvedMembership = try await mockCloudKitService.resolveConflict(localRecord: membership, serverRecord: serverRecord)
        
        // Then - Relationships should be preserved
        XCTAssertEqual(resolvedMembership.family?.id, originalFamily?.id)
        XCTAssertEqual(resolvedMembership.user?.id, originalUser?.id)
        XCTAssertEqual(resolvedMembership.role, .parentAdmin) // Updated field
        
        print("✅ Conflict resolution preserves relationships while updating other fields")
    }
    
    // MARK: - Edge Cases
    
    func testConflictResolution_IdenticalRecords() async throws {
        // Given
        let family = try createTestFamily(name: "Same Family", code: "SAME123")
        let modificationDate = Date()
        family.lastSyncDate = modificationDate
        
        // Create identical server record
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Same Family"
        serverRecord[CKFieldName.familyCode] = "SAME123"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        serverRecord.modificationDate = modificationDate
        
        // When
        let resolvedFamily = try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)
        
        // Then - Should return local record unchanged
        XCTAssertEqual(resolvedFamily.name, family.name)
        XCTAssertEqual(resolvedFamily.code, family.code)
        XCTAssertEqual(resolvedFamily.id, family.id)
        
        print("✅ Conflict resolution handles identical records correctly")
    }
    
    func testConflictResolution_InvalidServerRecord() async throws {
        // Given
        let family = try createTestFamily(name: "Local Family", code: "LOCAL1")
        
        // Create invalid server record (missing required fields)
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Server Family"
        // Missing code, createdByUserId, and createdAt
        serverRecord.modificationDate = Date()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)) { error in
            XCTAssertTrue(error is CloudKitSyncError)
            print("✅ Conflict resolution throws error for invalid server record")
        }
    }
    
    // MARK: - Performance Tests
    
    func testConflictResolution_Performance() async throws {
        // Given
        let family = try createTestFamily()
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Server Family"
        serverRecord[CKFieldName.familyCode] = "SERVER1"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        serverRecord.modificationDate = Date()
        
        // When & Then
        let startTime = Date()
        _ = try await mockCloudKitService.resolveConflict(localRecord: family, serverRecord: serverRecord)
        let duration = Date().timeIntervalSince(startTime)
        
        // Should complete quickly (under 100ms for simple conflict resolution)
        XCTAssertLessThan(duration, 0.1, "Conflict resolution should complete within 100ms")
        
        print("✅ Conflict resolution completes within performance threshold (\(String(format: "%.3f", duration))s)")
    }
}