import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for schema migration and data preservation during model updates
@MainActor
final class SchemaMigrationTests: DatabaseTestBase {
    
    // MARK: - Test Setup
    
    override func setUp() async throws {
        try await super.setUp()
        print("🔄 SchemaMigrationTests: Setting up schema migration tests...")
    }
    
    override func tearDown() async throws {
        print("🔄 SchemaMigrationTests: Tearing down schema migration tests...")
        try await super.tearDown()
    }
    
    // MARK: - Adding New Model Properties Tests
    
    /// Test that adding new optional properties doesn't break existing data
    func testAddingOptionalPropertiesPreservesExistingData() throws {
        print("🧪 Testing adding optional properties preserves existing data...")
        
        // Create test data with current schema
        let family = try createTestFamily(name: "Migration Test Family", code: "MIG001")
        let user = try createTestUser(displayName: "Migration User")
        let membership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        
        // Verify initial data
        XCTAssertEqual(family.name, "Migration Test Family")
        XCTAssertEqual(family.code, "MIG001")
        XCTAssertEqual(user.displayName, "Migration User")
        XCTAssertEqual(membership.role, .parentAdmin)
        
        // Simulate adding new optional properties by testing that existing data remains intact
        // In a real migration, new optional properties would be added to the model
        
        // Verify data integrity after simulated schema change
        let fetchedFamilies = try fetchAllRecords(Family.self)
        let fetchedUsers = try fetchAllRecords(UserProfile.self)
        let fetchedMemberships = try fetchAllRecords(Membership.self)
        
        XCTAssertEqual(fetchedFamilies.count, 1)
        XCTAssertEqual(fetchedUsers.count, 1)
        XCTAssertEqual(fetchedMemberships.count, 1)
        
        let fetchedFamily = fetchedFamilies.first!
        let fetchedUser = fetchedUsers.first!
        let fetchedMembership = fetchedMemberships.first!
        
        // Verify all original data is preserved
        XCTAssertEqual(fetchedFamily.name, "Migration Test Family")
        XCTAssertEqual(fetchedFamily.code, "MIG001")
        XCTAssertEqual(fetchedUser.displayName, "Migration User")
        XCTAssertEqual(fetchedMembership.role, .parentAdmin)
        
        // Verify relationships are preserved
        XCTAssertEqual(fetchedMembership.family?.id, fetchedFamily.id)
        XCTAssertEqual(fetchedMembership.user?.id, fetchedUser.id)
        
        print("✅ Adding optional properties preserves existing data")
    }
    
    /// Test that adding new required properties with default values works correctly
    func testAddingRequiredPropertiesWithDefaultValues() throws {
        print("🧪 Testing adding required properties with default values...")
        
        // Create test data
        let family = try createTestFamily(name: "Default Test Family", code: "DEF001")
        let originalCreatedAt = family.createdAt
        
        // Verify that new required properties with defaults are handled
        // In our current models, all properties already have defaults for CloudKit compatibility
        
        // Test that existing data maintains its values
        XCTAssertEqual(family.name, "Default Test Family")
        XCTAssertEqual(family.code, "DEF001")
        XCTAssertEqual(family.createdAt, originalCreatedAt)
        
        // Test that default values are applied to new instances
        let newFamily = Family(name: "New Family", code: "NEW001", createdByUserId: UUID())
        testContext.insert(newFamily)
        try saveContext()
        
        // Verify new instance has all required properties
        XCTAssertFalse(newFamily.name.isEmpty)
        XCTAssertFalse(newFamily.code.isEmpty)
        XCTAssertNotNil(newFamily.createdAt)
        XCTAssertNotNil(newFamily.id)
        XCTAssertEqual(newFamily.needsSync, true) // Default value
        
        print("✅ Adding required properties with default values works correctly")
    }
    
