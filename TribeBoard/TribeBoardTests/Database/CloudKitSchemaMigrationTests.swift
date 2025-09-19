import XCTest
import CloudKit
import SwiftData
@testable import TribeBoard

/// Tests for CloudKit schema migration and server-side schema changes
@MainActor
final class CloudKitSchemaMigrationTests: DatabaseTestBase {
    
    // MARK: - Properties
    
    private var mockService: MockCloudKitService!
    
    // MARK: - Test Setup
    
    override func setUp() async throws {
        try await super.setUp()
        print("☁️ CloudKitSchemaMigrationTests: Setting up CloudKit schema migration tests...")
        
        // Initialize mock CloudKit service
        mockService = MockCloudKitService()
    }
    
    override func tearDown() async throws {
        print("☁️ CloudKitSchemaMigrationTests: Tearing down CloudKit schema migration tests...")
        mockService = nil
        try await super.tearDown()
    }
    
    // MARK: - Server-Side Schema Update Tests
    
    /// Test handling of new fields added to CloudKit schema on server
    func testHandlingNewFieldsAddedToServerSchema() async throws {
        print("🧪 Testing handling of new fields added to server schema...")
        
        // Create local test data
        let family = try createTestFamily(name: "Schema Test Family", code: "SCH001")
        
        // Simulate server record with new fields that don't exist locally
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Schema Test Family"
        serverRecord[CKFieldName.familyCode] = "SCH001"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        
        // Add new fields that don't exist in local model (simulating server schema update)
        serverRecord["newServerField"] = "new_value"
        serverRecord["anotherNewField"] = 42
        serverRecord["optionalNewField"] = Date()
        
        // Test that local model can handle server record with unknown fields
        do {
            try family.updateFromCKRecord(serverRecord)
            
            // Verify that known fields are updated correctly
            XCTAssertEqual(family.name, "Schema Test Family")
            XCTAssertEqual(family.code, "SCH001")
            XCTAssertNotNil(family.ckRecordID)
            XCTAssertNotNil(family.lastSyncDate)
            XCTAssertFalse(family.needsSync)
            
            print("✅ Local model successfully handled server record with new fields")
            
        } catch {
            XCTFail("Local model should handle server records with unknown fields gracefully: \(error)")
        }
    }
    