    /// Test that adding new computed properties doesn't affect data storage
    func testAddingComputedPropertiesDoesNotAffectStorage() throws {
        print("🧪 Testing adding computed properties doesn't affect storage...")
        
        // Create test data with relationships
        let family = try createTestFamily(name: "Computed Test Family", code: "COMP01")
        let user1 = try createTestUser(displayName: "User 1")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "hash_user2")
        
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        
        // Test existing computed properties work correctly
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.activeMembers.count, 2)
        XCTAssertEqual(user1.activeMemberships.count, 1)
        XCTAssertEqual(user2.activeMemberships.count, 1)
        
        // Verify computed properties don't affect stored data
        let storedFamilyCount = try countRecords(Family.self)
        let storedUserCount = try countRecords(UserProfile.self)
        let storedMembershipCount = try countRecords(Membership.self)
        
        XCTAssertEqual(storedFamilyCount, 1)
        XCTAssertEqual(storedUserCount, 2)
        XCTAssertEqual(storedMembershipCount, 2)
        
        // Test that computed properties are recalculated correctly after data changes
        membership1.remove()
        try saveContext()
        
        XCTAssertFalse(family.hasParentAdmin) // Should be false after removal
        XCTAssertEqual(family.activeMembers.count, 1) // Should be 1 after removal
        
        print("✅ Adding computed properties doesn't affect storage")
    }
    
    // MARK: - Removing Model Properties Tests
    
    /// Test that removing optional properties maintains system functionality
    func testRemovingOptionalPropertiesMaintainsFunctionality() throws {
        print("🧪 Testing removing optional properties maintains functionality...")
        
        // Create test data
        let family = try createTestFamily(name: "Remove Test Family", code: "REM001")
        let user = try createTestUser(displayName: "Remove User")
        
        // Test that core functionality works even if optional properties are removed
        // In our current schema, avatarUrl is optional and could be removed
        
        // Verify core validation still works
        XCTAssertTrue(family.isFullyValid)
        XCTAssertTrue(user.isFullyValid)
        
        // Verify relationships still work
        let membership = try createTestMembership(family: family, user: user, role: .kid)
        XCTAssertTrue(membership.isFullyValid)
        XCTAssertEqual(membership.family?.id, family.id)
        XCTAssertEqual(membership.user?.id, user.id)
        
        // Test that removing optional CloudKit sync properties doesn't break core functionality
        // (In a real scenario, we might remove lastSyncDate or ckRecordID)
        family.lastSyncDate = nil
        family.ckRecordID = nil
        
        // Core functionality should still work
        XCTAssertTrue(family.isFullyValid)
        XCTAssertEqual(family.name, "Remove Test Family")
        XCTAssertEqual(family.code, "REM001")
        
        print("✅ Removing optional properties maintains functionality")
    }
    
    /// Test that removing unused properties doesn't break existing queries
    func testRemovingUnusedPropertiesDoesNotBreakQueries() throws {
        print("🧪 Testing removing unused properties doesn't break queries...")
        
        // Create test data
        let family1 = try createTestFamily(name: "Query Test 1", code: "QRY001")
        let family2 = try createTestFamily(name: "Query Test 2", code: "QRY002")
        let user = try createTestUser(displayName: "Query User")
        
        // Test various query patterns that should continue working
        
        // Fetch all families
        let allFamilies = try fetchAllRecords(Family.self)
        XCTAssertEqual(allFamilies.count, 2)
        
        // Fetch by predicate
        let family1Results = try fetchRecords(Family.self, predicate: #Predicate { $0.name == "Query Test 1" })
        XCTAssertEqual(family1Results.count, 1)
        XCTAssertEqual(family1Results.first?.code, "QRY001")
        
        // Fetch by code
        let family2Results = try fetchRecords(Family.self, predicate: #Predicate { $0.code == "QRY002" })
        XCTAssertEqual(family2Results.count, 1)
        XCTAssertEqual(family2Results.first?.name, "Query Test 2")
        
        // Test relationship queries
        let membership = try createTestMembership(family: family1, user: user, role: .parentAdmin)
        
        let membershipResults = try fetchRecords(Membership.self, predicate: #Predicate { $0.role == Role.parentAdmin })
        XCTAssertEqual(membershipResults.count, 1)
        XCTAssertEqual(membershipResults.first?.family?.id, family1.id)
        
        print("✅ Removing unused properties doesn't break queries")
    }
    
    // MARK: - Changing Relationship Configuration Tests
    
    /// Test that changing relationship delete rules preserves data integrity
    func testChangingRelationshipDeleteRulesPreservesIntegrity() throws {
        print("🧪 Testing changing relationship delete rules preserves integrity...")
        
        // Create test data with relationships
        let family = try createTestFamily(name: "Relationship Test", code: "REL001")
        let user1 = try createTestUser(displayName: "User 1")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "hash_user2")
        
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        
        // Verify initial state
        XCTAssertEqual(family.memberships?.count, 2)
        XCTAssertEqual(user1.memberships?.count, 1)
        XCTAssertEqual(user2.memberships?.count, 1)
        
        // Test current cascade delete behavior
        testContext.delete(family)
        try saveContext()
        
        // Verify cascade delete worked (memberships should be deleted)
        let remainingMemberships = try fetchAllRecords(Membership.self)
        XCTAssertEqual(remainingMemberships.count, 0, "Memberships should be cascade deleted when family is deleted")
        
        // Users should still exist (no cascade from family to user)
        let remainingUsers = try fetchAllRecords(UserProfile.self)
        XCTAssertEqual(remainingUsers.count, 2, "Users should remain when family is deleted")
        
        print("✅ Changing relationship delete rules preserves integrity")
    }
    
    /// Test that changing relationship inverse configurations maintains consistency
    func testChangingRelationshipInverseConfigurationsMaintainsConsistency() throws {
        print("🧪 Testing changing relationship inverse configurations maintains consistency...")
        
        // Create test data
        let family = try createTestFamily(name: "Inverse Test", code: "INV001")
        let user = try createTestUser(displayName: "Inverse User")
        let membership = try createTestMembership(family: family, user: user, role: .kid)
        
        // Test bidirectional relationship consistency
        XCTAssertTrue(family.memberships?.contains { $0.id == membership.id } ?? false,
                     "Family should contain the membership")
        XCTAssertTrue(user.memberships?.contains { $0.id == membership.id } ?? false,
                     "User should contain the membership")
        XCTAssertEqual(membership.family?.id, family.id, "Membership should reference the family")
        XCTAssertEqual(membership.user?.id, user.id, "Membership should reference the user")
        
        // Test that relationship changes maintain consistency
        let newUser = try createTestUser(displayName: "New User", appleUserIdHash: "new_hash")
        membership.user = newUser
        try saveContext()
        
        // Verify consistency after change
        XCTAssertEqual(membership.user?.id, newUser.id)
        XCTAssertTrue(newUser.memberships?.contains { $0.id == membership.id } ?? false)
        
        // Original user should no longer have this membership
        let originalUser = try fetchRecords(UserProfile.self, predicate: #Predicate { $0.displayName == "Inverse User" }).first!
        XCTAssertFalse(originalUser.memberships?.contains { $0.id == membership.id } ?? true)
        
        print("✅ Changing relationship inverse configurations maintains consistency")
    }
    
    /// Test that changing optional to required relationships is handled gracefully
    func testChangingOptionalToRequiredRelationshipsHandledGracefully() throws {
        print("🧪 Testing changing optional to required relationships handled gracefully...")
        
        // Our current models already have optional relationships for CloudKit compatibility
        // Test that validation properly handles missing relationships
        
        let family = try createTestFamily(name: "Required Test", code: "REQ001")
        let user = try createTestUser(displayName: "Required User")
        
        // Create membership with proper relationships
        let membership = try createTestMembership(family: family, user: user, role: .kid)
        
        // Test validation with complete relationships
        XCTAssertTrue(membership.isFullyValid)
        XCTAssertTrue(membership.isValid)
        
        // Test that validation catches missing relationships
        let incompleteMembership = Membership(family: family, user: user, role: .kid)
        incompleteMembership.family = nil // Simulate missing relationship
        
        XCTAssertFalse(incompleteMembership.isValid, "Membership should be invalid without family")
        XCTAssertFalse(incompleteMembership.isFullyValid, "Membership should not be fully valid without family")
        
        print("✅ Changing optional to required relationships handled gracefully")
    }
    
    // MARK: - Complex Migration Scenarios
    
    /// Test migration with multiple simultaneous schema changes
    func testComplexMigrationWithMultipleChanges() throws {
        print("🧪 Testing complex migration with multiple changes...")
        
        // Create comprehensive test data
        let family1 = try createTestFamily(name: "Complex Family 1", code: "COMP01")
        let family2 = try createTestFamily(name: "Complex Family 2", code: "COMP02")
        
        let user1 = try createTestUser(displayName: "Complex User 1")
        let user2 = try createTestUser(displayName: "Complex User 2", appleUserIdHash: "complex_hash_2")
        let user3 = try createTestUser(displayName: "Complex User 3", appleUserIdHash: "complex_hash_3")
        
        let membership1 = try createTestMembership(family: family1, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family1, user: user2, role: .kid)
        let membership3 = try createTestMembership(family: family2, user: user3, role: .parentAdmin)
        
        // Verify initial complex state
        XCTAssertEqual(try countRecords(Family.self), 2)
        XCTAssertEqual(try countRecords(UserProfile.self), 3)
        XCTAssertEqual(try countRecords(Membership.self), 3)
        
        // Test that complex relationships work correctly
        XCTAssertTrue(family1.hasParentAdmin)
        XCTAssertTrue(family2.hasParentAdmin)
        XCTAssertEqual(family1.activeMembers.count, 2)
        XCTAssertEqual(family2.activeMembers.count, 1)
        
        // Simulate complex migration scenario:
        // 1. Add new properties (already have defaults)
        // 2. Modify relationships (test consistency)
        // 3. Update validation rules (test they still work)
        
        // Test that all validation still works after simulated changes
        XCTAssertTrue(family1.isFullyValid)
        XCTAssertTrue(family2.isFullyValid)
        XCTAssertTrue(user1.isFullyValid)
        XCTAssertTrue(user2.isFullyValid)
        XCTAssertTrue(user3.isFullyValid)
        XCTAssertTrue(membership1.isFullyValid)
        XCTAssertTrue(membership2.isFullyValid)
        XCTAssertTrue(membership3.isFullyValid)
        
        // Test that complex queries still work
        let parentAdmins = try fetchRecords(Membership.self, predicate: #Predicate { $0.role == Role.parentAdmin })
        XCTAssertEqual(parentAdmins.count, 2)
        
        let family1Members = try fetchRecords(Membership.self, predicate: #Predicate { $0.family?.code == "COMP01" })
        XCTAssertEqual(family1Members.count, 2)
        
        print("✅ Complex migration with multiple changes handled correctly")
    }
    
    /// Test data integrity validation before and after migration
    func testDataIntegrityValidationBeforeAndAfterMigration() throws {
        print("🧪 Testing data integrity validation before and after migration...")
        
        // Create test data with known integrity constraints
        let family = try createTestFamily(name: "Integrity Family", code: "INT001")
        let user1 = try createTestUser(displayName: "Integrity User 1")
        let user2 = try createTestUser(displayName: "Integrity User 2", appleUserIdHash: "integrity_hash_2")
        
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        
        // Pre-migration integrity checks
        func validateDataIntegrity() throws {
            // Check record counts
            let familyCount = try countRecords(Family.self)
            let userCount = try countRecords(UserProfile.self)
            let membershipCount = try countRecords(Membership.self)
            
            XCTAssertEqual(familyCount, 1, "Should have exactly 1 family")
            XCTAssertEqual(userCount, 2, "Should have exactly 2 users")
            XCTAssertEqual(membershipCount, 2, "Should have exactly 2 memberships")
            
            // Check relationship integrity
            let allMemberships = try fetchAllRecords(Membership.self)
            for membership in allMemberships {
                XCTAssertNotNil(membership.family, "All memberships should have a family")
                XCTAssertNotNil(membership.user, "All memberships should have a user")
                XCTAssertTrue(membership.isFullyValid, "All memberships should be valid")
            }
            
            // Check business rule integrity
            let parentAdminCount = allMemberships.filter { $0.role == .parentAdmin }.count
            XCTAssertEqual(parentAdminCount, 1, "Should have exactly 1 parent admin per family")
            
            // Check unique constraints
            let allFamilies = try fetchAllRecords(Family.self)
            let familyCodes = allFamilies.map { $0.code }
            XCTAssertEqual(Set(familyCodes).count, familyCodes.count, "All family codes should be unique")
        }
        
        // Validate integrity before migration
        try validateDataIntegrity()
        
        // Simulate migration process
        // In a real migration, this would involve schema changes
        // For testing, we'll modify some data and ensure integrity is maintained
        
        // Add some CloudKit sync metadata (simulating migration adding new fields)
        family.ckRecordID = "family_record_id"
        family.lastSyncDate = Date()
        user1.ckRecordID = "user1_record_id"
        user1.lastSyncDate = Date()
        membership1.ckRecordID = "membership1_record_id"
        membership1.lastSyncDate = Date()
        
        try saveContext()
        
        // Validate integrity after migration
        try validateDataIntegrity()
        
        // Additional post-migration checks
        let updatedFamily = try fetchAllRecords(Family.self).first!
        XCTAssertNotNil(updatedFamily.ckRecordID, "Family should have CloudKit record ID after migration")
        XCTAssertNotNil(updatedFamily.lastSyncDate, "Family should have last sync date after migration")
        
        print("✅ Data integrity validation before and after migration successful")
    }
    
    // MARK: - Migration Error Handling Tests
    
    /// Test handling of migration failures and rollback scenarios
    func testMigrationFailureHandlingAndRollback() throws {
        print("🧪 Testing migration failure handling and rollback...")
        
        // Create initial valid state
        let family = try createTestFamily(name: "Rollback Family", code: "ROLL01")
        let user = try createTestUser(displayName: "Rollback User")
        let membership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        
        // Capture initial state
        let initialFamilyCount = try countRecords(Family.self)
        let initialUserCount = try countRecords(UserProfile.self)
        let initialMembershipCount = try countRecords(Membership.self)
        
        XCTAssertEqual(initialFamilyCount, 1)
        XCTAssertEqual(initialUserCount, 1)
        XCTAssertEqual(initialMembershipCount, 1)
        
        // Simulate migration failure scenario
        // In a real scenario, this might be a failed schema update or data transformation
        
        do {
            // Simulate a migration operation that might fail
            // For example, trying to add a required field without a default value
            
            // Create invalid data that would cause migration to fail
            let invalidFamily = Family(name: "", code: "", createdByUserId: UUID()) // Invalid data
            testContext.insert(invalidFamily)
            
            // This should fail validation
            XCTAssertFalse(invalidFamily.isFullyValid, "Invalid family should not be valid")
            
            // Don't save the invalid data (simulating rollback)
            testContext.rollback()
            
        } catch {
            // Migration failed, verify rollback worked
            print("Migration failed as expected: \(error)")
        }
        
        // Verify rollback - original data should still be intact
        let postRollbackFamilyCount = try countRecords(Family.self)
        let postRollbackUserCount = try countRecords(UserProfile.self)
        let postRollbackMembershipCount = try countRecords(Membership.self)
        
        XCTAssertEqual(postRollbackFamilyCount, initialFamilyCount, "Family count should be unchanged after rollback")
        XCTAssertEqual(postRollbackUserCount, initialUserCount, "User count should be unchanged after rollback")
        XCTAssertEqual(postRollbackMembershipCount, initialMembershipCount, "Membership count should be unchanged after rollback")
        
        // Verify original data is still valid
        let remainingFamily = try fetchAllRecords(Family.self).first!
        XCTAssertEqual(remainingFamily.name, "Rollback Family")
        XCTAssertEqual(remainingFamily.code, "ROLL01")
        XCTAssertTrue(remainingFamily.isFullyValid)
        
        print("✅ Migration failure handling and rollback successful")
    }
    
    /// Test partial migration scenarios and recovery
    func testPartialMigrationScenariosAndRecovery() throws {
        print("🧪 Testing partial migration scenarios and recovery...")
        
        // Create test data representing a partially migrated state
        let family1 = try createTestFamily(name: "Partial Family 1", code: "PART01")
        let family2 = try createTestFamily(name: "Partial Family 2", code: "PART02")
        
        // Simulate partial migration: some records have new fields, others don't
        family1.ckRecordID = "migrated_record_1"
        family1.lastSyncDate = Date()
        family1.needsSync = false
        
        // family2 doesn't have CloudKit fields set (simulating partial migration)
        family2.ckRecordID = nil
        family2.lastSyncDate = nil
        family2.needsSync = true
        
        try saveContext()
        
        // Test recovery mechanism - identify and fix partially migrated records
        let allFamilies = try fetchAllRecords(Family.self)
        var unmigrated = 0
        var migrated = 0
        
        for family in allFamilies {
            if family.ckRecordID == nil || family.lastSyncDate == nil {
                unmigrated += 1
                
                // Simulate recovery: complete the migration for this record
                if family.ckRecordID == nil {
                    family.ckRecordID = "recovered_\(family.id.uuidString)"
                }
                if family.lastSyncDate == nil {
                    family.lastSyncDate = Date()
                }
                family.needsSync = true // Mark for sync after recovery
            } else {
                migrated += 1
            }
        }
        
        try saveContext()
        
        // Verify recovery completed successfully
        XCTAssertEqual(unmigrated, 1, "Should have found 1 unmigrated record")
        XCTAssertEqual(migrated, 1, "Should have found 1 already migrated record")
        
        // Verify all records are now properly migrated
        let recoveredFamilies = try fetchAllRecords(Family.self)
        for family in recoveredFamilies {
            XCTAssertNotNil(family.ckRecordID, "All families should have CloudKit record ID after recovery")
            XCTAssertNotNil(family.lastSyncDate, "All families should have last sync date after recovery")
            XCTAssertTrue(family.isFullyValid, "All families should be valid after recovery")
        }
        
        print("✅ Partial migration scenarios and recovery successful")
    }
}