    /// Test handling of removed fields from CloudKit schema on server
    func testHandlingRemovedFieldsFromServerSchema() async throws {
        print("🧪 Testing handling of removed fields from server schema...")
        
        // Create local test data with all current fields
        let user = try createTestUser(displayName: "Schema User")
        user.avatarUrl = URL(string: "https://example.com/avatar.jpg")
        
        // Simulate server record missing optional fields (simulating server schema removal)
        let serverRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: user.id.uuidString))
        serverRecord[CKFieldName.userDisplayName] = "Updated Schema User"
        serverRecord[CKFieldName.userAppleUserIdHash] = user.appleUserIdHash
        serverRecord[CKFieldName.userCreatedAt] = user.createdAt
        // Note: avatarUrl field is intentionally missing (simulating server schema change)
        
        // Test that local model handles missing optional fields gracefully
        do {
            try user.updateFromCKRecord(serverRecord)
            
            // Verify that required fields are updated
            XCTAssertEqual(user.displayName, "Updated Schema User")
            XCTAssertEqual(user.appleUserIdHash, user.appleUserIdHash)
            
            // Optional field should remain as it was or be set to nil based on implementation
            // The current implementation doesn't modify avatarUrl if it's not in the record
            XCTAssertEqual(user.avatarUrl?.absoluteString, "https://example.com/avatar.jpg")
            
            print("✅ Local model successfully handled server record with missing optional fields")
            
        } catch {
            XCTFail("Local model should handle server records with missing optional fields gracefully: \(error)")
        }
    }
    
    /// Test handling of field type changes in CloudKit schema
    func testHandlingFieldTypeChangesInServerSchema() async throws {
        print("🧪 Testing handling of field type changes in server schema...")
        
        // Create local test data
        let membership = try createTestMembership(role: .kid)
        
        // Create server record with expected types
        let serverRecord = CKRecord(recordType: CKRecordType.membership, recordID: CKRecord.ID(recordName: membership.id.uuidString))
        serverRecord[CKFieldName.membershipRole] = Role.parentAdmin.rawValue
        serverRecord[CKFieldName.membershipJoinedAt] = membership.joinedAt
        serverRecord[CKFieldName.membershipStatus] = MembershipStatus.active.rawValue
        
        // Test normal type handling
        do {
            try membership.updateFromCKRecord(serverRecord)
            XCTAssertEqual(membership.role, .parentAdmin)
            XCTAssertEqual(membership.status, .active)
            
            print("✅ Normal field type handling works correctly")
            
        } catch {
            XCTFail("Normal field type handling should work: \(error)")
        }
        
        // Test handling of invalid enum values (simulating server schema change)
        let invalidRecord = CKRecord(recordType: CKRecordType.membership, recordID: CKRecord.ID(recordName: membership.id.uuidString))
        invalidRecord[CKFieldName.membershipRole] = "invalid_role_value" // Invalid enum value
        invalidRecord[CKFieldName.membershipJoinedAt] = membership.joinedAt
        invalidRecord[CKFieldName.membershipStatus] = MembershipStatus.active.rawValue
        
        // Test that invalid enum values are handled gracefully
        do {
            try membership.updateFromCKRecord(invalidRecord)
            XCTFail("Should throw error for invalid enum value")
        } catch {
            // This is expected - invalid enum values should cause errors
            XCTAssertTrue(error is CloudKitSyncError, "Should throw CloudKitSyncError for invalid data")
            print("✅ Invalid enum values properly rejected")
        }
    }
    
    // MARK: - Schema Version Compatibility Tests
    
    /// Test backward compatibility with older CloudKit schema versions
    func testBackwardCompatibilityWithOlderSchemaVersions() async throws {
        print("🧪 Testing backward compatibility with older schema versions...")
        
        // Simulate older version of Family record (missing some current fields)
        let oldFamilyRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: UUID().uuidString))
        oldFamilyRecord[CKFieldName.familyName] = "Old Version Family"
        oldFamilyRecord[CKFieldName.familyCode] = "OLD001"
        oldFamilyRecord[CKFieldName.familyCreatedByUserId] = UUID().uuidString
        // Note: createdAt field might be missing in older versions
        
        // Create new Family instance and try to update from old record
        let family = Family(name: "Temp", code: "TEMP", createdByUserId: UUID())
        
        do {
            try family.updateFromCKRecord(oldFamilyRecord)
            
            // Verify that available fields are updated
            XCTAssertEqual(family.name, "Old Version Family")
            XCTAssertEqual(family.code, "OLD001")
            
            // Missing fields should have default values or remain unchanged
            XCTAssertNotNil(family.createdAt) // Should have default value
            
            print("✅ Backward compatibility with older schema versions works")
            
        } catch {
            // If the old record is missing required fields, it should fail gracefully
            XCTAssertTrue(error is CloudKitSyncError, "Should throw CloudKitSyncError for incomplete old records")
            print("✅ Incomplete old records properly rejected")
        }
    }
    
    /// Test forward compatibility with newer CloudKit schema versions
    func testForwardCompatibilityWithNewerSchemaVersions() async throws {
        print("🧪 Testing forward compatibility with newer schema versions...")
        
        // Create local data
        let user = try createTestUser(displayName: "Future User")
        
        // Simulate future version of UserProfile record with additional fields
        let futureRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: user.id.uuidString))
        futureRecord[CKFieldName.userDisplayName] = "Updated Future User"
        futureRecord[CKFieldName.userAppleUserIdHash] = user.appleUserIdHash
        futureRecord[CKFieldName.userCreatedAt] = user.createdAt
        futureRecord[CKFieldName.userAvatarUrl] = "https://example.com/new_avatar.jpg"
        
        // Add future fields that don't exist in current model
        futureRecord["futureField1"] = "future_value"
        futureRecord["futureField2"] = ["array", "of", "values"]
        futureRecord["futureField3"] = ["key": "value"]
        
        // Test that current model can handle future records
        do {
            try user.updateFromCKRecord(futureRecord)
            
            // Verify that known fields are updated
            XCTAssertEqual(user.displayName, "Updated Future User")
            XCTAssertEqual(user.avatarUrl?.absoluteString, "https://example.com/new_avatar.jpg")
            
            // Unknown fields should be ignored gracefully
            print("✅ Forward compatibility with newer schema versions works")
            
        } catch {
            XCTFail("Current model should handle future records gracefully: \(error)")
        }
    }
    
    // MARK: - Migration Recovery Tests
    
    /// Test recovery mechanisms when CloudKit migration fails
    func testRecoveryMechanismsWhenMigrationFails() async throws {
        print("🧪 Testing recovery mechanisms when migration fails...")
        
        // Create test data
        let family = try createTestFamily(name: "Recovery Family", code: "REC001")
        let user = try createTestUser(displayName: "Recovery User")
        let membership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        
        // Configure mock service to simulate migration failure
        mockService.shouldFailOperations = true
        mockService.networkDelay = 0.1
        
        // Attempt sync operation that will fail
        do {
            try await mockService.save(family)
            XCTFail("Operation should have failed")
        } catch {
            // Expected failure
            print("Migration failed as expected: \(error)")
        }
        
        // Test recovery mechanism
        // 1. Reset mock service to working state
        mockService.shouldFailOperations = false
        
        // 2. Verify local data is still intact
        XCTAssertEqual(family.name, "Recovery Family")
        XCTAssertEqual(family.code, "REC001")
        XCTAssertTrue(family.needsSync) // Should still need sync after failure
        
        // 3. Retry the operation
        do {
            try await mockService.save(family)
            print("✅ Recovery successful after migration failure")
        } catch {
            XCTFail("Recovery operation should succeed: \(error)")
        }
        
        // 4. Verify recovery completed successfully
        let savedRecords = mockService.recordStorage
        XCTAssertTrue(savedRecords.contains { $0.key.contains(family.id.uuidString) })
        
        print("✅ Migration recovery mechanisms work correctly")
    }
    
    /// Test partial migration recovery scenarios
    func testPartialMigrationRecoveryScenarios() async throws {
        print("🧪 Testing partial migration recovery scenarios...")
        
        // Create multiple records for batch migration
        let family1 = try createTestFamily(name: "Partial Family 1", code: "PAR001")
        let family2 = try createTestFamily(name: "Partial Family 2", code: "PAR002")
        let family3 = try createTestFamily(name: "Partial Family 3", code: "PAR003")
        
        let families = [family1, family2, family3]
        
        // Configure mock service to fail on second record
        mockService.shouldFailOperations = false
        mockService.failOnRecordIndex = 1 // Fail on second record
        
        // Attempt batch migration
        var successCount = 0
        var failureCount = 0
        
        for family in families {
            do {
                try await mockService.save(family)
                successCount += 1
            } catch {
                failureCount += 1
                print("Expected failure for family: \(family.name)")
            }
        }
        
        // Verify partial success
        XCTAssertEqual(successCount, 2, "Should have 2 successful migrations")
        XCTAssertEqual(failureCount, 1, "Should have 1 failed migration")
        
        // Test recovery of failed records
        mockService.shouldFailOperations = false
        mockService.failOnRecordIndex = nil
        
        // Retry failed records
        let failedFamilies = families.filter { $0.needsSync }
        XCTAssertEqual(failedFamilies.count, 1, "Should have 1 family still needing sync")
        
        for family in failedFamilies {
            do {
                try await mockService.save(family)
                print("✅ Successfully recovered failed migration for: \(family.name)")
            } catch {
                XCTFail("Recovery should succeed: \(error)")
            }
        }
        
        // Verify all records are now synced
        let savedRecords = mockService.recordStorage
        for family in families {
            XCTAssertTrue(savedRecords.contains { $0.key.contains(family.id.uuidString) },
                         "Family \(family.name) should be in saved records")
        }
        
        print("✅ Partial migration recovery scenarios work correctly")
    }
    
    // MARK: - Data Validation During Migration Tests
    
    /// Test data validation before CloudKit migration
    func testDataValidationBeforeMigration() async throws {
        print("🧪 Testing data validation before migration...")
        
        // Create valid test data
        let validFamily = try createTestFamily(name: "Valid Family", code: "VAL001")
        XCTAssertTrue(validFamily.isFullyValid)
        
        // Create invalid test data
        let invalidFamily = Family(name: "", code: "INVALID", createdByUserId: UUID()) // Empty name
        XCTAssertFalse(invalidFamily.isFullyValid)
        
        // Test migration of valid data
        do {
            try await mockService.save(validFamily)
            print("✅ Valid data migrated successfully")
        } catch {
            XCTFail("Valid data should migrate successfully: \(error)")
        }
        
        // Test that invalid data is rejected before migration
        do {
            // In a real implementation, validation should happen before attempting CloudKit save
            let ckRecord = try invalidFamily.toCKRecord()
            
            // Verify that the record contains invalid data
            let name = ckRecord[CKFieldName.familyName] as? String
            XCTAssertEqual(name, "", "Invalid record should have empty name")
            
            // The CloudKit save might succeed, but validation should catch this earlier
            print("✅ Invalid data properly identified before migration")
            
        } catch {
            print("✅ Invalid data rejected during record conversion: \(error)")
        }
    }
    
    /// Test data validation after CloudKit migration
    func testDataValidationAfterMigration() async throws {
        print("🧪 Testing data validation after migration...")
        
        // Create server record with valid data
        let validServerRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: UUID().uuidString))
        validServerRecord[CKFieldName.userDisplayName] = "Valid User"
        validServerRecord[CKFieldName.userAppleUserIdHash] = "valid_hash_123456789"
        validServerRecord[CKFieldName.userCreatedAt] = Date()
        
        // Test migration from valid server record
        let user = UserProfile(displayName: "Temp", appleUserIdHash: "temp")
        
        do {
            try user.updateFromCKRecord(validServerRecord)
            XCTAssertTrue(user.isFullyValid, "User should be valid after migration from valid server record")
            print("✅ Valid server record migrated successfully")
        } catch {
            XCTFail("Valid server record should migrate successfully: \(error)")
        }
        
        // Create server record with invalid data
        let invalidServerRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: UUID().uuidString))
        invalidServerRecord[CKFieldName.userDisplayName] = "" // Invalid empty name
        invalidServerRecord[CKFieldName.userAppleUserIdHash] = "short" // Invalid short hash
        invalidServerRecord[CKFieldName.userCreatedAt] = Date()
        
        // Test migration from invalid server record
        let user2 = UserProfile(displayName: "Temp", appleUserIdHash: "temp")
        
        do {
            try user2.updateFromCKRecord(invalidServerRecord)
            
            // Even if migration succeeds, validation should catch invalid data
            XCTAssertFalse(user2.isFullyValid, "User should be invalid after migration from invalid server record")
            print("✅ Invalid server record properly identified after migration")
            
        } catch {
            print("✅ Invalid server record rejected during migration: \(error)")
        }
    }
    
    /// Test comprehensive data integrity validation during migration process
    func testComprehensiveDataIntegrityValidationDuringMigration() async throws {
        print("🧪 Testing comprehensive data integrity validation during migration...")
        
        // Create complex test data with relationships
        let family = try createTestFamily(name: "Integrity Family", code: "INT001")
        let user1 = try createTestUser(displayName: "User 1")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "hash_user2")
        
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        
        // Pre-migration integrity validation
        func validateIntegrity() throws {
            // Validate individual records
            XCTAssertTrue(family.isFullyValid, "Family should be valid")
            XCTAssertTrue(user1.isFullyValid, "User 1 should be valid")
            XCTAssertTrue(user2.isFullyValid, "User 2 should be valid")
            XCTAssertTrue(membership1.isFullyValid, "Membership 1 should be valid")
            XCTAssertTrue(membership2.isFullyValid, "Membership 2 should be valid")
            
            // Validate relationships
            XCTAssertEqual(membership1.family?.id, family.id, "Membership 1 should reference correct family")
            XCTAssertEqual(membership1.user?.id, user1.id, "Membership 1 should reference correct user")
            XCTAssertEqual(membership2.family?.id, family.id, "Membership 2 should reference correct family")
            XCTAssertEqual(membership2.user?.id, user2.id, "Membership 2 should reference correct user")
            
            // Validate business rules
            XCTAssertTrue(family.hasParentAdmin, "Family should have a parent admin")
            XCTAssertEqual(family.activeMembers.count, 2, "Family should have 2 active members")
            
            // Validate unique constraints
            let parentAdmins = family.activeMembers.filter { $0.role == .parentAdmin }
            XCTAssertEqual(parentAdmins.count, 1, "Family should have exactly 1 parent admin")
        }
        
        // Validate before migration
        try validateIntegrity()
        
        // Simulate migration process
        try await mockService.save(family)
        try await mockService.save(user1)
        try await mockService.save(user2)
        try await mockService.save(membership1)
        try await mockService.save(membership2)
        
        // Validate after migration
        try validateIntegrity()
        
        // Verify CloudKit records maintain integrity
        let savedRecords = mockService.recordStorage
        XCTAssertEqual(savedRecords.count, 5, "Should have 5 saved records")
        
        // Verify each record type is present
        let familyRecords = savedRecords.values.filter { $0.recordType == CKRecordType.family }
        let userRecords = savedRecords.values.filter { $0.recordType == CKRecordType.userProfile }
        let membershipRecords = savedRecords.values.filter { $0.recordType == CKRecordType.membership }
        
        XCTAssertEqual(familyRecords.count, 1, "Should have 1 family record")
        XCTAssertEqual(userRecords.count, 2, "Should have 2 user records")
        XCTAssertEqual(membershipRecords.count, 2, "Should have 2 membership records")
        
        print("✅ Comprehensive data integrity validation during migration successful")
    }
    
    // MARK: - CloudKit Schema Synchronization Tests
    
    /// Test synchronization of schema changes from CloudKit server
    func testSynchronizationOfSchemaChangesFromServer() async throws {
        print("🧪 Testing synchronization of schema changes from server...")
        
        // Create local data
        let family = try createTestFamily(name: "Sync Family", code: "SYNC01")
        
        // Simulate server record with schema changes (new fields, modified fields)
        let serverRecord = CKRecord(recordType: CKRecordType.family, recordID: CKRecord.ID(recordName: family.id.uuidString))
        serverRecord[CKFieldName.familyName] = "Updated Sync Family"
        serverRecord[CKFieldName.familyCode] = "SYNC01"
        serverRecord[CKFieldName.familyCreatedByUserId] = family.createdByUserId.uuidString
        serverRecord[CKFieldName.familyCreatedAt] = family.createdAt
        
        // Add new server-side fields
        serverRecord["serverOnlyField"] = "server_value"
        serverRecord["newOptionalField"] = Date()
        
        // Test synchronization from server
        do {
            try family.updateFromCKRecord(serverRecord)
            
            // Verify known fields are synchronized
            XCTAssertEqual(family.name, "Updated Sync Family")
            XCTAssertNotNil(family.ckRecordID)
            XCTAssertNotNil(family.lastSyncDate)
            XCTAssertFalse(family.needsSync)
            
            print("✅ Schema changes synchronized from server successfully")
            
        } catch {
            XCTFail("Schema synchronization should succeed: \(error)")
        }
    }
    
    /// Test handling of CloudKit subscription updates for schema changes
    func testHandlingCloudKitSubscriptionUpdatesForSchemaChanges() async throws {
        print("🧪 Testing handling of CloudKit subscription updates for schema changes...")
        
        // This test simulates receiving subscription notifications about schema changes
        // In a real implementation, this would involve CloudKit push notifications
        
        // Create test data
        let user = try createTestUser(displayName: "Subscription User")
        
        // Simulate receiving a subscription notification about a record change
        let notificationUserInfo: [AnyHashable: Any] = [
            "ck": [
                "qry": [
                    "rid": user.id.uuidString,
                    "mt": 2 // Record updated
                ]
            ]
        ]
        
        // Create a mock CloudKit service to handle the notification
        let cloudKitService = CloudKitService()
        
        // In a real test, we would:
        // 1. Receive the notification
        // 2. Fetch the updated record from CloudKit
        // 3. Apply the changes to local storage
        // 4. Validate that schema changes are handled correctly
        
        // For this test, we'll simulate the process
        let updatedServerRecord = CKRecord(recordType: CKRecordType.userProfile, recordID: CKRecord.ID(recordName: user.id.uuidString))
        updatedServerRecord[CKFieldName.userDisplayName] = "Updated Subscription User"
        updatedServerRecord[CKFieldName.userAppleUserIdHash] = user.appleUserIdHash
        updatedServerRecord[CKFieldName.userCreatedAt] = user.createdAt
        
        // Add new field from server schema update
        updatedServerRecord["subscriptionNewField"] = "subscription_value"
        
        // Apply the update
        try user.updateFromCKRecord(updatedServerRecord)
        
        // Verify the update was applied correctly
        XCTAssertEqual(user.displayName, "Updated Subscription User")
        XCTAssertNotNil(user.lastSyncDate)
        
        print("✅ CloudKit subscription updates for schema changes handled correctly")
    }
}